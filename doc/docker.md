## Setting up Stonix with Docker

You can use Docker To setup Stonix, a brocoind node and a c-lightning node all in go with the following command:

```bash
$ docker run -it -v ~/.stonix-docker:/data -p 9737:9737 \
             shesek/stonix-wallet --login bob:superSecretPass456
```

You will then be able to access the Stonix wallet at `https://localhost:9737`.

Runs in `testnet` mode by default, set `NETWORK` to override (e.g. `-e NETWORK=brocoin`).

Data files will be stored in `~/.stonix-docker/{brocoin,lightning,stonix}`.
You can set Stonix's configuration options in `~/.stonix-docker/stonix/config`.

When starting for the first time, you'll have to wait for the brocoin node to sync up.
You can check the progress by tailing `~/.stonix-docker/brocoin/debug.log`.

You can set custom command line options for `brocoind` with `BROCOIND_OPT`
and for `lightningd` with `LIGHTNINGD_OPT`.

Note that TLS will be enabled by default (even without changing `--host`).
You can use `--no-tls` to turn it off.

#### With existing `lightningd`

To connect to an existing `lightningd` instance running on the same machine,
mount the lightning data subdirectory for the network (e.g. `~/.lightning/brocoin`)
into `/etc/lightning`:

```bash
$ docker run -it -v ~/.stonix-docker:/data -p 9737:9737 \
             -v ~/.lightning/brocoin:/etc/lightning \
             shesek/stonix-wallet:standalone
```

Note the `:standalone` version for the docker image, which doesn't include
brocoind's/lightningd's binaries and weights about 60MB less.

Connecting to remote lightningd instances is currently not supported.

#### With existing `brocoind`, but with bundled `lightningd`

To connect to an existing `brocoind` instance running on the same machine,
mount the brocoin data directory to `/etc/brocoin` (e.g. `-v ~/.brocoin:/etc/brocoin`),
and either use host networking (`--network host`) or specify the IP where brocoind is reachable via `BROCOIND_RPCCONNECT`.
The RPC credentials and port will be read from brocoind's config file.

To connect to a remote brocoind instance, set `BROCOIND_URI=http://[user]:[pass]@[host]:[port]`
(or use `__cookie__:...` as the login for cookie-based authentication).
