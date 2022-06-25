# Reproducible builds

The NPM package, Android `apk` builds, Linux `AppImage`/`snap`/`tar.gz` builds, macOS `zip` builds and Windows `exe` installer are deterministically reproducible.

The Android `apk`, Linux `deb` and Windows portable runner are currently not. :-(

### Reproduce with Docker

A `Dockerfile` for reproducing the builds is available at `scripts/builder.Dockerfile`.
It can be used as follows:

```bash
$ git clone https://github.com/shesek/stonix-wallet && cd stonix-wallet
$ docker build -f scripts/builder.Dockerfile -t stonix-builder .
$ docker run --cap-add SYS_ADMIN --device /dev/fuse --security-opt apparmor:unconfined \
            -it -v `pwd`/docker-builds:/target stonix-builder
```

The distribution files and a `SHA256SUMS` file will be created in `./docker-builds/`.

> You need FUSE on your host (`apt install fuse`) and the `--cap-add SYS_ADMIN --device /dev/fuse --security-opt apparmor:unconfined`
> args to enable FUSE in the docker container, which is required for making reproducible Android `apk` builds
> (using `disorderfs`, see
> [[1]](https://lists.reproducible-builds.org/pipermail/rb-general/2018-June/001027.html)
> [[2]](https://code.briarproject.org/briar/briar/issues/1273#note_27268)
> [[3]](https://code.briarproject.org/briar/briar-reproducer/commit/22d04ff8bba956ec9647fd583ec655df691e15e5?w=1)
> [[4]](https://github.com/moby/moby/issues/16429#issuecomment-144491265)).
> If you don't care about apk reproducibility, you can run docker without these args.

### NPM package

The npm package should be reproducible even without docker.
It should be sufficient to use a recent nodejs release (the official releases are made with nodejs v16.8.0 and npm v7.21.0).
Run `npm run dist:npm -- --pack-tgz` to create `stonix-wallet-[x.y.z]-npm.tgz` in main directory.

The `npm-shrinkwrap.json` file inside the npm package commits to integrity checksums
for the entire dependency graph using
[Subresource Integrity](https://w3c.github.io/webappsec-subresource-integrity/).

<!--
### Android APK

Android `apk` files that are signed using the android code signing process cannot be reproduced independently.
Stonix therefore provides two separate `apk` files:

- `stonix-wallet-x.y.z-release.apk` - a release build signed using android's signing process that is not reproducible.

- `stonix-wallet-x.y.z-debug.apk` - a debug build that is not signed using android's signing process but is reproducible.
-->

### Travis-CI

The builds are [reproduced on Travis-CI](https://travis-ci.org/shesek/stonix-wallet).
The SHA256 checksums are available at the end of the job log.

You can get the checksums for the last stable release as follows:

```bash
$ jobid=$(curl -s 'https://api.travis-ci.org/v3/repo/shesek%2Fstonix-wallet/builds?branch.name=stable&sort_by=started_at:desc&limit=1' | jq -r '.builds[0].jobs[0].id')
$ curl -s https://api.travis-ci.org/v3/job/$jobid/log.txt | sed -nr '/^-----BEGIN SHA256SUM-----\s*$/{:a;n;/^\s*$/q;p;ba}'
```
