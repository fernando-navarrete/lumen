# CI/CD: public GitHub mirror, a clone that builds anywhere

Work plan to finish Lumen's CI/CD the way `../gogdl_flutter` finished its own
(`../gogdl_flutter/devlog/v1.3.x-ci-cd.md`, steps 9 and 14–18, plus its `v1.3.3`): a full-history
secret scan, a license, a real README, a public read-only push mirror on GitHub, and — the point of it —
**a clone from GitHub that builds with no SSH key, no LAN access and no git setting**. Every git
dependency therefore resolves from the public mirrors (`github.com/fernando-navarrete/*`), never from
`thinkcentre.home`. It ends with the mirror live, a clean-room clone green, and this plan turned into a
devlog.

Lumen's CI/CD Phases 1–3 (`devlog/ci-cd-merge-requests.md`) already cover what gogdl_flutter's steps
1–8 and 12–13 did: MR pipelines, the format hook, protected `main` and `v*`, the lockfile check, OSV
scanning with a weekly schedule, and Renovate. This plan only adds what's missing.

Inside an MR, each step is one commit on the branch. Merge method as usual (semi-linear; squash allowed
for CI and docs MRs). Bite tests run in throwaway MRs that are closed unmerged and don't count. Tick each
checkbox as it's done.

| MR | Branch | Steps | Title | Status |
|---|---|---|---|---|
| — | (none) | **0** | Decisions, blockers | ✅ |
| **1** | `ci/github-mirror` | 1–3 | `CI/CD: gogdl_flutter v1.3.3 from GitHub, no deploy key` | ✅ |
| — | (settings) | 4 | Retire the deploy key | ✅ |
| **2** | `ci/secrets` | 5–7 | `CI/CD: secret scan, full-history audit` | ✅ |
| **3** | `ci/mirror-content` | 8–9 | `CI/CD: license, README, what the mirror shows` | ✅ |
| — | (settings) | 10–11 | GitHub repo, GitLab push mirror | ✅ |
| — | (none) | 12 | Clean-room clone from GitHub | 🟦 |
| **4** | `docs/ci-github-mirror` | 13 | `Docs: GitHub mirror devlog, close out the plan` | ⬜ |

Status: ⬜ not started · 🟦 in progress · ✅ done · ⏸ blocked

Every MR: `fvm dart format --output=none --set-exit-if-changed lib test tool`, `fvm flutter analyze
--fatal-infos` and `fvm flutter test` pass locally, and the MR pipeline is green. **Set the MR title by
hand when opening it** and check the squash message in the merge widget: GitLab titles a new MR from the
branch's first commit (gogdl_flutter hit this three times).

## Starting point (2026-10-08)

- `main` at `87660ef`, newest tag `v1.3.0`, 190 commits on all refs, 30 tags (`v0.1.0`–`v1.3.0`), one
  author email (already public through the gogdl_flutter mirror). Branch `ci/github-mirror` is this one.
  `v1.4.0` work (`v1.4.0-LIBRARY.md`) runs in parallel through its own MRs.
- `pubspec.yaml` pins `gogdl_flutter` at `ssh://git@thinkcentre.home:2200/gogdl/gogdl_flutter.git`,
  `ref: v1.3.0` (`a5b7b5e`). Every other package in `pubspec.lock` is hosted on pub.dev.
  `tool/check_lockfile.sh` allows git packages only from that `gogdl` group.
- CI (`.gitlab-ci.yml`) loads `GOGDL_DEPLOY_KEY_B64` (masked, unprotected) in `.deploy-key` for `lint`,
  `test` and `bridge-lock`, and again in `renovate`'s `~/.ssh/config`. Image
  `gogdl-flutter-ci:flutter-3.47.2-rust-1.98.1-frb-2.13.0` (gogdl_flutter is on `-r2`; all three tags
  are on the runner host).
