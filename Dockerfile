FROM node:16.8-bullseye-slim as builder

ARG DEVELOPER
ARG STANDALONE
ENV STANDALONE=$STANDALONE

# Install build dependencies for third-party packages (c-lightning/brocoind)
RUN apt-get update && apt-get install -y --no-install-recommends git ca-certificates dirmngr wget  \
    $([ -n "$STANDALONE" ] || echo "autoconf automake build-essential gettext gpg gpg-agent libtool libgmp-dev \
                                     libsqlite3-dev python python3 python3-mako python3-pip wget zlib1g-dev unzip")

ENV LIGHTNINGD_VERSION=0.10.2
ENV LIGHTNINGD_SHA256=3c9dcb686217b2efe0e988e90b95777c4591e3335e259e01a94af87e0bf01809

RUN [ -n "$STANDALONE" ] || ( \
    wget -O /tmp/lightning.zip https://github.com/ElementsProject/lightning/releases/download/v$LIGHTNINGD_VERSION/clightning-v$LIGHTNINGD_VERSION.zip \
    && echo "$LIGHTNINGD_SHA256 /tmp/lightning.zip" | sha256sum -c \
    && unzip /tmp/lightning.zip -d /tmp/lightning \
    && cd /tmp/lightning/clightning* \
    && pip3 install mrkd \
    && DEVELOPER=$DEVELOPER ./configure --prefix=/opt/lightning \
    && make && make install)

# Install brocoind
ENV BITCOIN_VERSION 22.0
ENV BITCOIN_FILENAME brocoin-$BITCOIN_VERSION-x86_64-linux-gnu.tar.gz
ENV BITCOIN_URL https://bitcoincore.org/bin/brocoin-core-$BITCOIN_VERSION/$BITCOIN_FILENAME
ENV BITCOIN_SHA256 59ebd25dd82a51638b7a6bb914586201e67db67b919b2a1ff08925a7936d1b16
RUN [ -n "$STANDALONE" ] || \
    (mkdir /opt/brocoin && cd /opt/brocoin \
    && wget -qO "$BITCOIN_FILENAME" "$BITCOIN_URL" \
    && echo "$BITCOIN_SHA256 $BITCOIN_FILENAME" | sha256sum -c - \
    && BD=brocoin-$BITCOIN_VERSION/bin \
    && tar -xzvf "$BITCOIN_FILENAME" $BD/brocoind $BD/brocoin-cli --strip-components=1)

RUN mkdir -p /opt/bin /opt/brocoin/bin /opt/lightning

# npm doesn't normally like running as root, allow it since we're in docker
RUN npm config set unsafe-perm true

# Install tini
RUN wget -O /opt/bin/tini "https://github.com/krallin/tini/releases/download/v0.18.0/tini-amd64" \
    && echo "12d20136605531b09a2c2dac02ccee85e1b874eb322ef6baf7561cd93f93c855 /opt/bin/tini" | sha256sum -c - \
    && chmod +x /opt/bin/tini

RUN ls -l /opt/lightning

# Install Stonix
WORKDIR /opt/stonix/client
COPY client/package.json client/npm-shrinkwrap.json ./
COPY client/fonts ./fonts
RUN npm install

WORKDIR /opt/stonix
COPY package.json npm-shrinkwrap.json ./
RUN npm install
COPY . .

# Build production NPM package
RUN npm run dist:npm \
 && npm prune --production \
 && find . -mindepth 1 -maxdepth 1 \
           ! -name '*.json' ! -name dist ! -name LICENSE ! -name node_modules ! -name scripts \
           -exec rm -r "{}" \;

# Prepare final image

FROM node:16.8-bullseye-slim

ARG STANDALONE
ENV STANDALONE=$STANDALONE

WORKDIR /opt/stonix

RUN apt-get update && apt-get install -y --no-install-recommends xz-utils inotify-tools netcat-openbsd \
        $([ -n "$STANDALONE" ] || echo libgmp-dev libsqlite3-dev) \
    && rm -rf /var/lib/apt/lists/* \
    && ln -s /opt/stonix/dist/cli.js /usr/bin/stonix-wallet \
    && mkdir /data \
    && ln -s /data/lightning $HOME/.lightning

COPY --from=builder /opt/stonix /opt/stonix
COPY --from=builder /opt/lightning /opt/lightning
COPY --from=builder /opt/brocoin/bin/ /usr/bin
COPY --from=builder /opt/bin/ /usr/bin
RUN ln -s /opt/lightning/bin/* /usr/bin

ENV CONFIG=/data/stonix/config TLS_PATH=/data/stonix/tls TOR_PATH=/data/stonix/tor COOKIE_FILE=/data/stonix/cookie HOST=0.0.0.0

# link the granax (Tor Control client) node_modules installation directory
# inside /data/stonix/tor/, to persist the Tor Bundle download in the user-mounted volume
RUN ln -s $TOR_PATH/tor-installation/node_modules dist/transport/granax-dep/node_modules

VOLUME /data
ENTRYPOINT [ "tini", "-g", "--", "scripts/docker-entrypoint.sh" ]

EXPOSE 9735 9737
