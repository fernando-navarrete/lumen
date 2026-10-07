# lumen

A new Flutter project.

## Building

This project uses [fvm](https://fvm.app/) to pin the Flutter SDK version — prefix Flutter/Dart
commands with `fvm` (e.g. `fvm flutter pub get`, `fvm flutter run -d linux`), not the bare
`flutter`/`dart` binaries.

Game library, download and Proton-GE logic come from the `gogdl_flutter` Rust bridge package,
fetched over SSH from `ssh://git@thinkcentre.home:2200/gogdl/gogdl_flutter.git` (see
`pubspec.yaml`). Building this project therefore currently requires LAN access to
`thinkcentre.home` plus an SSH key authorized on it. A full README rewrite (system requirements,
CI details, etc.) is tracked for `v1.5.0`.

## Checks

GitLab CI runs on merge requests and `v*` tags: `lint` (`dart format` and `flutter analyze --fatal-infos`),
`test`, and a dependency scan (`bridge-lock`, `scan`, `scan-gate`: OSV-Scanner on `pubspec.lock` and the
bridge's `Cargo.lock`). The scan also runs weekly on a pipeline schedule (`SCHEDULE=scan`). `main` is
protected, so every change goes through a merge request. See `SECURITY.md` for the dependency rules.

Renovate (`renovate.json`) runs from a second weekly schedule (`SCHEDULE=renovate`) and opens one MR for all minor
and patch updates of pub packages and the public CI images. Majors are off except security fixes, every release waits
7 days, and `gogdl_flutter`, the CI image and `.fvmrc` stay manual. The job needs `RENOVATE_TOKEN` (project access
token, `api` + `write_repository`, role Developer) and `GITHUB_COM_TOKEN` (no permissions), both masked and
**protected** with environment scope `renovate`.

Enable the format pre-commit hook once per clone:

```sh
git config core.hooksPath .githooks
```

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
