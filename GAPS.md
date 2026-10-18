# GAPS

Open gaps, bugs and improvement opportunities in Lumen. Add new findings under the matching section,
and delete an item once it ships (the release's devlog keeps how it was fixed). Items scheduled for a
release are listed in [ROADMAP.md](ROADMAP.md).

Priority tags: **P0** = broken behavior users will hit · **P1** = important gap · **P2** = polish / cleanup.

---

## 1. Bugs

- [ ] **P2 — "Prefix has an invalid version?!"** after a Proton-GE upgrade (11-6 → 11-7) on an existing
  prefix; the game exited with code 5.
- [ ] **P2 — The bridge panics without a system CA bundle** (`reqwest`: "No CA certificates were loaded
  from the system"). Documented in the README's host requirements and the `1.5.0` known issues; not
  handled.
- [ ] **P2 — Old keyring item left behind after the `v1.5.0` application ID change.** The
  SharedPreferences file is copied to `io.github.fernando_navarrete.Lumen` on first start, but the
  keyring item (`flutter_secure_storage_linux` names its schema and account after the ID) is not, so
  each install signs in once more and the old `io.github.fernandonr189.lumen/FlutterSecureStorage`
  token stays in the keyring. Delete it from Passwords and Keys (or
  `secret-tool clear account io.github.fernandonr189.lumen.secureStorage`), or have `Account` remove
  it. The old `~/.local/share/io.github.fernandonr189.lumen/` is kept on purpose, so a downgrade
  still works.

## 2. Missing features

- [ ] **P2 — Prefix tools.** "Open prefix folder", "reset prefix", winecfg and winetricks, plus an
  "open install folder" action. (`v1.7.0`)
- [ ] **P2 — Desktop notifications** when a download, repair or sync finishes. (`v1.7.0`)
- [ ] **P2 — Playtime and last-played tracking** (the hero banner already says "CONTINUE PLAYING").
  (`v1.7.0`)
- [ ] **P2 — `.desktop` shortcuts / launch by game id** from outside the app. (`v1.7.0`)
- [ ] **P2 — Cancel a Proton-GE download.** The bridge takes a `CancelToken` and gogdl-lib cleans up a
  dropped extraction, so only `ProtonNotifier` (which ignores `Cancelled`) and a UI action are missing.
- [ ] **P2 — Cancel a save sync.** Same for `SavesNotifier`, which maps `Cancelled` to `failed` today.
- [ ] **P2 — Library sorting and an offline view.** Sort by name, last played (needs the playtime
  tracking) or install state, and show the library without a connection (nothing GOG returns is
  persisted across restarts).
- [ ] **P2 — Pin an installed build.** A deliberately rolled-back install keeps showing "Update
  available".
- [ ] **P2 — DLC Apply limits.** Only another Apply is blocked during the removal call, and there is no
  size estimate before Apply (only the freed bytes afterwards; `getInstallSize` fetches manifests per
  call).
- [ ] **P2 — Cap game log size.** Each launch truncates `<gameId>.log` and keeps one
  `<gameId>.previous.log`, but a single chatty session (`PROTON_LOG`-level output, a game spamming
  stderr) can still grow its log without bound. Cap it per launch (stop writing, or keep the head and
  tail) if that turns up in practice.
- [ ] **P2 — Big-game resume timing and free-space wording.** Resume's verification pass was only
  timed on a small game (a resume journal in gogdl-lib may be needed for big ones), and the
  free-space dialog can't name the mount because the bridge returns bytes only.

## 3. Not verified live

Tested against `FakeGogBackend` or on one desktop only.

- [ ] **P2 — Real-account flows.** Pause, resume, cancel, uninstall and the space dialog (`v1.3.0`); a
  game bought after launch appearing after Refresh, and DLC removal or install on a real install
  (`v1.4.0`).
- [ ] **P2 — The AppImage.** Not run on a clean Ubuntu with a real install, launch and stop, nor with a
  `/proc/<pid>/environ` check of a launched game; the window minimum size, `app_id` and icon are
  untested on GNOME, KDE and X11 (only Hyprland).
- [ ] **P2 — AppImage auto-update end to end.** `v1.6.0` is the first AppImage with update
  information, so an update through AppImageUpdate or Gear Lever (a delta only, and a result matching
  the release's `.sha256`) can first be checked with the release after it.

## 4. Packaging and distribution

- [ ] **P2 — Flatpak and `.deb`.** The spike on `org.freedesktop.Platform` failed at startup (no GTK 3
  or `libsecret`); it needs `org.gnome.Platform` (408 MB download) or a bundled GTK. The Secret
  Service, file-chooser portal paths and Proton inside the sandbox weren't tested.
- [ ] **P1 — AUR package.** Blocked: AUR account registration is closed, with no date to reopen
  (2026-10-17). Settled in `v1.6.0`'s investigation, to build on the GitHub releases (no backfill
  needed):
  - Names: `lumen` is taken (an unrelated Rust CLI), so package `lumen-gog-bin`,
    `provides=(lumen-gog)`, `conflicts=(lumen-gog)`, binary `/usr/bin/lumen-gog`, files under
    `/opt/lumen-gog`, and the `.desktop` file's `Exec=lumen-gog` via `sed` on the extracted copy.
  - A `linux/packaging/aur/PKGBUILD.in` template. `source`: the GitHub release's AppImage
    (`noextract`) plus `LICENSE-MIT` and `LICENSE-APACHE` from
    `raw.githubusercontent.com/fernando-navarrete/lumen/v$pkgver/` with their sha256;
    `license=('MIT OR Apache-2.0')`; `options=(!strip !debug)`. `prepare()` runs `chmod +x` and
    `--appimage-extract` (works under `makepkg` in a container, no FUSE), so pacman owns the files.
  - `depends` (namcap-quiet): `gtk3 libsecret hicolor-icon-theme libepoxy fontconfig glib2 glibc
    libgcc libstdc++ zlib cairo pango harfbuzz gdk-pixbuf2 at-spi2-core`; a Secret Service provider
    and a Vulkan driver as `optdepends`. Accepted namcap warnings: ELF under `/opt`, no FULL RELRO and
    unstripped prebuilt binaries, `libjvm.so` referenced by the `jni` package's `libdartjni.so`
    (never loaded).
  - The `aur` job after `github-release`: image `archlinux:base-devel` by digest
    (`sha256:061679925e5d5028f2df9395d441ce6c4b9accf0157ff3486c06b6962e014ef1` on 2026-10-17; refresh
    it), `pacman -S --noconfirm git openssh` at job time (recorded in SECURITY.md as an unpinned fetch
    from the Arch mirrors; base-devel has neither), a non-root `builder` user, `makepkg -f` to prove
    it builds, `.SRCINFO` only from `makepkg --printsrcinfo`, a push to
    `ssh://aur@aur.archlinux.org/lumen-gog-bin.git` only on a change, and a downgrade skipped by reading
    the AUR's current `pkgver`. `AUR_SSH_KEY` is a protected File variable in an `aur` environment
    (checked with `ssh-keygen -y -f`; base64 it if the File variable mangles it, as with the deploy key
    in `devlog/ci-cd-github-mirror.md`). A committed `known_hosts` checked against the AUR's published
    fingerprints with `StrictHostKeyChecking=yes`, no `ssh-keyscan`. On 2026-10-17: Ed25519
    `SHA256:RFzBCUItH9LZS0cKB5UE6ceAYhBD5C8GeOBip8Z11+4`, ECDSA
    `SHA256:uTa/0PndEgPZTf76e1DFqXKJEXKsn7m9ivhLQtzGOCI`, RSA
    `SHA256:5s5cIyReIfNNVGRFdDbe3hdYiI5OelHGpw2rOUud3Q8`; re-check them when the work resumes. A
    manual, no-key dry run on MRs.
  - Order when it resumes (one MR, `feat/aur`): an AUR account and a CI key
    (`ssh-keygen -t ed25519 -C lumen-aur-ci`); then the template, a `tool/render_pkgbuild.sh` and a
    local proof (`makepkg`, `namcap`, `pacman -U`, start `lumen-gog`) against the latest GitHub
    release, plus the first push (which creates the package) by hand; then the `aur` job, which only
    automates what already works by hand.
- [ ] **P2 — Build-host `RUNPATH` in a shipped plugin.** `libflutter_secure_storage_linux_plugin.so`
  carries the insecure `RUNPATH` `/home/fernando/repo/lumen/linux/flutter/ephemeral` (the build
  machine's checkout), and it ships in every AppImage. Found by `namcap`; harmless unless that path
  exists on the user's machine. Strip it at bundle time (`patchelf --remove-rpath` or
  `--set-rpath '$ORIGIN'`), or fix it in the plugin's CMake.
- [ ] **P2 — `.rpm`/`.deb` repositories through OBS or Copr.** The openSUSE Build Service can build for
  Fedora, openSUSE, Debian and Ubuntu from one spec, and both it and Copr take updates through an API,
  so a later job could follow the `aur` pattern. Official distro repositories (Debian, Fedora, Ubuntu)
  need a human packager or sponsor and aren't a CI job.

## 5. CI and supply chain

- [ ] **P2 — Scan in the dependency repos.** Run the same `scan` in `gogdl_flutter` and `gogdl-lib`, so
  a vulnerable crate is caught before Lumen pins the release.
- [ ] **P2 — MR coverage.** `flutter test --coverage` plus a Cobertura conversion.
- [ ] **P2 — CI image isn't digest-pinned.** `gogdl-flutter-ci` is built on the runner host and is in no
  registry.
- [ ] **P2 — No `lockFileMaintenance`.** Renovate moves transitive packages only through a direct bump,
  since maintenance would skip the 7-day wait. Revisit if the lockfile goes stale.
- [ ] **P2 — GitHub token expiry is a calendar reminder.** The GitHub mirror token expires about
  2027-01-06 (check the exact date on GitHub's token page). An expired token fails silently; look at
  Settings → Repository → Mirroring. `GITHUB_RELEASE_TOKEN` expires 2027-01-15; an expired one fails
  the tag's `github-release` job (a 401 naming the token), so rotate it before a release falls after
  that date (SECURITY.md, "Rotate secrets").
- [ ] **P2 — The GitHub rulesets don't stop the owner moving a tag.** Their bypass is the Repository
  admin role, so the mirror can push a restore. GitLab's `v*` protection is the guard; compare
  `git ls-remote` on both sides after any tag incident.
