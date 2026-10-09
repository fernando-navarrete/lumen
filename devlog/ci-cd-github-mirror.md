# Devlog — CI/CD: public GitHub mirror, a clone that builds anywhere

Finished Lumen's CI/CD the way `gogdl_flutter` finished its own (`devlog/v1.3.x-ci-cd.md` there), 2026-10-08:
a full-history secret scan, a license, a real README, a public read-only push mirror on GitHub and, the point
of it, **a clone from GitHub that builds with no SSH key, no LAN access and no git setting**. Ran as steps
0–13 of a work plan (deleted with this devlog) over squash MRs: !7 `7e4e037` (steps 1–3), !8 `4716d63`
(step 4's `SECURITY.md`, `.gitleaks.toml`, the `secrets` job), !10 `957a5ea` (step 6's bite test recorded,
step 7), !11 `49644dc` (steps 8–9: licenses, metadata, README), !12 `6274ece` (step 10), !13 `0beb372`
(step 11) and this one (steps 12–13). !9, the `secrets` bite test, was closed unmerged. SHAs are the
commits on `main`. This file keeps the decisions and pitfalls that aren't obvious from the diff.

## Step 0 — Decisions

- **D1 `gogdl_flutter` source:** `https://github.com/fernando-navarrete/gogdl_flutter.git` in
  `pubspec.yaml` for everyone, CI included (gogdl_flutter's D10 reversal: an `insteadOf` rewrite left a
  GitHub clone broken). CI then proves on every MR that a clone resolves without a key.
- **D2 bridge version:** `v1.3.3` (not `v1.3.1`, which has no GitLab release). Its `rustls` 0.23.45 clears
  RUSTSEC-2026-0285, so the `osv-scanner.toml` entry went.
- **D3 CI image:** `…-frb-2.13.0-r2`: same Flutter/Rust/frb, digest-pinned base, `rustup-init` checked by sha256.
- **D4 license:** `MIT OR Apache-2.0`, as gogdl_flutter and gogdl-lib.
- **D5 mirror:** public `fernando-navarrete/lumen`, read-only; issues, projects, wiki, discussions and
  Actions off.
- **D6 push:** GitLab's built-in push mirror, protected branches only, so no CI job gets the token and
  feature branches never reach GitHub.
