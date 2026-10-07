# CI/CD work plan — merge requests, linting and dependency scanning

Bring Lumen's CI/CD up to the level of `metatrader-dashboard` (same GitLab at `thinkcentre.home`, same
runner):

1. **Security scans for vulnerable dependencies**, on every merge request and weekly on `main`.
2. **Linting**, as a merge gate.
3. **A protected `main` and merge-request workflow.** Nobody pushes to `main`, and nothing merges with a red
   pipeline.

When this plan is done, the repository has **one branch, `main`**, locally and on `origin`. Every later
branch is short-lived: it exists only while its MR is open and is deleted when the MR merges.

**MR budget: one required MR, one optional.** MRs are slow here (one runner, Native Assets cargo build on
every job), so the work is grouped. Phase 1 is the last direct push to `main`, then protection goes on.
Phase 2 is the one MR that delivers all three requirements. Phase 3 (Renovate plus closing docs) is
optional and can ride along with the first v1.4.0 MR instead.

Tick each checkbox as it's done.

## Where we start (2026-10-06)

| | Lumen today | metatrader-dashboard |
|---|---|---|
| Pipeline trigger | Tag pushes only | MRs, `main`, `v*` tags, schedules |
| Lint | `flutter analyze --fatal-infos` (on tags) | Prettier + ESLint gate, pre-commit hook |
| Dependency scan | None | `npm audit`, lockfile checks, OSV-Scanner, weekly scan schedule |
| `main` protection | None (direct pushes) | No pushes (owner included), pipeline must pass, threads resolved |
| Dependency updates | Manual | Renovate, weekly scheduled pipeline |
| MR template / `SECURITY.md` | None | Both |

Branches:

| Branch | State | Fate |
|---|---|---|
| `main` | `v1.3.0` | Stays |
| `release/v1.3.0` (local + origin) | Fully merged into `main` | Delete in Phase 1 |
| `release/v1.4.0` (local + origin) | One commit ahead of `main` (`60b8982`, v1.4.0 Phase 0: only adds `v1.4.0-LIBRARY.md`), fast-forwardable | Fast-forward `main` to it, then delete, in Phase 1 |
| `origin/restart` | Fully merged into `main` (last commit 2026-09-07) | Delete in Phase 1 |

Other facts that shape the plan:

- The code is already `dart format`-clean (113 files, 0 changed), so a format gate needs no mass
  reformat and no `.git-blame-ignore-revs`.
- Dart has no `npm audit` equivalent. **OSV-Scanner reads `pubspec.lock`** (pub ecosystem), so it is the
  vulnerability gate, not just the malware gate as in metatrader.
- Most of the code that actually ships is Rust: `gogdl_flutter`'s `rust/Cargo.lock` (which also pins
  `gogdl-lib`) is built into the app by the Native Assets hook. Scanning only `pubspec.lock` would miss it,
  so the scan covers that `Cargo.lock` at the exact ref Lumen pins.
- `gogdl_flutter` is a private git dependency reached over SSH with `GOGDL_DEPLOY_KEY_B64`. MR pipelines
  run on unprotected branches, so **that variable must stay unprotected** (masked only), or every MR
  pipeline fails at `pub get`. It's a read-only deploy key, so the risk is acceptable for a
  single-operator repo. Record that decision in `SECURITY.md`.
- The CI image (`gogdl-flutter-ci:…`) is built locally on the runner host and isn't in a registry, so it
  can't be digest-pinned or Renovate-managed. Public images (OSV-Scanner, Renovate) are pinned as
  `tag@sha256`, as in metatrader.

## Decisions

- **Merge method: "Merge commit with semi-linear history".** The MR must be rebased onto `main` (so the
  pipeline tested exactly what lands), and `main` still gets one merge commit per MR with its phase commits
  underneath. That keeps Lumen's existing "one merge per release, phases underneath" history. **Squash:
  "Allow"**, used for CI and docs MRs and for any MR whose branch has red/revert commits. Feature MRs keep
  their phase commits.
- **No pipeline on pushes to `main`.** With semi-linear merges, `main` only ever receives a tree the MR
  pipeline already tested, and the runner is shared. Pipelines run for MRs, `v*` tags and schedules.
- **No required approvals.** Single developer, and GitLab doesn't let you approve your own MR by default.
  The gate is the pipeline plus resolved threads.
