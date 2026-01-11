#!/bin/sh
set -eu

DATADIR="${DATADIR:-/data}"
FLAG="${DATADIR}/sync_enabled"

calc_dbcache() {
  dbcache="${FB_DBCACHE_MB:-}"
  if [ -n "${dbcache}" ]; then
    echo "${dbcache}"
    return
  fi

  mem_kb="$(awk '/MemTotal/ {print $2}' /proc/meminfo 2>/dev/null || echo 0)"
  mem_mb="$((mem_kb / 1024))"
  dbcache="$((mem_mb / 8))"
  if [ "${dbcache}" -lt 256 ]; then dbcache=256; fi
  if [ "${dbcache}" -gt 2048 ]; then dbcache=2048; fi
  echo "${dbcache}"
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
  echo "[fractald] Using dbcache=${dbcache}MB"
  bitcoind -datadir="${DATADIR}" -printtoconsole -dbcache="${dbcache}" &
  echo $! > /tmp/bitcoind.pid
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
  bitcoin-cli -datadir="${DATADIR}" -rpcwait=30 -rpcclienttimeout=60 getnodeaddresses 60 2>/dev/null \
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
          if (addr != "" && port != "" && added < 12) {
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
}

stop_node() {
  if [ ! -f /tmp/bitcoind.pid ]; then
    return
  fi
  pid="$(cat /tmp/bitcoind.pid 2>/dev/null || true)"
  if [ -z "${pid}" ]; then
    rm -f /tmp/bitcoind.pid || true
    return
  fi

  echo "[fractald] Stopping Fractal node..."
  bitcoin-cli -datadir="${DATADIR}" stop >/dev/null 2>&1 || true

  # Wait up to ~30s, then force-kill.
  for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do
    if ! kill -0 "${pid}" 2>/dev/null; then
      rm -f /tmp/bitcoind.pid || true
      return
    fi
    sleep 2
  done

  kill "${pid}" 2>/dev/null || true
  rm -f /tmp/bitcoind.pid || true
}

while true; do
  if [ "$(read_flag)" = "1" ]; then
    start_node
    pid="$(cat /tmp/bitcoind.pid 2>/dev/null || true)"
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