- **D7 rulesets:** `main` and `v*`: no deletion, no force push, bypass for the Repository admin role. On a
  personal repo the fine-grained token acts as the owner, so that is the only bypass that lets the mirror
  push a restore (gogdl-lib's no-bypass ruleset rejected one).
- **D8 pin check:** `tool/check_bridge_pin.sh` in `lint` (Lumen has no `release` job). It reads github.com,
  so it also catches a GitHub tag that moved after the lock was written.
- **D9 LAN details in history:** kept (`thinkcentre.home`, port 2200, the `extra_hosts` IP). Rewriting
  would change every SHA and tag.
- **D10 dependency rule:** git dependencies only from `https://github.com/fernando-navarrete/`;
  `check_lockfile.sh` no longer allows the `gogdl` group on `thinkcentre.home`.

## Steps 1–4 — Bridge from GitHub, CI without the key (`39f9888`, `070c0a6`)

- `gogdl_flutter` `v1.3.3` at `9ad8427` from GitHub, image `-r2`, RUSTSEC entry dropped. No API change, so
  `analyze` and the tests passed untouched.
- `.deploy-key`, Renovate's SSH `before_script` and every `GOGDL_DEPLOY_KEY_B64` mention left
  `.gitlab-ci.yml`. Checked locally with `GIT_SSH_COMMAND=false`, empty `PUB_CACHE` and `CARGO_HOME`.
- `check_bridge_pin.sh`: the url must be the GitHub one, the `ref` a `vX.Y.Z` tag, and `git ls-remote`
  (peeled `^{}` line when annotated; `v1.3.0` is, `v1.3.3` isn't) must give `resolved-ref`. Red locally on a
  wrong SHA, a missing tag, a branch or SHA ref, the old LAN url and no `gogdl_flutter` package; green on
  the real lock and on `v1.3.0` in a scratch lock.
- Step 4 (settings, after merge): variable and deploy key deleted; "Weekly scan" and "Renovate" played by
  hand, both green.

## Steps 5–7 — Secrets (`392d31c`, `070c0a6`)

- Full-history gitleaks v8.30.1 (pinned by digest, repo read-only, `--network none`): 194 commits on all
  refs, 184 scanned (it counts only commits with additions), every branch and tag covered, **no leaks**,
  so `.gitleaks.toml` has no allowlist. A manual pass over `git log --all -p` found no `.env*`/key/cert
  files, no token values and no fixtures shaped like secrets; the only personal path is `/home/fernando`
  (accepted like D9).
- `secrets` job: the MR range `$CI_MERGE_REQUEST_DIFF_BASE_SHA..HEAD`, otherwise `HEAD --remotes --tags`.
  Bite test !9: a fake `ghp_` token turned it red.
- `SECURITY.md` no longer calls the project private; the rotation list has the mirror token and lost the
  deploy key.

## Steps 8–9 — License, metadata, README (`d2d599c`)

- `LICENSE-MIT`/`LICENSE-APACHE`, a real `pubspec.yaml` description and `repository:`, template comments
  and the unused `cupertino_icons` gone. The window and header-bar title say `Lumen`.
- **Decision:** `APPLICATION_ID` stays `io.github.fernandonr189.lumen`. It names the SharedPreferences
  directory and the keyring label/account, so changing it would orphan every install's games, Proton
  registry and login token.
- README replaces the Flutter template: what Lumen is, "Building from a clone", Development (the gates,
  the hook), "This repository is a mirror", License.

## Steps 10–11 — GitHub repo and push mirror (`a454b04`, `c9bd0de`)

- Repo created empty; rulesets "Protect main" (24766406) and "Protect tags" (24766408), both active. The
  fine-grained token (`Contents: read and write` on `lumen` only) has a 90-day expiry, so **about
  2027-01-06**.
- After the first "Update now", `main` and all 30 tags matched GitLab SHAs (34 ref lines each, peeled
  lines included) and `main` was the only branch on GitHub. A pushed feature branch stayed off GitHub;
  its merge moved `main` on both sides.

## Step 12 — Clean-room clone

- The `-r2` image wasn't on the laptop, so it was built from a GitHub clone of gogdl_flutter `v1.3.3` with
  `ci/build-image.sh`. In a container with no `extra_hosts`, an empty `~/.ssh` and `GIT_SSH_COMMAND=false`:
  clone, both pin checks, `pub get --enforce-lockfile`, `analyze --fatal-infos`, 362 tests and
  `build linux` green.
- A second run on `debian:trixie-slim` with a non-root user, following only the README: green after the
  README gained `git`, `curl`, `unzip`, `xz-utils` and `ca-certificates` (fvm, Flutter and rustup need
  them on a minimal system). Rerun from GitHub `main` at `c9bd0de`: green.

## Pitfalls

- **Squash messages again.** GitLab titled !7, !8 and !11 from the branch's first commit ("GitHub mirror
  work plan", "retire the deploy key", "license, package metadata"), which undersell their MRs, despite the
  plan's warning. Set the title when opening and check the merge widget.
- **LAN DNS leaks into Docker.** The laptop's resolver knows `thinkcentre.home` and Docker copies it, so a
  "clean-room" container still resolved it. Run with `--dns 1.1.1.1 --dns 9.9.9.9` and confirm
  `getent hosts thinkcentre.home` fails.
- **The bridge's CI image has no `libsecret-1-dev`**, so `build linux` there needs an `apt install` first.
  That is the image's gap, not Lumen's.

## Left for later

Tracked in `GAPS.md` §7: the mirror token's expiry (a calendar reminder only, and an expired token fails
silently), the rulesets' admin bypass (GitLab's `v*` protection is the real guard, an `ls-remote`
comparison the check), and `check_bridge_pin.sh`, which hasn't run in a `v*` tag pipeline yet.