- **Vulnerability gate:** any OSV vulnerability advisory in either lockfile fails `scan`, on MRs, `v*`
  tags and the weekly schedule alike, unless it's listed in `osv-scanner.toml` with a `reason` and an
  `ignoreUntil` date, so an accepted finding comes back on its own. RUSTSEC informational advisories
  (`unmaintained`, `unsound`, `notice`) are printed in the log and kept in the report but never fail the
  job. A newly published advisory turns every open MR red until it's fixed or ignored. That's intended:
  `main` must not accept merges while a known vulnerability is unaddressed.
- **v1.4.0 keeps going, but without a release branch.** Each v1.4.0 MR bundles several phases, and `main`
  must stay releasable after each one. A `v1.3.x` hotfix: branch `hotfix/v1.3.x` from the `v1.3.0` tag, fix,
  push the `v1.3.x` tag (its tag pipeline is the hotfix's CI, since a branch with no MR gets no pipeline),
  then cherry-pick the fix (`git cherry-pick -x`) onto a fresh branch from `main` and merge it through a
  normal MR. Delete the hotfix branch once tagged. The tag keeps its commits reachable. Never rebase the
  tagged branch onto `main`, because semi-linear would then land different SHAs than the ones tagged.

## Phase 0 — Investigation (local only, no push)

- [x] Run OSV-Scanner locally on `pubspec.lock`, using the pinned image from metatrader
      (`ghcr.io/google/osv-scanner:v2.6.0@sha256:afd8…`). Record the baseline: which advisories, and for
      each one either "fix by bumping" or "accept until <date>".
- [x] Same for `gogdl_flutter`'s `rust/Cargo.lock` at the `resolved-ref` in `pubspec.lock`. Note the
      RUSTSEC "unmaintained"/informational entries separately. They don't gate (see Decisions). Find how
      informational entries show up in OSV-Scanner's JSON (e.g. `database_specific.informational` on the
      RUSTSEC record) and confirm the OSV image's `/bin/sh` can filter on it without `jq`; if it can't,
      the filter runs in `bridge-lock`'s CI image on the artifact. Any real finding needs a bridge release to fix, so list them as an
      ignore with an expiry plus a follow-up in `gogdl_flutter`'s GAPS.
- [x] Check that a throwaway lockfile with a known-vulnerable version makes OSV exit 1. Note the exit
      codes (0 clean, 1 findings, anything else an error, which must fail the job too).
- [x] Lint candidates. Enable these in `analysis_options.yaml` locally and count the findings:
      `unawaited_futures`, `cancel_subscriptions`, `close_sinks`, `avoid_dynamic_calls`,
      `prefer_final_locals`, `directives_ordering`, `always_declare_return_types`. The first three catch
      real bugs in stream-heavy notifier code. Adopt each rule whose findings fit in Phase 2. Put the rest
      in GAPS with their counts.
- [x] Check that `fvm flutter pub get --enforce-lockfile` passes on a clean checkout. It fails if
      `pubspec.lock` is stale or a hosted package's sha256 changed.
- [x] Renovate feasibility, which decides Phase 3. Can Renovate's `pub` manager update `pubspec.lock`
      when one dependency is SSH-only (`ignoreDeps: ["gogdl_flutter"]` still leaves it in the lockfile)?
      Check whether the `fvm` manager handles `.fvmrc`. If either can't work cleanly, drop Phase 3's
      Renovate part.
- [x] Check in GitLab (version and settings) that semi-linear merge, "Pipelines must succeed", "All
      threads must be resolved", "Auto-cancel redundant pipelines" and protected tags are all available.

### Phase 0 findings (2026-10-06)

Everything below was run locally with nothing committed or pushed. All Phase 0 boxes are ticked; the GitLab
settings check was done by hand (see the end of this section).

**OSV baseline** (OSV-Scanner v2.6.0, the pinned image)

- `pubspec.lock` (120 packages): clean, exit 0. Nothing to bump or ignore.
- Bridge `rust/Cargo.lock` at `a5b7b5e1` (266 crates), exit 1:

  | Advisory | Crate | Kind | Fixed in | Decision |
  |---|---|---|---|---|
  | RUSTSEC-2026-0285 / GHSA-2mjx-qc3c-rqvc | `rustls` 0.23.43 | **vulnerability** (TLS 1.3 handshake, CVSS 5.3) | 0.23.45 | Needs a bridge release. Ignore until a date in `osv-scanner.toml` and add a follow-up to `gogdl_flutter` GAPS. Published 2026-10-05, so it's brand new. |
  | RUSTSEC-2026-0190 | `anyhow` 1.0.75 | informational (`unsound`) | 1.0.103 | Reported only, never gates. |
  | RUSTSEC-2025-0056 | `adler` 1.0.2 | informational (`unmaintained`) | none (use `adler2`) | Reported only, never gates. |

