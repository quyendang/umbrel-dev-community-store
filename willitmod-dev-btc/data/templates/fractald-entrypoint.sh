#!/bin/sh
set -eu

DATADIR="${DATADIR:-/data}"
FLAG="${DATADIR}/sync_enabled"
PID_FILE="/tmp/bitcoind.pid"

calc_dbcache() {
  dbcache="${FB_DBCACHE_MB:-}"
  if [ -n "${dbcache}" ]; then
    echo "${dbcache}"
    return
  fi

  mem_kb="$(awk '/MemTotal/ {print $2}' /proc/meminfo 2>/dev/null || echo 0)"
  mem_mb="$((mem_kb / 1024))"
  # IBD is extremely disk-IO heavy; using more dbcache helps a lot on typical
  # Umbrel hardware. Keep it bounded to avoid OOM on low-memory systems.
  dbcache="$((mem_mb / 4))"
  if [ "${dbcache}" -lt 512 ]; then dbcache=512; fi
  if [ "${dbcache}" -gt 4096 ]; then dbcache=4096; fi
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
  if ! bitcoin-cli -datadir="${DATADIR}" stop >/dev/null 2>&1; then
    # If RPC is overloaded/unresponsive, fall back to a direct signal.
    kill -TERM "${pid}" 2>/dev/null || true
  fi

  # Wait up to ~10 minutes for a clean shutdown (flush + prune can be slow in IBD).
  for _ in 1 2 3 4 5 6 7 8 9 10 \
           11 12 13 14 15 16 17 18 19 20 \
           21 22 23 24 25 26 27 28 29 30 \
           31 32 33 34 35 36 37 38 39 40 \
           41 42 43 44 45 46 47 48 49 50 \
           51 52 53 54 55 56 57 58 59 60 \
           61 62 63 64 65 66 67 68 69 70 \
           71 72 73 74 75 76 77 78 79 80 \
           81 82 83 84 85 86 87 88 89 90 \
           91 92 93 94 95 96 97 98 99 100 \
           101 102 103 104 105 106 107 108 109 110 \
           111 112 113 114 115 116 117 118 119 120 \
           121 122 123 124 125 126 127 128 129 130 \
           131 132 133 134 135 136 137 138 139 140 \
           141 142 143 144 145 146 147 148 149 150 \
           151 152 153 154 155 156 157 158 159 160 \
           161 162 163 164 165 166 167 168 169 170 \
           171 172 173 174 175 176 177 178 179 180 \
           181 182 183 184 185 186 187 188 189 190 \
           191 192 193 194 195 196 197 198 199 200 \
           201 202 203 204 205 206 207 208 209 210 \
           211 212 213 214 215 216 217 218 219 220 \
           221 222 223 224 225 226 227 228 229 230 \
           231 232 233 234 235 236 237 238 239 240 \
           241 242 243 244 245 246 247 248 249 250 \
           251 252 253 254 255 256 257 258 259 260 \
           261 262 263 264 265 266 267 268 269 270 \
           271 272 273 274 275 276 277 278 279 280 \
           281 282 283 284 285 286 287 288 289 290 \
           291 292 293 294 295 296 297 298 299 300; do
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
