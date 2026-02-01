# WillItMod Dev Community Store

Development/test app store for WillItMod apps.

## Apps

- **Bitcoin** (`willitmod-dev-btc`): BTC full node (Core/Knots) + solo Stratum v1 pool (ckpool) in a single app.
- **Bitcoin Cash** (`willitmod-dev-bch`): BCH full node (BCHN) + solo Stratum v1 pool (ckpool) in a single app.
- **Bitcoin SV** (`willitmod-dev-bsv`): BSV full node + solo Stratum v1 pool (ckpool) in a single app (amd64-only).
- **BitcoinII** (`willitmod-dev-bc2`): BitcoinII (BC2) full node + solo Stratum v1 pool (ckpool) in a single app.
- **DigiByte** (`willitmod-dev-dgb`): DigiByte Core full node + solo Stratum v1 pool (ckpool) in a single app (experimental).
- **eCash** (`willitmod-dev-xec`): eCash (XEC) full node + solo Stratum v1 pool (ckpool) in a single app.
- **Peercoin** (`willitmod-dev-ppc`): Peercoin full node + solo Stratum v1 pool (ckpool) in a single app.
- **Fractal Bitcoin** (`willitmod-dev-fbtc`): Fractal Bitcoin (FBTC) full node + solo Stratum v1 pool (ckpool) in a single app (amd64-only).
- **AxeMIG** (`willitmod-dev-axemig`): data-only blockchain migration tool (experimental).

## Quick setup (solo mining)

1. Install the app and let the node sync.
2. Point miners at:
   - BTC: `stratum+tcp://<host-ip>:7890`
   - BCH: `stratum+tcp://<host-ip>:4567`
   - BSV: `stratum+tcp://<host-ip>:8901`
   - BC2: `stratum+tcp://<host-ip>:2345`
   - DGB (SHA256): `stratum+tcp://<host-ip>:5678`
   - DGB (Scrypt): `stratum+tcp://<host-ip>:5679`
   - XEC: `stratum+tcp://<host-ip>:4321`
   - PPC: `stratum+tcp://<host-ip>:9876`
   - FBTC (Fractal Bitcoin): `stratum+tcp://<host-ip>:8334`

## Address format notes

**BCH**
Many wallets (e.g. Trust Wallet) show Bitcoin Cash addresses in CashAddr format (`q...` / `p...`).

For maximum compatibility with ckpool/miners, use a legacy BCH Base58 address (`1...` / `3...`) as the payout address. If your wallet only shows CashAddr, convert it to legacy (or enable legacy display) before saving.

**XEC**
Many wallets show eCash addresses in CashAddr format (`ecash:q...` / `ecash:p...`).

For maximum compatibility with ckpool/miners, use a legacy Base58 address (`1...` / `3...`) as the payout address. AxeXEC converts CashAddr to legacy for ckpool compatibility.

**DGB**
Use a DigiByte address (typically Base58 `D...` / `S...` or Bech32 `dgb1...`).

## Security / provenance

- BCHN runs from Docker Hub image `mainnet/bitcoin-cash-node` (pinned by version tag in `docker-compose.yml`).
- ckpool runs from `ghcr.io/getumbrel/docker-ckpool-solo` (pinned by version tag in `docker-compose.yml`).
- BTC node selector runs from `ghcr.io/willitmod/axebtc-bitcoind-switch` (pinned by version tag in `docker-compose.yml`).
- BC2 node runs from `ghcr.io/willitmod/bitcoinii-core` (pinned by version tag in `docker-compose.yml`).
- XEC node is built locally from official Bitcoin ABC release tarballs (pinned by version in `data/xecd/Dockerfile`).
- PPC node runs from `ghcr.io/willitmod/peercoin-core` (pinned by version tag in `docker-compose.yml`).
- Fractal Bitcoin node is built from official fractald-release tarball (v0.2.9rc2, amd64 only) in `willitmod-dev-fbtc/data/fractald/Dockerfile`.
- This store repo does not patch upstream source code; it only orchestrates upstream components via Docker images (some are built from official release tarballs).