- Where "informational" lives: `vulnerabilities[].affected[].database_specific.informational`. It is a string
  (`unmaintained`, `unsound`), or `null` for real vulnerabilities. GHSA records have no such field.
- The OSV image has busybox `sh`, `grep`, `sed`, `awk` and `tr`, but no `jq`. The JSON is pretty-printed, so a
  `grep` can count the flags (2 informational, 1 null here), but mapping a flag back to its advisory id means
  tracking nesting in `awk`, which is fragile. **Decision (revised in Phase 2): the CI image has no `jq`
  either, but it has `dart`, so `scan-gate` runs `tool/osv_gate.dart`, a dependency-free script with unit
  tests.** `scan` only runs the scanner (exit 0 or 1), and `scan-gate` decides pass or fail from the JSON.
- Since an ignore is per advisory id, an alternative needs no filtering: list the informational ids in
  `osv-scanner.toml` as well. That gets noisy, and a new informational id would turn the job red, so it isn't
  recommended.

**Exit codes**

- 0: clean. 1: findings. 127: bad path or an offline run with no cached DB. All non-0/1 codes must fail the job.
- Ignoring one id filters its aliases too (`RUSTSEC-2018-0018 and 3 aliases`). The job still exits 1 while
  any other advisory remains, so every finding must be ignored or fixed before the job passes.

**Lint candidates** (`flutter analyze`, 58 infos in total)

| Rule | lib | test | Recommendation |
|---|---|---|---|
| `always_declare_return_types` | 0 | 0 | Adopt |
| `cancel_subscriptions` | 0 | 0 | Adopt |
| `unawaited_futures` | 1 (`launch_state.dart:366`) | 0 | Adopt, fix the one site |
| `close_sinks` | 1 (`launch_state.dart:531`, the log sink) | 10 | Adopt. Check whether the lib site is a real leak, `// ignore` the stream-test sinks |
| `avoid_dynamic_calls` | 0 | 3 (`saves_state_test.dart`) | Adopt, fix the 3 test sites |
| `directives_ordering` | 11 | 4 | Adopt (mechanical, `dart fix --apply`) |
| `prefer_final_locals` | 28 | 0 | Adopt (mechanical, `dart fix --apply`) |

All seven fit in the Phase 2 MR, so none go to GAPS.

**Lockfile and tools**

- `flutter pub get --enforce-lockfile` passes on a fresh clone (about 1s, with warm caches).
- Renovate 44.138.0 (local image), extract only: `pub` finds 13 deps in `pubspec.yaml` (it skips
  `gogdl_flutter` under `ignoreDeps`), `fvm` reads `.fvmrc` (`flutter 3.47.2`), `gitlabci` sees the CI image
  as `gogdl-flutter-ci`. Two consequences:
  - `gogdl-flutter-ci` must go in `ignoreDeps` too. It's a local image and Renovate can't look it up.
  - The `fvm` manager would bump `.fvmrc` alone, while the CI image tag, the bridge's Rust pin and `pubspec`
    must move together. Disable `fvm` and keep `.fvmrc` manual.
