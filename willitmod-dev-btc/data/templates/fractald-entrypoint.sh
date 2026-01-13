#!/bin/sh
set -eu

DATADIR="${DATADIR:-/data}"
FLAG="${DATADIR}/sync_enabled"
PID_FILE="/tmp/bitcoind.pid"

calc_dbcache() {
  dbcache="$(printf %s "${FB_DBCACHE_MB:-}" | tr -d '\r\n\t ' || true)"
  case "${dbcache}" in
    '' ) ;;
    *[!0-9]* ) dbcache="" ;;
    * )
      if [ "${dbcache}" -gt 0 ] 2>/dev/null; then
        echo "${dbcache}"
        return
      fi
      dbcache=""
      ;;
  esac

  # Optional file override (written by the AxeBTCF UI).
  dbcache_file="${DATADIR}/dbcache_mb"
  if [ -f "${dbcache_file}" ]; then
    dbcache="$(head -n 1 "${dbcache_file}" 2>/dev/null | tr -d '\r\n\t ' || true)"
    case "${dbcache}" in
      '' ) ;;
      *[!0-9]* ) dbcache="" ;;
      * )
        if [ "${dbcache}" -gt 0 ] 2>/dev/null; then
          echo "${dbcache}"
          return
        fi
        dbcache=""
        ;;
    esac
  fi

  mem_kb="$(awk '/MemTotal/ {print $2}' /proc/meminfo 2>/dev/null || echo 0)"
  mem_mb="$((mem_kb / 1024))"
  # IBD is extremely disk-IO heavy; using more dbcache helps a lot on typical
  # Umbrel hardware. Default to 8GB on >=16GB systems; keep it bounded to avoid
  # OOM on low-memory systems.
  if [ "${mem_mb}" -ge 16384 ] 2>/dev/null; then
    dbcache=8192
  else
    dbcache="$((mem_mb / 4))"
  fi
  if [ "${dbcache}" -lt 512 ]; then dbcache=512; fi
  if [ "${dbcache}" -gt 8192 ]; then dbcache=8192; fi
  echo "${dbcache}"
}

calc_rpcthreads() {
  v="${FB_RPCTHREADS:-}"
  if [ -n "${v}" ]; then
    echo "${v}"
    return
  fi
  echo 32
}

calc_rpcworkqueue() {
  v="${FB_RPCWORKQUEUE:-}"
  if [ -n "${v}" ]; then
    echo "${v}"
    return
  fi
  echo 1024
}

read_flag() {
  if [ -f "${FLAG}" ]; then
    # Accept "1", "true", etc. Anything else is treated as off.
    val="$(head -n 1 "${FLAG}" 2>/dev/null | tr -d '\r\n\t ' || true)"
    case "${val}" in
      1|true|TRUE|yes|YES|on|ON) echo 1 ;;
      *) echo 0 ;;
    esac
  else
    echo 0
  fi
}

start_node() {
  echo "[fractald] Starting Fractal node..."
  dbcache="$(calc_dbcache)"
  rpcthreads="$(calc_rpcthreads)"
  rpcworkqueue="$(calc_rpcworkqueue)"
  echo "[fractald] Using dbcache=${dbcache}MB"
  echo "[fractald] Using rpcthreads=${rpcthreads} rpcworkqueue=${rpcworkqueue}"
  bitcoind -datadir="${DATADIR}" -printtoconsole -dbcache="${dbcache}" -rpcthreads="${rpcthreads}" -rpcworkqueue="${rpcworkqueue}" &
  echo $! > "${PID_FILE}"
}

try_add_peers() {
  # Throttle (avoid hammering RPC / addnode).
  now="$(date +%s 2>/dev/null || echo 0)"
  last="$(cat /tmp/peer_boost_at 2>/dev/null || echo 0)"
  case "${now}" in
    ''|*[!0-9]*) now=0 ;;
  esac
  case "${last}" in
    ''|*[!0-9]*) last=0 ;;
  esac
  if [ "${now}" -gt 0 ] && [ $((now - last)) -lt 60 ]; then
    return
  fi

  # If Fractal has trouble finding peers via DNS seed, "onetry" a few fresh
  # addresses from addrman to help establish initial connectivity.
  # Keep it lightweight and safe (no persistent addnode entries).
  cc="$(bitcoin-cli -datadir="${DATADIR}" -rpcwait=30 -rpcclienttimeout=60 getconnectioncount 2>/dev/null || echo 0)"
  case "${cc}" in
    ''|*[!0-9]*) cc=0 ;;
  esac
  if [ "${cc}" -ge 4 ]; then
    return
  fi

  if [ "${now}" -gt 0 ]; then
    echo "${now}" > /tmp/peer_boost_at 2>/dev/null || true
  fi

  echo "[fractald] Low peer count (${cc}); trying a few onetry peers..."
  bitcoin-cli -datadir="${DATADIR}" -rpcwait=30 -rpcclienttimeout=60 getnodeaddresses 80 2>/dev/null \
    | awk '
        BEGIN { addr=""; port=""; added=0; }
        /"address"[[:space:]]*:/ {
          gsub(/[",]/,"");
          addr=$2;
          next;
        }
        /"port"[[:space:]]*:/ {
          gsub(/[",]/,"");
          port=$2;
          # Prefer known Fractal mainnet P2P ports. Skip IPv6 (requires [] formatting).
          if (addr != "" && port != "" && added < 12 && addr !~ /:/ && (port == 8333 || port == 10333)) {
            print addr ":" port;
            added++;
          }
          addr=""; port="";
          next;
        }
      ' \
    | while read -r ap; do
        bitcoin-cli -datadir="${DATADIR}" -rpcwait=5 -rpcclienttimeout=10 addnode "${ap}" onetry >/dev/null 2>&1 || true
      done
  echo "[fractald] Peer boost complete."
}

stop_node() {
  if [ ! -f "${PID_FILE}" ]; then
    return
  fi
  pid="$(cat "${PID_FILE}" 2>/dev/null || true)"
  if [ -z "${pid}" ]; then
    rm -f "${PID_FILE}" || true
    return
  fi

  echo "[fractald] Stopping Fractal node..."
  if ! bitcoin-cli -datadir="${DATADIR}" -rpcclienttimeout=10 stop >/dev/null 2>&1; then
    # If RPC is overloaded/unresponsive, fall back to a direct signal.
    kill -TERM "${pid}" 2>/dev/null || true
  fi

  # AXEBTCF_FAST_STOP
  # Wait up to ~90s for a clean shutdown (Umbrel restarts should be quick).
  for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 37 38 39 40 41 42 43 44 45; do
    if ! kill -0 "${pid}" 2>/dev/null; then
      rm -f "${PID_FILE}" || true
      return
    fi
    sleep 2
  done

  echo "[fractald] Timed out waiting for clean shutdown; force-killing pid ${pid}"
  kill "${pid}" 2>/dev/null || true
  rm -f "${PID_FILE}" || true
}

on_term() {
  echo "[fractald] Caught termination signal; stopping node..."
  stop_node || true
  exit 0
}

trap on_term TERM INT

while true; do
  if [ "$(read_flag)" = "1" ]; then
    start_node
    pid="$(cat "${PID_FILE}" 2>/dev/null || true)"
    while [ -n "${pid}" ] && kill -0 "${pid}" 2>/dev/null; do
      if [ "$(read_flag)" != "1" ]; then
        stop_node
        break
      fi
      try_add_peers || true
      sleep 5
    done
  else
    echo "[fractald] Fractal sync disabled (toggle AxePoW mode in the app to enable)."
    sleep 10
  fi
done
