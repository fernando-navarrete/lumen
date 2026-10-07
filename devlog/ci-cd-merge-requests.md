# Devlog — CI/CD: merge requests, linting, dependency scanning, Renovate

Brought Lumen's CI/CD up to the level of `metatrader-dashboard` (same GitLab at `thinkcentre.home`, same
runner), 2026-10-06 to 07: dependency scans on every MR and weekly, lint as a merge gate, a protected `main`
and an MR workflow, then Renovate. Delivered as: a direct push to `main` (Phase 1, branch cleanup and
protection), MR 1 `ci/merge-requests` (Phase 2), the follow-up `ci/prove-gates-2` (the gates actually
exercised), and MR 2 `ci/renovate` (Phase 3). This file keeps the decisions and pitfalls that aren't obvious
from the diff.

## Decisions

- **Merge method: "Merge commit with semi-linear history".** The MR must be rebased onto `main`, so the pipeline
  tested exactly what lands, and `main` still gets one merge commit per MR with its phase commits underneath.
  **Squash: "Allow"**, used for CI and docs MRs and any MR with red/revert commits. Feature MRs keep their phase
  commits.
- **No pipeline on pushes to `main`.** `main` only receives a tree an MR pipeline already tested, and the runner is
  shared. Pipelines run for MRs, `v*` tags and schedules.
- **No required approvals.** Single developer; the gate is the pipeline plus resolved threads.
- **Vulnerability gate:** any OSV vulnerability in `pubspec.lock` or the bridge's `Cargo.lock` fails `scan-gate`
  unless listed in `osv-scanner.toml` with a `reason` and an `ignoreUntil`. RUSTSEC informational advisories
  (`unmaintained`, `unsound`, `notice`) are printed, never gating. A newly published advisory turns open MRs
  red until it's fixed or ignored, on purpose.
- **The bridge's `Cargo.lock` is scanned too.** Most shipped code is Rust, built by the Native Assets hook;
  `bridge-lock` exports the lockfile at the exact `resolved-ref` Lumen pins.
- **v1.4.0 has no release branch.** Each MR bundles several phases and leaves `main` releasable. A `v1.3.x`
  hotfix: branch from the `v1.3.0` tag, push the `v1.3.x` tag (its tag pipeline is the CI), then
  `git cherry-pick -x` onto a fresh branch from `main` through a normal MR. Never rebase the tagged branch.
- **Renovate:** managers `pub` and `gitlabci` only. `fvm` is off because `.fvmrc`, the CI image tag, the bridge's
  Rust pin and `pubspec.yaml` must move together; `gogdl_flutter` and the local `gogdl-flutter-ci` image are in
  `ignoreDeps`. `pubspec.yaml` has no `environment: flutter:` bound, so `renovate.json` carries
  `constraints.flutter` (kept equal to `.fvmrc`) to tell Renovate which Flutter to install for the lockfile
  update. No `lockFileMaintenance`: it would move transitive packages without the 7-day wait.

## Phase 0 — Investigation

- **OSV baseline** (OSV-Scanner v2.6.0): `pubspec.lock` clean. The bridge's `Cargo.lock` had one vulnerability,
  RUSTSEC-2026-0285 (`rustls` 0.23.43, fixed in 0.23.45, published 2026-10-05), accepted in `osv-scanner.toml`
  until a bridge release bumps it, plus two informational advisories (`anyhow` unsound, `adler` unmaintained).
- Informational advisories show as `vulnerabilities[].affected[].database_specific.informational` (a string, or
  `null` for real vulnerabilities). The OSV image has no `jq`, nor does the CI image, but the CI image has
  `dart`, so the gate is `tool/osv_gate.dart` with unit tests, run by `scan-gate` on the `scan` report.
- OSV exit codes: 0 clean, 1 findings, anything else (e.g. 127) is an error and must fail the job.
- Lint candidates: seven rules, 58 infos in total, all adopted in Phase 2.
- `pub get --enforce-lockfile` passes on a clean checkout.

## Phase 1 — Bootstrap (direct push)

Fast-forwarded `main` to `release/v1.4.0`, rewrote the v1.4.0 branching section for MRs, deleted
`release/v1.3.0`, `release/v1.4.0` and `restart`, then set up the GitLab side: semi-linear merge, pipelines and
threads must pass, skipped pipelines not counted as success, auto-cancel redundant pipelines, `main` protected
(no one pushes), `v*` tags protected. A dummy push to `main` was rejected.