- **Not verified:** that a lockfile update (`pub get` in Renovate's container) works while an SSH-only dep is
  in the lockfile. Only a real Renovate run shows that. Phase 3 stays optional, and its first run has to be
  watched.

**GitLab settings:** checked by hand by the maintainer on 2026-10-06 (no version or gaps recorded).

## Phase 1 — Bootstrap: branch cleanup and protection (last direct push)

Docs-only commits, done before protection so they cost no MR.

- [x] `git switch main && git merge --ff-only release/v1.4.0`, which brings v1.4.0 Phase 0 to `main`.
- [x] Rewrite the **Branching** section of `v1.4.0-LIBRARY.md` for the MR workflow. No `release/v1.4.0`,
      no `rc` tag to get CI, phases grouped into a few MRs (proposal: 1–4, 5–6 once the bridge is tagged,
      7–9). Each MR leaves `main` releasable. Phase 9 tags `v1.4.0` on `main` after its MR merges.
      Patches P1–P3 are one MR each, or one MR for all three with a tag per merge commit, tagged on
      `main`'s merge commit. Only `v1.3.x` hotfixes use the cherry-pick path in Decisions.
- [x] Commit this plan and the rewrite on `main` (one commit), push `main`.
- [x] Delete the old branches:
      `git push origin --delete release/v1.3.0 release/v1.4.0 restart` and
      `git branch -d release/v1.3.0 release/v1.4.0`.
- [x] GitLab → Settings → Merge requests: semi-linear merge method; squash "Allow"; "Delete source branch"
      on by default; "Pipelines must succeed"; "All threads must be resolved"; "Skipped pipelines are
      considered successful" **off**.
- [x] Settings → CI/CD → General pipelines: "Auto-cancel redundant pipelines" on.
- [x] Settings → Repository → Protected branches: `main`, allowed to push **No one**, allowed to merge
      Maintainers, force push off.
- [x] Protected tags: `v*`, allowed to create Maintainers.
- [x] Settings → CI/CD → Variables: `GOGDL_DEPLOY_KEY_B64` masked and **not** protected.
- [x] Check that `git push origin main` with a dummy local commit is rejected, then drop the commit.

## Phase 2 — MR 1: merge-request pipeline, lint gates, dependency scanning

Branch `ci/merge-requests`. One MR, squash-merged.

**2a. Pipeline triggers** (`.gitlab-ci.yml`)
- [x] Replace the tags-only `workflow:` with: schedules; `merge_request_event`; branch push with an open
      MR → never; `v*` tags. No `main` push pipeline (see Decisions).
- [x] `default: interruptible: true`. Stages `lint`, `test`, `scan`.
- [x] Every non-schedule job: `rules: schedule → never`. Then add `$SCHEDULE == "scan"` rules to the
      scan jobs only, as in metatrader.
- [x] Rewrite the header comment so it covers each job, the schedules and the variables, like
      metatrader's header.

**2b. Lint** (replaces `analyze`)
- [x] Job `lint`: `dart format --output=none --set-exit-if-changed lib test` first (cheap), then
      `flutter analyze --fatal-infos`.
- [x] `analysis_options.yaml`: add the rules Phase 0 kept and fix their findings in the same MR.
- [x] `.githooks/pre-commit`: format check on staged `.dart` files only (no analyze, no tests; CI runs
      those). Enable once per clone with `git config core.hooksPath .githooks`. Check only, never rewrite,
      for the same reason as metatrader's hook.

**2c. Lockfile integrity**
- [x] The shared setup runs `flutter pub get --enforce-lockfile`.
- [x] A small check (shell in `lint`, or `tool/check_lockfile.sh`) that fails if any hosted package in
      `pubspec.lock` comes from somewhere other than `https://pub.dev`, or any git package from somewhere
      other than `ssh://git@thinkcentre.home:2200/gogdl/`.

**2d. Dependency scan**
- [x] Job `bridge-lock` (CI image plus the deploy-key setup, **no** `pub get`, no cargo). Read
      `gogdl_flutter`'s `resolved-ref` from `pubspec.lock`, shallow-fetch that commit, and export
      `rust/Cargo.lock` as an artifact (`bridge-Cargo.lock`, 30 days).
- [x] Job `scan` (OSV-Scanner image, digest-pinned, `needs: [bridge-lock]`): scan `pubspec.lock` and
      `bridge-Cargo.lock` with `--config osv-scanner.toml`. Exit 0 passes and 1 fails; anything else is
      a scanner or network error and fails too. Exit 1 fails only if a non-informational advisory remains
      after the ignores; informational-only results pass with the IDs printed. Keep the JSON reports as artifacts (30 days) and print
      the advisory IDs in the log.
- [x] `osv-scanner.toml` with the Phase 0 baseline. Each accepted advisory gets `ignoreUntil` and a
      `reason`, and anything not accepted is fixed in this MR.
- [x] `test` keeps its current setup, plus `--enforce-lockfile`.

**2e. MR workflow files**
- [x] `.gitlab/merge_request_templates/Default.md`: summary; checklist with "analyze and test green
      locally", "`pubspec.yaml`/`pubspec.lock` changed → new packages listed, meet `SECURITY.md`",
      "`gogdl_flutter` ref or `.fvmrc` changed → CI image tag bumped", "CLAUDE.md/README updated if
      behavior or architecture changed".

**2f. Docs**
- [x] `SECURITY.md` (adapted from metatrader): the bar for a new pub package (needed, maintained,
      verified publisher where possible, at least 7 days old, few transitive deps); what `scan` gates (vulnerabilities fail,
      RUSTSEC informational only reported) and how to accept a finding; the hotfix cherry-pick rule; the unprotected deploy-key decision; what to do when a package is reported
      compromised (find it in both lockfiles, check CI logs, rotate the deploy key, pin, rerun the scan
      schedule, cut a patch tag).
- [x] `CLAUDE.md`: replace "CI … runs on every tag push (branch pushes don't trigger a pipeline)" with
      the new jobs and triggers, and add the branch/MR rule (`main` is protected, every change goes
      through an MR, semi-linear merge, source branch deleted).
- [x] `README.md`: a short "Checks" section (jobs, schedule, hook setup).

**2g. Prove the gates in this MR** (no throwaway MRs)

> 2g was skipped in MR 1 and is run afterwards in a follow-up MR, branch `ci/prove-gates-2` (squash-merged, so
> its red/revert commits don't reach `main`). The first attempt, `ci/prove-gates`, merged on its baseline
> pipeline before any gate was exercised.

- [x] Push a misformatted file and check that `lint` goes red and Merge is blocked. Then revert it.
      Result (2026-10-07, `1c64adf`): `lint` red at the `dart format` step, Merge blocked. Reverted in `e619a8f`.
- [x] Push an analyzer info (for example an unused import) and check that it goes red. Then revert it.
      Result (`d7b97f4`, `import 'dart:math';` in `lib/main.dart`): `lint` red at `flutter analyze`, Merge
      blocked. Reverted in `9cfd377`.
- [x] Temporarily drop one `osv-scanner.toml` ignore (or pin a known-vulnerable version) and check that
      `scan` goes red. Then revert it.
      Result (`e542f4f`, dropped the RUSTSEC-2026-0285 ignore): `scan-gate` red (the vulnerability gate; `scan`
      itself only fails on scanner errors), Merge blocked. Reverted in `a431eb2`.
- [x] Last pipeline green, then squash-merge, which drops the red/revert commits.

**After merge** (settings, no MR)
- [x] CI/CD → Schedules: "Weekly scan", on `main`, weekly, variable `SCHEDULE=scan` only. Play it by hand
      once and check that only `bridge-lock` and `scan` ran, green.
- [x] Make sure the schedule owner gets failed-pipeline email.

## Phase 3 — MR 2 (optional): Renovate and closing docs

Only if Phase 0 found Renovate workable. Otherwise this MR shrinks to the closing docs. To save the MR,
fold those into the first v1.4.0 MR instead.

- [ ] `renovate.json`: managers `pub` (`ignoreDeps: ["gogdl_flutter"]`, bumped by hand together with the
      CI image), `gitlabci` (public images only, `pinDigests`; the local CI image is ignored), and `fvm`
      if it works. Weekly, minor/patch grouped, `minimumReleaseAge: 7 days`, majors disabled,
      `vulnerabilityAlerts` and `osvVulnerabilityAlerts` with no age wait.
- [ ] `renovate` job copied from metatrader: `SCHEDULE=renovate` schedule only, `RENOVATE_TOKEN`
      protected and scoped to the `renovate` environment, private-CA handling via
      `CI_SERVER_TLS_CA_FILE`.
- [ ] Create the "Renovate" schedule and play it once. Its first MR must go through the normal pipeline.
- [ ] Closing docs: move this plan to `devlog/ci-cd-merge-requests.md` (decisions, gotchas, verification,
      as in the v1.3.0 devlog), and add a GAPS entry for each lint rule and accepted advisory that was
      deferred.

## Phase 4 — Close-out (no MR)

- [ ] `git fetch --prune` and `git branch -a`: only `main` and `origin/main` (plus `origin/HEAD`).
- [ ] GitLab → Repository → Branches lists only `main`.
- [ ] Delete any local branches left by Phases 2–3 (`git branch -d ci/merge-requests …`).
- [ ] Do the same cleanup in `gogdl_flutter` and `gogdl-lib` if they adopt this setup (out of scope here).

## Out of scope (note in GAPS)

- Running the same `scan` job in `gogdl_flutter` and `gogdl-lib` themselves, so a vulnerable crate is
  caught before Lumen pins the release.
- A release job (GitLab release from tag notes) and a built Linux artifact on tags. Lumen has no
  `CHANGELOG.md` yet.
- Coverage reporting in MRs (`flutter test --coverage` plus a Cobertura conversion).
- Digest-pinning the CI image. It would need a registry for `gogdl-flutter-ci`.