- `osv-scanner.toml` accepts RUSTSEC-2026-0285 (`rustls` 0.23.43 in `v1.3.0`'s `Cargo.lock`) until
  2026-11-06.
- No secret scan, no license file, README is the Flutter template ("A new Flutter project."), and so is
  `pubspec.yaml`'s `description`. `SECURITY.md` calls the project private. GAPS §7 has "The build isn't
  reproducible outside your LAN" ticked as *documented and deferred*, not fixed.
- Upstream is ready: `github.com/fernando-navarrete/gogdl_flutter` has `main` and `v1.3.3` at `9ad8427`.
  `v1.3.3` fetches `gogdl-lib` from `github.com/fernando-navarrete/gogdl-lib` over HTTPS (`v1.2.3` at
  `988011c` there), and carries `rustls` 0.23.45. No API change since `v1.3.0` (`CHANGELOG.md`
  1.3.1–1.3.3). `github.com/fernando-navarrete/lumen` doesn't exist yet.

### How gogdl_flutter maps here

| gogdl_flutter | here |
|---|---|
| Step 9: full-history gitleaks, `.gitleaks.toml`, `secrets` job | the same (steps 5–6) |
| Step 10: `SECURITY.md` | rotation list: mirror token in, deploy key out; no longer "private" (step 7) |
| Step 14: `LICENSE-*`, `repository:`, README "This repository is a mirror" | the same, plus a README that replaces the template (steps 8–9) |
| Step 15: GitHub repo, rulesets with the Repository admin bypass, fine-grained token | the same (step 10) |
| Step 16: GitLab built-in push mirror, protected refs only, `ls-remote` comparison | the same (step 11) |
| Step 17: `tool/check_lib_pin.sh` in `release` (pinned `gogdl-lib` tag on GitHub at the locked SHA) | `tool/check_bridge_pin.sh` in `lint` (pinned `gogdl_flutter` tag on GitHub at `resolved-ref`): Lumen has no `release` job, and `lint` runs on every MR and tag (step 3) |
| `v1.3.3` (D10 reversed): `gogdl-lib` from GitHub over HTTPS, deploy key gone | done **first** here (steps 1–2, 4), not as a fix-up afterwards |
| Step 18: devlog, GAPS, hand-offs, delete the plan | the same (step 13) |
| — | step 12: a clean-room clone proves the goal, which gogdl_flutter only checked with `GIT_SSH_COMMAND=false` |

---

## Step 0: Decisions and blockers

Recommended answers are in *italics*. The steps below assume them. **Accepted 2026-10-08: every
recommended answer, with D4 = `MIT OR Apache-2.0`** (`LICENSE-MIT` and `LICENSE-APACHE`, copied from
`../gogdl_flutter` in step 8). For D3, the `-r2` tag was confirmed in the runner host's local Docker images
on 2026-10-08.

- [x] **D1. Where `gogdl_flutter` comes from.** *`https://github.com/fernando-navarrete/gogdl_flutter.git`
      in `pubspec.yaml`, for everyone, CI included* — gogdl_flutter's D10 reversal: an `insteadOf`
      rewrite left a GitHub clone broken without it, so it switched to the GitHub URL in `v1.3.3`. GitLab
      stays where development happens; the mirrors keep the SHAs, so nothing in the lock depends on which
      side served it. CI then proves on every MR that a clone resolves without a key.
- [x] **D2. Bridge version.** *`v1.3.3`* (not `v1.3.1`, which has no GitLab release). It also clears
      RUSTSEC-2026-0285, so its `osv-scanner.toml` entry goes.
- [x] **D3. CI image tag.** *Move to `…-frb-2.13.0-r2` in MR 1*, as gogdl_flutter's plan expected
      ("Lumen keeps its old tag until its own MR"): same Flutter/Rust/frb, but a digest-pinned base and a
      `rustup-init` checked by sha256. Lumen doesn't use the extra tools in it (cargo-deny).
- [x] **D4. License.** *`MIT OR Apache-2.0`, as gogdl_flutter and gogdl-lib* (`LICENSE-MIT`,
      `LICENSE-APACHE`). The alternative is `GPL-3.0-or-later`, common for game launchers (Heroic,
      Lutris); pick it if forks shouldn't be able to close the source. Lumen copies no GPL code, so
      either works.
- [x] **D5. Mirror.** *Public, `fernando-navarrete/lumen`*, read-only. Issues, Projects, Wiki,
      Discussions and Actions off; the README says where to report problems.
- [x] **D6. How the mirror pushes.** *GitLab's built-in push mirror, protected branches only*, so no CI
      job gets the token and feature branches never reach GitHub (gogdl_flutter D7).
- [x] **D7. GitHub rulesets.** *`main` and `v*`: no deletion, no force push, bypass for the Repository
      admin role* (gogdl_flutter step 15). On a personal repo the fine-grained token acts as the owner,
      so that's the only bypass that lets the mirror push a restore; gogdl-lib's no-bypass ruleset
      rejected one (its B1). GitLab's `v*` protection stays the real guard, `ls-remote` the check.
- [x] **D8. Pin check placement.** *A `tool/check_bridge_pin.sh` step in `lint`*, since Lumen has no
      `release` job. It reads github.com, so it also catches a GitHub tag that moved after the lock was
      written (`--enforce-lockfile` fetches `resolved-ref` and wouldn't notice).
- [x] **D9. LAN details in history.** *Keep them.* The mirror publishes `thinkcentre.home`, port 2200 and
      the `extra_hosts` IP in `.gitlab-ci.yml`'s header. gogdl_flutter's mirror already exposes the same
      hostname and port, and a private-range IP reaches nothing from outside. Rewriting history would
      change every SHA and tag.
- [x] **D10. Dependency rule.** *Git dependencies only from `https://github.com/fernando-navarrete/`.*
      `check_lockfile.sh` stops allowing `ssh://git@thinkcentre.home:2200/gogdl/` at all, so a LAN-only
      URL can't come back by accident.

**Blockers, in other repos:**

- [x] **B1. `gogdl_flutter` `v1.3.3` on GitHub.** `git ls-remote` shows `refs/tags/v1.3.3` at `9ad8427`,
      the same as GitLab. Checked 2026-10-08, and re-checked the same day (`main` also at `9ad8427`).
- [x] **B2. `gogdl-lib` `v1.2.3` on GitHub at `988011c`** (what `v1.3.3`'s `rust/Cargo.lock` locks).
      Checked 2026-10-08; it was wrong once (gogdl_flutter's B1) and was fixed there. Re-checked the same
      day against `v1.3.3`'s `rust/Cargo.lock`: `gogdl-lib` 1.2.3 from
      `git+https://github.com/fernando-navarrete/gogdl-lib.git?tag=v1.2.3#988011c…` (HTTPS), `rustls` 0.23.45.
- [ ] **B3. (not blocking)** gogdl_flutter GAPS §6: gogdl-lib's `downstream` job still patches the
      `thinkcentre.home` URL. Doesn't affect Lumen's build; left there.

**Done when:** each answer is recorded here.

---

## MR 1: `ci/github-mirror`

This plan is the branch's first commit. Title the MR by hand.

### Step 1: `gogdl_flutter` `v1.3.3` from GitHub

- [x] `pubspec.yaml`: `url: https://github.com/fernando-navarrete/gogdl_flutter.git`, `ref: v1.3.3`.
      `fvm flutter pub get`, so `pubspec.lock` has `resolved-ref: 9ad8427…` and the GitHub `url`; only
      that entry may change in the lock diff.
- [x] `tool/check_lockfile.sh`: a git package must come from `"https://github.com/fernando-navarrete/`
      (D10). Locally: green on the new lock, red on the old one (`git show main:pubspec.lock`), and red on
      a hand-edited `ssh://` URL.
- [x] `osv-scanner.toml`: drop the RUSTSEC-2026-0285 entry (the bridge now has `rustls` 0.23.45). Keep the
      header.
- [x] `.gitlab-ci.yml`: image `…-frb-2.13.0-r2` (D3); the MR template's image checkbox still applies.
- [x] `fvm flutter analyze --fatal-infos` and `fvm flutter test` green against `v1.3.3` (no API change is
      expected; if anything breaks, record it here).

**Done when:** the lock pins `9ad8427` from GitHub and `scan-gate` is green without the RUSTSEC entry.

### Step 2: CI without the deploy key

- [x] Delete `.deploy-key` and its `!reference` in `.flutter` and `bridge-lock`. `pub get` fetches
      `gogdl_flutter` over HTTPS, and its Native Assets hook's cargo fetches `gogdl-lib` over HTTPS, so
      neither needs ssh, `~/.ssh/config` or `git-fetch-with-cli`.
- [x] `bridge-lock`: unchanged logic (it already reads `url` from `pubspec.lock`), now an HTTPS fetch from
      GitHub. Its comment says so.
- [x] `renovate`: drop the whole SSH `before_script`. `pub upgrade` re-resolves over HTTPS.
- [x] `.gitlab-ci.yml` header: replace the deploy-key paragraph with one like gogdl_flutter's `v1.3.3`
      header ("fetched from its public GitHub mirror over HTTPS … so CI proves that a clone builds
      anywhere"). Keep the `extra_hosts` note: the runner still needs `thinkcentre.home` to reach GitLab
      itself.
- [x] Locally, before pushing: `GIT_SSH_COMMAND=false fvm flutter pub get --enforce-lockfile` with an empty
      `PUB_CACHE` and `CARGO_HOME`, then `fvm flutter test`. Green means nothing reaches for ssh.
- [x] The MR pipeline is green with the variable still set (it's just unused now).

**Done when:** no job in `.gitlab-ci.yml` mentions `GOGDL_DEPLOY_KEY_B64`, ssh or `~/.ssh`, and the
pipeline is green.

### Step 3: The bridge pin check (`tool/check_bridge_pin.sh`)

- [x] Port gogdl_flutter's `tool/check_lib_pin.sh` (`v1.3.3` version) to `pubspec.lock`: read
      `gogdl_flutter`'s `url`, `ref` and `resolved-ref`; fail unless the url is
      `https://github.com/fernando-navarrete/gogdl_flutter.git` (or `$2`), the ref is a `vX.Y.Z` tag, and
      `git ls-remote <url> refs/tags/<ref> refs/tags/<ref>^{}` gives `resolved-ref` (the peeled `^{}`
      line when the tag is annotated; `v1.3.0` is, `v1.3.3` isn't). POSIX `sh`, like `check_lockfile.sh`.
- [x] `lint` runs it first (cheap, network only to github.com). Say so in the header's `lint` line.
- [x] Red cases, locally: a wrong `resolved-ref`, a missing tag (`v9.9.9`), a branch or SHA `ref`, the old
      `thinkcentre.home` url, no `gogdl_flutter` package. Green: the real lock, and `v1.3.0` (annotated)
      on a scratch lock.
- [x] `SECURITY.md` ("Adding a dependency", CI paragraph), README "Checks", `CLAUDE.md` (the `lint` and
      `check_lockfile.sh` sentences in "Commands") and the MR template: the GitHub-only rule and the pin
      check. `CLAUDE.md`'s "gogdl group on thinkcentre.home" wording goes.

**Done when:** `lint` runs the check green, and it was red on every case above.

### Step 4: Retire the deploy key (settings, after MR 1 merges)

Only after merge: an open MR branched before it still loads the key.

- [x] Rebase or merge `main` into any open branch (the `v1.4.0` MRs), so none still needs the key.
      (2026-10-08: `origin` has only `main`, nothing to rebase.)
- [x] Delete the `GOGDL_DEPLOY_KEY_B64` variable in Lumen. Remove Lumen's deploy key from the
      `gogdl_flutter` project. Delete the private key wherever it was generated.
- [x] Play "Weekly scan" and "Renovate" (`SCHEDULE=renovate`) by hand: both green, and Renovate's log shows
      the pub manager resolving `pubspec.lock` with no ssh error.
      (2026-10-08: variable and deploy key removed; both scheduled pipelines green.)
- [x] `SECURITY.md`: delete "The deploy key" section; the rotation list loses `GOGDL_DEPLOY_KEY_B64`.
      (Committed as MR 2's first commit.)

**Done when:** the variable and the deploy key are gone and the next MR pipeline is still green.

---

## MR 2: `ci/secrets`

Must merge before step 11: the mirror publishes the whole history and every tag, and a secret pushed to a
public repo has to be treated as leaked even if removed later.

### Step 5: Full-history secret audit

- [x] Run gogdl_flutter's pinned gitleaks image locally over everything:
      `gitleaks git . --log-opts="--all" --redact` (190+ commits, every branch, `origin/*`, all 30 tags).
      (2026-10-08: `gitleaks:v8.30.1@sha256:c00b6bd0…`, repo mounted read-only, `--network none`:
      **no leaks**. 194 commits on all refs, 186 non-merge; gitleaks reports 184 scanned because it only
      counts commits with additions, and it walks `git log -p -U0 --all`, so every ref and tag is covered.
      Only low-entropy `generic-api-key` candidates were skipped, none in a secret-shaped value.)
- [x] Review every finding. Likely candidates: test fixtures for the auth token (`test/`), the keyring
      error strings (`lib/common/keyring_error.dart`), GOG client ids in code. A **real** secret means stop:
      rotate it, then decide history rewrite vs. not mirroring before anything else.
      (No findings to review. `clientId`/`clientSecret` appear only as parameter names in removed code.)
- [x] Also grep the history for things gitleaks doesn't flag: real GOG tokens or refresh tokens pasted in
      test data, `.env` files, personal paths beyond `/home/fernando` (D9 covers the LAN details).
      (2026-10-08, over `git log --all -p`: no `.env*`/key/cert/`*secret*`/`*token*` file ever added; no
      `refresh_token`/`access_token`/`Bearer`/`client_secret` values; no token-like fixtures in `test/`; long
      strings are only sha256 digests. The only personal path is `/home/fernando`, from the old
      `path: /home/fernando/repo/gogdl_flutter` override, accepted like D9. Emails: the author's, already
      public via gogdl_flutter, `noreply@anthropic.com` and `git@thinkcentre.home`.)

**Done when:** no finding, or each one reviewed and recorded here as a false positive.
**Result:** no findings, so step 6's `.gitleaks.toml` has no allowlist.

### Step 6: `.gitleaks.toml` and the `secrets` job

- [x] `.gitleaks.toml` from gogdl_flutter's: default rules; allowlist entries only for step 5's reviewed
      false positives, each narrow (`targetRules` + `paths`/`regexes`) with a comment.
- [x] `secrets` job from gogdl_flutter's (same image and digest, `GIT_DEPTH: 0`, MR range
      `$CI_MERGE_REQUEST_DIFF_BASE_SHA..HEAD`, otherwise `HEAD --remotes --tags`, redacted JSON artifact).
      `.not-on-schedule` rules; stage `lint`. Header line for it.
      (2026-10-08: pinned gitleaks `v8.30.1`; locally `no leaks found` on `HEAD --remotes --tags`, 184 commits,
      and on `main..HEAD`.)
- [x] `renovate.json`: the gitleaks image digest is covered by the `gitlabci` `pinDigests` rule already;
      check that Renovate picks it up (no config change expected).
      (No change made; the `gitlabci` rule is the same one that covers the OSV image. To confirm on the
      next `SCHEDULE=renovate` run.)
- [x] Bite test: a fake `ghp_` token in a throwaway MR turns `secrets` red. Close it, delete the branch.
      (2026-10-08: !9, `secrets` red; closed unmerged, branch deleted. Step 6's first three boxes merged in MR 2.)

**Done when:** `secrets` is green here and was red on the bite test. ✔

### Step 7: `SECURITY.md` for a public repo

- [x] Intro: no longer "private"; the GitHub copy is a read-only mirror, and problems go to the maintainer
      directly (an email or the GitLab instance, whichever the README names in step 9).
      (2026-10-08: "maintainer directly, not in a public issue", no address, as gogdl_flutter; step 9's
      README uses the same wording.)
- [x] "The deploy key" goes (step 4). The rotation list gains the GitHub mirror token (a new fine-grained
      token, `Contents: read and write` on `lumen` only, pasted into Settings → Repository → Mirroring).
      (The section went in `4716d63`; the token is now in the rotation list.)
- [x] A short "Secrets" paragraph: `secrets` gates every MR; a leak found after the mirror pushed it is
      rotated first, history second.

**Done when:** merged.

---

## MR 3: `ci/mirror-content`

### Step 8: License and package metadata

- [x] `LICENSE-MIT` and `LICENSE-APACHE` (copy gogdl_flutter's, owner line updated) per D4.
      (2026-10-08: copied verbatim; the MIT owner line is already `2026 Fernando Navarrete`, the Apache text has none.)
- [x] `pubspec.yaml`: a real `description` (one line: GOG library manager, downloader and Proton launcher
      for Linux), `repository: https://github.com/fernando-navarrete/lumen`. Drop the template comments and
      `cupertino_icons` if unused (GAPS §7 P2) — only if `analyze`/`test` stay green; otherwise leave it
      for its own MR.
      (2026-10-08: description, `repository:`, template comments and `cupertino_icons` gone; the lock diff is
      only that entry.)
- [x] `linux/` metadata: check the application id and window title don't still say a template name.
      (Window and header-bar title now `Lumen`. `APPLICATION_ID` stays `io.github.fernandonr189.lumen`: it names
      the SharedPreferences directory and the keyring label/account, so changing it would orphan every
      install's games, Proton registry and login token.)

**Done when:** `fvm flutter pub get` leaves `pubspec.lock` untouched (or only drops `cupertino_icons`). ✔

### Step 9: README for someone who just cloned it

Replaces the Flutter template (GAPS §7 P1). Short, as gogdl_flutter's:

- [x] What Lumen is (one paragraph), Linux only, what it delegates to `gogdl_flutter`.
- [x] **Building from a clone**, with no LAN mention: `git clone https://github.com/fernando-navarrete/lumen`,
      fvm (the pinned Flutter in `.fvmrc`), rustup (the bridge's Native Assets hook installs Rust 1.98.1
      from its `rust-toolchain.toml` on the first build), the Linux build deps (`clang`, `cmake`, `ninja`,
      `pkg-config`, GTK 3 and `libsecret-1` dev packages), a running Secret Service (GNOME Keyring or
      KWallet) for login, network access to pub.dev, crates.io and github.com on the first build. Then
      `fvm flutter pub get`, `fvm flutter run -d linux`, `fvm flutter build linux`. Every command here is
      the one step 12 runs.
- [x] "Development": the gates and the pre-commit hook (move from "Checks"), CI kept brief and pointing to
      the `.gitlab-ci.yml` header.
- [x] "This repository is a mirror" (gogdl_flutter's wording): developed on a self-hosted GitLab, GitHub
      is a read-only push mirror of `main` and `v*`, issues and PRs off, how to report.
- [x] "License" section. Layout: `LICENSE-*`, `SECURITY.md`, `.gitleaks.toml`, `osv-scanner.toml`,
      `renovate.json`, `.githooks/`, `tool/`.
- [x] `CLAUDE.md`: one line that GitHub is a push mirror, and the GitHub-only dependency rule.
      (2026-10-08: no JDK needed, `jni` only looks for one optionally; README "Checks" is folded into
      "Development", and `SECURITY.md` points there. Real proof is step 12.)

**Done when:** merged, and nothing in README tells a reader to reach `thinkcentre.home`.

---

## Settings: GitHub and the push mirror

Need MR 2 merged (step 5 clean). MR 3 can merge after or before: it reaches GitHub on its own once the
mirror runs.

### Step 10: GitHub side

- [x] Create `fernando-navarrete/lumen`: empty (no README, license or `.gitignore`), public. Issues,
      Projects, Wiki, Discussions and Actions off.
      (2026-10-08: public, size 0, default branch `main`; issues, projects, wiki and discussions off as
      read from the API; Actions off confirmed in the UI.)
- [x] Rulesets per D7: "Protect Main" (`refs/heads/main`) and "Tag Rules" (`refs/tags/v*`), restrict
      deletions, block force pushes, bypass: Repository admin.
      (Created as "Protect main" (24766406) and "Protect tags" (24766408), both active, rules `deletion` +
      `non_fast_forward`. The Repository admin bypass is confirmed in the UI; the unauthenticated API
      doesn't show it.)
- [x] Fine-grained token: `Contents: read and write` on `lumen` only, with an expiry. Record the expiry
      date here (gogdl_flutter didn't, and it's a GAPS line there).
      (2026-10-08: generated with a 90-day expiry, so it expires on or about **2027-01-06**; check the exact
      date on GitHub's token page. Not pasted anywhere yet; step 11 puts it in GitLab's mirror settings.)

**Done when:** `git ls-remote https://github.com/fernando-navarrete/lumen.git` lists nothing and both
rulesets are active. ✔

### Step 11: GitLab push mirror

- [x] Settings → Repository → Mirroring repositories: `https://github.com/fernando-navarrete/lumen.git`,
      push, password auth (any username, the token as password), "Mirror only protected branches" on,
      "Keep divergent refs" off. "Update now".
- [x] Compare SHAs, not names: `git ls-remote origin 'refs/heads/main' 'refs/tags/*'` against the same on
      GitHub (peeled `^{}` lines included). `main` and all 30 tags match, no GitLab tag is missing, and
      GitHub has no other branch (`ci/*` must not be there).
      (2026-10-08: `main` at `d2d599c` and every tag matched; 34 ref lines each, peeled lines included;
      `main` was the only branch on GitHub.)
- [x] The next merge into `main` shows up on GitHub within minutes; a pushed feature branch never does.
      (2026-10-08: `docs/ci-github-mirror` stayed off GitHub after the push; its merge moved `main` to
      `a454b04` on both sides.)

**Done when:** all three checks hold. ✔

---

## Step 12: Clean-room clone from GitHub

The acceptance test for the whole plan: a machine that has never seen `thinkcentre.home`.

- [x] In a fresh container of the `-r2` CI image (Flutter and rustup baked in, so this tests Lumen, not the
      toolchain install), on the default Docker network with **no** `extra_hosts`, no `~/.ssh`, empty
      `PUB_CACHE`/`CARGO_HOME`, and `GIT_SSH_COMMAND=false`:
      `getent hosts thinkcentre.home` fails; then
      `git clone https://github.com/fernando-navarrete/lumen.git && cd lumen &&
      flutter pub get --enforce-lockfile && flutter analyze --fatal-infos && flutter test &&
      flutter build linux`.
      (2026-10-08: the `-r2` image isn't on the laptop, so it was built here from a GitHub clone of
      gogdl_flutter `v1.3.3` with `ci/build-image.sh`. `--dns 1.1.1.1 --dns 9.9.9.9`, because the laptop's
      LAN DNS resolves `thinkcentre.home` and Docker copies it: `getent` fails in the container, `~/.ssh` is
      empty, `GIT_SSH_COMMAND=false`. Cloned `a454b04`; `check_lockfile.sh`, `check_bridge_pin.sh`,
      `pub get --enforce-lockfile`, `analyze --fatal-infos`, 362 tests and `build linux` all green. The
      image has no `libsecret-1-dev`, so the script apt-installs it before the build: the bridge's image,
      not Lumen's, so no fix.)
- [x] Also once on a host with fvm, following only the README's "Building from a clone" (a scratch user or a
      distrobox), to catch a missing system package the image happens to have.
      (A `debian:trixie-slim` container, non-root user, same DNS override: the README's packages, fvm and
      rustup from their installers, then `fvm install`, `pub get`, `test` (362) and `build linux`: green.
      The README didn't name `git`, `curl`, `unzip`, `xz-utils` and `ca-certificates`, which fvm, Flutter
      and rustup need on a minimal system; added to "You need". I installed them up front, so I didn't
      test them one by one.)
- [ ] Any fix lands through an MR on GitLab, then this step is rerun.
      (The README line above is the only fix. Rerun run 2 from GitHub once this merge reaches it, then tick this box and the table row.)

**Done when:** both runs are green with no step outside the README.

---

## MR 4: `docs/ci-github-mirror`

### Step 13: Close-out

- [ ] `devlog/ci-cd-github-mirror.md`: decisions, pitfalls and bite tests, SHAs on `main`, in
      `devlog/ci-cd-merge-requests.md`'s format.
- [ ] GAPS §7: tick "The build isn't reproducible outside your LAN" (fixed: GitHub mirror + bridge `v1.3.3`),
      "README is the Flutter template", "RUSTSEC-2026-0285 accepted", and the `pubspec.yaml` cleanup if
      done. New open lines: mirror token expiry (date), the ruleset's admin bypass, `check_bridge_pin.sh`
      first run on a tag.
- [ ] `devlog/ci-cd-merge-requests.md` "Gotchas": the deploy-key bullets now point at this devlog.
- [ ] Hand-offs to `gogdl_flutter`: its GAPS §6 "Lumen still pins `v1.3.0`" is done; Lumen's B2 (pin check)
      lives in Lumen's `lint`.
- [ ] Delete this file in the same commit.

**Done when:** merged, the merge shows up on GitHub, and this plan is a devlog.
