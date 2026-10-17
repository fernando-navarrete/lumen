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

## 4. Packaging and distribution

- [ ] **P2 — Flatpak and `.deb`.** The spike on `org.freedesktop.Platform` failed at startup (no GTK 3
  or `libsecret`); it needs `org.gnome.Platform` (408 MB download) or a bundled GTK. The Secret
  Service, file-chooser portal paths and Proton inside the sandbox weren't tested.
- [ ] **P1 — GitHub releases.** Releases live on the self-hosted GitLab, which users can't reach, and
  the GitHub mirror carries none. A `github-release` job after `release` would wait for the push
  mirror to deliver the tag (it is asynchronous), refuse unless GitHub's tag is at `CI_COMMIT_SHA`,
  then create the release from `release_notes.md` with the AppImage and `.sha256` from `package`,
  and upload with `--clobber` on a re-run. It needs a fine-grained token (`Contents: read and write` on
  `lumen` only, with an expiry), protected and scoped to a `github-release` environment like
  `RENOVATE_TOKEN`, and a `gh` image pinned by digest. (`v1.6.0`)
- [ ] **P1 — AUR package.** `lumen` is taken on the AUR (an unrelated CLI that also installs
  `/usr/bin/lumen`), so a name like `lumen-gog-bin` installing `/usr/bin/lumen-gog`. A
  `linux/packaging/aur/PKGBUILD.in` template whose `source` is the GitHub release URL (so it needs
  GitHub releases first); it extracts the AppImage in `prepare()` into `/opt/lumen-gog`, so pacman
  owns the files and no FUSE is needed, and installs the `.desktop` file (with `Exec` rewritten),
  icons and metainfo. An `aur` job after `github-release`, in a digest-pinned `archlinux:base-devel`
  image as a non-root user: fill in the version and sha256, `makepkg -f` to prove it builds (optionally
  `namcap`), regenerate `.SRCINFO`, and push to `ssh://aur@aur.archlinux.org/<name>.git`, skipping the
  commit when nothing changed. A dedicated SSH key as a protected file variable scoped to an `aur`
  environment, and known hosts pinned to the AUR's published fingerprints (no `ssh-keyscan`). The
  first push, which creates the package, is done by hand. (`v1.6.0`)
- [ ] **P2 — AppImage auto-update.** Embed update information with `appimagetool -u
  "gh-releases-zsync|fernando-navarrete|lumen|latest|Lumen-*-x86_64.AppImage.zsync"` in
  `tool/build_appimage.sh` and upload the generated `.zsync` with the release, so Gear Lever,
  AppImageUpdate and AppImageLauncher update Lumen in place on any distro. Needs GitHub releases.
  (`v1.6.0`)
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
- [ ] **P2 — Mirror token expiry is a calendar reminder.** The GitHub mirror token expires about
  2027-01-06 (check the exact date on GitHub's token page). An expired token fails silently; look at
  Settings → Repository → Mirroring.
- [ ] **P2 — The GitHub rulesets don't stop the owner moving a tag.** Their bypass is the Repository
  admin role, so the mirror can push a restore. GitLab's `v*` protection is the guard; compare
  `git ls-remote` on both sides after any tag incident.
