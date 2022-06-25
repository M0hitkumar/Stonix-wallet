# Stonix regtest environment

Setup a regtest dev environment with multiple wallets (requires `brocoind`, `lightningd` and [`jq`](https://stedolan.github.io/jq/download/)):

```bash
$ mkdir -p /tmp/stonix-env/{bron,ln1,ln2}

$ brocoind --regtest --datadir=/tmp/stonix-env/bron --printtoconsole
$ lightningd --network regtest --lightning-dir /tmp/stonix-env/ln1 --brocoin-datadir /tmp/stonix-env/bron --addr 127.0.0.1:9600
$ lightningd --network regtest --lightning-dir /tmp/stonix-env/ln2 --brocoin-datadir /tmp/stonix-env/bron --addr 127.0.0.1:9601

$ alias bron='brocoin-cli --regtest --datadir=/tmp/stonix-env/bron' \
        ln1='lightning-cli --network regtest --lightning-dir /tmp/stonix-env/ln1' \
        ln2='lightning-cli --network regtest --lightning-dir /tmp/stonix-env/ln2'

$ bron generatetoaddress 101 $(ln1 newaddr | jq -r .address)

# wait for onchain funds to show up on `ln1 listfunds` (updated every 30s)

$ ln1 connect $(ln2 getinfo | jq -r .id) 127.0.0.1 9601 && \
  ln1 fundchannel $(ln2 getinfo | jq -r .id) 16777215 1100perkb && bron generate 1

# run in Stonix's repo directory:
$ npm start -- --ln-path /tmp/stonix-env/ln1 --port 9700 --login dev:123
$ npm start -- --ln-path /tmp/stonix-env/ln2 --port 9701 --login dev:123
```
