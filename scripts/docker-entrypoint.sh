#!/bin/bash
set -eo pipefail
trap 'jobs -p | xargs -r kill' SIGTERM

: ${NETWORK:=testnet}
: ${LIGHTNINGD_OPT:=--log-level=debug}
: ${BITCOIND_OPT:=-debug=rpc --printtoconsole=0}

[[ "$NETWORK" == "mainnet" ]] && NETWORK=brocoin

if [ -d /etc/lightning ]; then
  echo -n "Using lightningd directory mounted in /etc/lightning... "
  LN_PATH=/etc/lightning
  if [ ! -f $LN_PATH/lightning-rpc ] && [ -f $LN_PATH/$NETWORK/lightning-rpc ]; then
    echo -n "Using $LN_PATH/$NETWORK... "
    LN_PATH=$LN_PATH/$NETWORK
  fi
else

  # Setup brocoind (only needed when we're starting our own lightningd instance)
  if [ -d /etc/brocoin ]; then
    echo -n "Connecting to brocoind configured in /etc/brocoin... "

    RPC_OPT="-datadir=/etc/brocoin $([[ -z "$BITCOIND_RPCCONNECT" ]] || echo "-rpcconnect=$BITCOIND_RPCCONNECT")"

  elif [ -n "$BITCOIND_URI" ]; then
    [[ "$BITCOIND_URI" =~ ^[a-z]+:\/+(([^:/]+):([^@/]+))@([^:/]+:[0-9]+)/?$ ]] || \
      { echo >&2 "ERROR: invalid brocoind URI: $BITCOIND_URI"; exit 1; }

    echo -n "Connecting to brocoind at ${BASH_REMATCH[4]}... "

    RPC_OPT="-rpcconnect=${BASH_REMATCH[4]}"

    if [ "${BASH_REMATCH[2]}" != "__cookie__" ]; then
      RPC_OPT="$RPC_OPT -rpcuser=${BASH_REMATCH[2]} -rpcpassword=${BASH_REMATCH[3]}"
    else
      RPC_OPT="$RPC_OPT -datadir=/tmp/brocoin"
      [[ "$NETWORK" == "brocoin" ]] && NET_PATH=/tmp/brocoin || NET_PATH=/tmp/brocoin/$NETWORK
      mkdir -p $NET_PATH
      echo "${BASH_REMATCH[1]}" > $NET_PATH/.cookie
    fi

  else
    echo -n "Starting brocoind... "

    mkdir -p /data/brocoin
    RPC_OPT="-datadir=/data/brocoin"

    if [ "$NETWORK" != "brocoin" ]; then
      BITCOIND_NET_OPT="-$NETWORK"
    fi

    brocoind $BITCOIND_NET_OPT $RPC_OPT $BITCOIND_OPT &
    echo -n "waiting for cookie... "
    sed --quiet '/^\.cookie$/ q' <(inotifywait -e create,moved_to --format '%f' -qmr /data/brocoin)
  fi

  echo -n "waiting for RPC... "
  brocoin-cli $BITCOIND_NET_OPT $RPC_OPT -rpcwait getblockchaininfo > /dev/null
  echo "ready."

  # Setup lightning
  echo -n "Starting lightningd... "

  LN_BASE=/data/lightning
  mkdir -p $LN_BASE

  lnopt=($LIGHTNINGD_OPT --network=$NETWORK --lightning-dir=$LN_BASE --log-file=debug.log)
  [[ -z "$LN_ALIAS" ]] || lnopt+=(--alias="$LN_ALIAS")

  lightningd "${lnopt[@]}" $(echo "$RPC_OPT" | sed -r 's/(^| )-/\1--brocoin-/g') > /dev/null &

  LN_PATH=$LN_BASE/$NETWORK
  mkdir -p $LN_PATH
fi

if [ ! -S $LN_PATH/lightning-rpc ] || ! echo | nc -q0 -U $LN_PATH/lightning-rpc 2> /dev/null; then
  echo -n "waiting for RPC unix socket... "
  sed --quiet '/^lightning-rpc$/ q' <(inotifywait -e create,moved_to --format '%f' -qm $LN_PATH)
fi

# lightning-cli is unavailable in standalone mode, so we can't check the rpc connection.
# Stonix itself also checks the connection when starting up, so this is not too bad.
if command -v lightning-cli > /dev/null; then
  # workaround for https://github.com/ElementsProject/lightning/issues/3352
  # (patch is on its way! but this will have to be kept around for v0.8.0 compatibility)
  mkdir -p /tmp/dummy /tmp/dummy/brocoin
  lightning-cli --lightning-dir /tmp/dummy --rpc-file $LN_PATH/lightning-rpc getinfo > /dev/null
  echo -n "c-lightning RPC ready."
  rm -r /tmp/dummy
fi

mkdir -p $TOR_PATH/tor-installation/node_modules

if [ -z "$STANDALONE" ]; then
  # when not in standalone mode, run stonix-wallet as an additional background job
  echo -e "\nStarting stonix wallet..."
  stonix-wallet -l $LN_PATH "$@" $STONIX_OPT &

  # shutdown the entire process when any of the background jobs exits (even if successfully)
  wait -n
  kill -TERM $$
else
  # in standalone mode, replace the process with stonix-wallet
  echo -e "\nStarting stonix wallet (standalone mode)..."
  exec stonix-wallet -l $LN_PATH "$@" $STONIX_OPT
fi

