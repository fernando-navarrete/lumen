## Summary

<!-- What changes and why. -->

## Checklist

- [ ] `fvm flutter analyze --fatal-infos` and `fvm flutter test` are green locally
- [ ] `pubspec.yaml` or `pubspec.lock` changed: listed the new packages (direct and transitive) in the description, and each meets the bar in `SECURITY.md`
- [ ] A git dependency changed: it comes from `https://github.com/fernando-navarrete/`, pinned by a `vX.Y.Z` tag, and `sh tool/check_bridge_pin.sh` passes
- [ ] `gogdl_flutter` ref or `.fvmrc` changed: moved `.ci-image` in `.gitlab-ci.yml` to the `flutter-rust` tag and digest whose Rust matches the bridge tag and whose Flutter matches `.fvmrc` (added in `infra/ci-images` first if missing), and `constraints.flutter` in `renovate.json` for `.fvmrc`
- [ ] Behavior or architecture changed: updated `CLAUDE.md` / `README.md`
- [ ] Fixed or found a gap: removed or added it in `GAPS.md`