## Phase 2 — Pipeline, lint, scan (MR 1 and 2g)

- Triggers: schedules, MR events, `v*` tags; a branch push with an open MR never runs (no duplicate pipeline).
- `lint`: `dart format --output=none --set-exit-if-changed lib test tool`, then `flutter analyze --fatal-infos`.
  Rules added: `unawaited_futures`, `cancel_subscriptions`, `close_sinks`, `avoid_dynamic_calls`,
  `prefer_final_locals`, `directives_ordering`, `always_declare_return_types`. `.githooks/pre-commit` checks
  format on staged files only.
- `tool/check_lockfile.sh` runs before `pub get`: hosted packages only from pub.dev, git packages only from the
  `gogdl` group on `thinkcentre.home`. `pub get` uses `--enforce-lockfile`.
- `bridge-lock` → `scan` → `scan-gate`, also on the weekly `SCHEDULE=scan` schedule.
- `SECURITY.md`, the MR template, README "Checks" and CLAUDE.md updated.
- **Gate proof** (`ci/prove-gates-2`, squash-merged): a misformatted file turned `lint` red at `dart format`; an
  unused import turned it red at `flutter analyze`; dropping the RUSTSEC-2026-0285 ignore turned `scan-gate` red;
  each blocked Merge and was reverted before the last green pipeline. The weekly schedule was played by hand and ran
  only `bridge-lock`, `scan` and `scan-gate`, green.

## Phase 3 — Renovate (MR 2)

- `renovate.json`: weekly (before 6am Monday, America/Mexico_City), one grouped minor/patch/digest MR, majors off,
  `minimumReleaseAge: 7 days` with `internalChecksFilter: strict`, `osvVulnerabilityAlerts` and
  `vulnerabilityAlerts` with no age wait, `pinDigests` for `gitlabci`.
- `renovate` job: same pinned image as `metatrader-dashboard`, only on `SCHEDULE=renovate`, declares the
  `renovate` environment so the protected `RENOVATE_TOKEN` / `GITHUB_COM_TOKEN` reach no other job. Unlike
  metatrader it writes the deploy key and `~/.ssh/config` first (no ssh-agent), because updating `pubspec.lock`
  re-resolves the SSH-only `gogdl_flutter`.
- Validated locally with `renovate-config-validator --strict`; the image has `git`, `ssh`, `ssh-keyscan`,
  `base64` and `install-tool`.
- **Still to verify after merge** (settings, no MR): create the token and variables, create the "Renovate"
  schedule, play it once, and watch the log for the lockfile-update step, the one thing Phase 0 couldn't prove.
  If it fails, disable the `pub` manager and record that here.

## Gotchas

- `GOGDL_DEPLOY_KEY_B64` must stay masked but **unprotected**, or every MR pipeline fails at `pub get`.
- A GitLab "File" variable mangled the multi-line PEM on paste, hence the base64 single-line variable.
- The Native Assets hook runs cargo with a scrubbed environment, so `SSH_AUTH_SOCK` never reaches it: the key goes
  in `~/.ssh/config` and cargo gets `git-fetch-with-cli = true`.
- The first attempt at proving the gates (`ci/prove-gates`) merged on its baseline pipeline before any gate was
  exercised; the proof was redone in `ci/prove-gates-2`.
- `scan` itself fails only on scanner errors; vulnerability findings fail `scan-gate`.
- Bump the CI image tag in `.gitlab-ci.yml` and `constraints.flutter` in `renovate.json` whenever `.fvmrc` changes.

## Left for later

Tracked in `GAPS.md` §7: the accepted RUSTSEC-2026-0285 until the bridge bumps `rustls`; running `scan` in
`gogdl_flutter` and `gogdl-lib`; a release job with a Linux artifact on tags; MR coverage; digest-pinning the CI
image (needs a registry); `lockFileMaintenance`.

## Close-out checklist

- [ ] `git fetch --prune` and `git branch -a`: only `main` and `origin/main`.
- [ ] GitLab → Repository → Branches lists only `main`.
- [ ] Delete local branches left behind (`ci/*`).
