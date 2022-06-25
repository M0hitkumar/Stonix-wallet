FROM node:12.16-slim as builder

ARG DEVELOPER
ENV STANDALONE=1

# Install build c-lightning for third-party packages (c-lightning/brocoind)
RUN apt-get update && apt-get install -y --no-install-recommends git wget ca-certificates \
    qemu qemu-user-static qemu-user binfmt-support

RUN npm config set unsafe-perm true

# Install tini
RUN mkdir /opt/bin && wget -qO /opt/bin/tini "https://github.com/krallin/tini/releases/download/v0.18.0/tini-armhf" \
    && echo "01b54b934d5f5deb32aa4eb4b0f71d0e76324f4f0237cc262d59376bf2bdc269 /opt/bin/tini" | sha256sum -c - \
    && chmod +x /opt/bin/tini

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

FROM arm32v7/node:12.16-slim

ENV STANDALONE=1

WORKDIR /opt/stonix
COPY --from=builder /usr/bin/qemu-arm-static /usr/bin/qemu-arm-static
RUN apt-get update && apt-get install -y --no-install-recommends xz-utils inotify-tools netcat-openbsd \
    && rm -rf /var/lib/apt/lists/* \
    && ln -s /opt/stonix/dist/cli.js /usr/bin/stonix-wallet \
    && mkdir /data \
    && ln -s /data/lightning $HOME/.lightning

COPY --from=builder /opt/bin /usr/bin
COPY --from=builder /opt/stonix /opt/stonix

ENV CONFIG=/data/stonix/config TLS_PATH=/data/stonix/tls TOR_PATH=/data/stonix/tor COOKIE_FILE=/data/stonix/cookie HOST=0.0.0.0

# link the granax (Tor Control client) node_modules installation directory
# inside /data/stonix/tor/, to persist the Tor Bundle download in the user-mounted volume
RUN ln -s $TOR_PATH/tor-installation/node_modules dist/transport/granax-dep/node_modules

VOLUME /data
ENTRYPOINT [ "tini", "-g", "--", "scripts/docker-entrypoint.sh" ]

EXPOSE 9737
