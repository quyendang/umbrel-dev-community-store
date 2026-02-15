# Fractal Bitcoin node - built from official release tarball (amd64 only).
# https://github.com/fractal-bitcoin/fractald-release/releases
FROM debian:bookworm-slim

ARG FRACTALD_VERSION=0.3.0
ARG TARGETARCH

# Fractal Bitcoin only provides x86_64-linux-gnu tarball.
RUN set -eux; \
  if [ "${TARGETARCH}" != "amd64" ]; then \
    echo "Fractal Bitcoin node is only available for amd64 (x86_64). Current: ${TARGETARCH}" >&2; \
    exit 1; \
  fi; \
  apt-get update; \
  apt-get install -y --no-install-recommends ca-certificates wget; \
  rm -rf /var/lib/apt/lists/*

RUN set -eux; \
  url="https://github.com/fractal-bitcoin/fractald-release/releases/download/v${FRACTALD_VERSION}/fractald-${FRACTALD_VERSION}-x86_64-linux-gnu.tar.gz"; \
  echo "Downloading ${url}"; \
  wget -q -O /tmp/fractald.tar.gz "${url}"; \
  tar -zxf /tmp/fractald.tar.gz -C /opt; \
  rm -f /tmp/fractald.tar.gz; \
  ln -sf "/opt/fractald-${FRACTALD_VERSION}-x86_64-linux-gnu/bin/bitcoind" /usr/local/bin/bitcoind; \
  ln -sf "/opt/fractald-${FRACTALD_VERSION}-x86_64-linux-gnu/bin/bitcoin-cli" /usr/local/bin/bitcoin-cli

# RPC port is configured via /data/bitcoin.conf (templated by the app).
# Data dir is mounted at /data.
CMD ["bitcoind", "-datadir=/data", "-printtoconsole"]
