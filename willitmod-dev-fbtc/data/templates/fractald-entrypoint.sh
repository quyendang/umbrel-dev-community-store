#!/bin/sh
set -eu

echo "[fbtc] fractald entrypoint starting"

if ! command -v bitcoind >/dev/null 2>&1; then
  echo "[fbtc] ERROR: bitcoind not found in PATH"
  exit 127
fi

# Fractal node: -datadir=/data, config is /data/bitcoin.conf (in datadir)
echo "[fbtc] Exec: bitcoind -datadir=/data -printtoconsole"
exec bitcoind -datadir=/data -printtoconsole
