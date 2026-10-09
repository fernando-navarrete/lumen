# Lumen

A GOG game library manager, downloader and Proton launcher for Linux. Lumen logs in to your GOG
account, lists the games you own, downloads, verifies and repairs them, syncs cloud saves, and runs
them under an app-managed [Proton-GE](https://github.com/GloriousEggroll/proton-ge-custom) (not
Steam). Linux is the only platform that is built and tested.

All GOG API access, downloading, verification and repair, save-cloud sync and Proton-GE release
fetching are done by the Rust bridge
[`gogdl_flutter`](https://github.com/fernando-navarrete/gogdl_flutter), pinned by tag in
`pubspec.yaml` and fetched over HTTPS from its public GitHub mirror. A clone builds as is: no key,
no SSH and no git setting.

## Building from a clone

```sh
git clone https://github.com/fernando-navarrete/lumen.git
cd lumen
```

You need:

- [fvm](https://fvm.app/), which installs the Flutter version pinned in `.fvmrc` (`3.47.2`, with
  `fvm install`). Prefix Flutter and Dart commands with `fvm`, not the bare binaries.
- [rustup](https://rustup.rs). The bridge builds its native library with a Native Assets build hook
  that runs cargo, and its `rust-toolchain.toml` pins Rust `1.98.1`, which rustup installs on the
  first build. `pub get`, `analyze` and `test` need it too, even though tests never load the library.
- The Linux desktop build tools: `clang`, `cmake`, `ninja`, `pkg-config`, and the GTK 3 and
  `libsecret-1` development packages (`libsecret` 0.18.4 or newer).
- To log in, a running Secret Service provider (GNOME Keyring or KWallet): the GOG token is stored
  in the keyring.
- Network access to pub.dev, crates.io and github.com on the first build.

Then:

```sh
fvm flutter pub get
fvm flutter run -d linux
fvm flutter build linux    # the bundle lands in build/linux/x64/release/bundle/
```

## Development

The checks CI runs, locally:

```sh
fvm dart format --output=none --set-exit-if-changed lib test tool
fvm flutter analyze --fatal-infos
fvm flutter test
```

Tests run against a fake `GogBackend`, so none of them load the native library.

Once per clone, `git config core.hooksPath .githooks` enables a pre-commit hook that checks the
format of the staged Dart files. `git commit --no-verify` skips it; CI still checks.

GitLab CI runs on merge requests and `v*` tags. `lint` runs `tool/check_bridge_pin.sh` (the pinned
`gogdl_flutter` tag exists on GitHub at the locked commit), the format check and
`flutter analyze --fatal-infos`; `test` runs the suite; `secrets` runs gitleaks over the commits;
`bridge-lock`, `scan` and `scan-gate` run OSV-Scanner on `pubspec.lock` and the bridge's
`Cargo.lock`, which also runs weekly. Renovate opens one grouped minor and patch update MR a week.
`main` is protected, so every change goes through a merge request. The header of `.gitlab-ci.yml`
describes each job, and [SECURITY.md](SECURITY.md) has the dependency rules.

## Layout

- `lib/`: the app. `state/` (Riverpod notifiers and the `GogBackend` interface over the bridge),
  `screens/`, `components/`, `common/` (paths, launch resolution, errors), `models/`, `theme/`.
- `test/`: unit and widget tests, with fakes under `test/helpers/`.
- `linux/`: the Linux runner. There are no other platform folders.
- `tool/`: `check_lockfile.sh`, `check_bridge_pin.sh` and the OSV gate.
- `.githooks/`: the pre-commit hook.
- `SECURITY.md`, `.gitleaks.toml`, `osv-scanner.toml`, `renovate.json`: supply-chain policy and the
  config of the `secrets`, `scan` and Renovate jobs.
- `LICENSE-MIT`, `LICENSE-APACHE`: the license (see "License").
- `CLAUDE.md`, `ROADMAP.md`, `GAPS.md`, `devlog/`: architecture notes, planned releases, known gaps
  and the history of how each release was built.

## This repository is a mirror

Development happens on a self-hosted GitLab. This GitHub repository is a read-only push mirror of
`main` and the `v*` tags (GitLab's built-in push mirror, protected refs only, with a fine-grained
token limited to this repository): issues, pull requests and Actions are off here. Report a problem
to the maintainer directly (see [SECURITY.md](SECURITY.md)).

## License

Licensed under either of [MIT](LICENSE-MIT) or [Apache-2.0](LICENSE-APACHE), at your option.
