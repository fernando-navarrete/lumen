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

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
