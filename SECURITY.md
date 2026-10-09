# Security policy

This file covers the supply chain: what a new dependency has to meet, what the `scan` job gates and how to accept
a finding, and what to do when a package we use is reported compromised. The jobs that enforce it are described in
the header of `.gitlab-ci.yml` and in `README.md` ("Development").

This is a single-maintainer project developed on a self-hosted GitLab. `github.com/fernando-navarrete/lumen` is a
read-only push mirror of `main` and the `v*` tags, with issues and pull requests off. Report a problem to the
maintainer directly, not in a public issue.

## Adding a dependency

A new pub package has to meet all of these:

- **Needed.** It isn't replaceable by a few lines of our own code.
- **Maintained.** Recent releases, issues answered, and more than one maintainer or a known publisher.
- **A verified publisher** on pub.dev where possible.
- **At least 7 days old** (the same wait Renovate applies, `minimumReleaseAge`), so a compromised release has time to be caught.
- **Few transitive dependencies.** Check `fvm flutter pub deps` and the `pubspec.lock` diff, and prefer the smaller
  option.
- **A dev dependency** unless the app needs it at runtime.

In the MR, list the new packages (direct and transitive) and skim the `pubspec.lock` diff; the MR template has a
checkbox for it. CI then checks that every package in `pubspec.lock` comes from pub.dev with a sha256 (or, for a git
package, from `https://github.com/fernando-navarrete/`), resolves with `--enforce-lockfile`, and scans the lockfile.
`lint` also runs `tool/check_bridge_pin.sh`: `gogdl_flutter` must be pinned by a `vX.Y.Z` tag that GitHub has at the
locked commit. A git dependency reachable only over the LAN is not allowed.

## What `scan` gates

`bridge-lock`, `scan` and `scan-gate` run on every MR, every `v*` tag and weekly (schedule `SCHEDULE=scan`). They
scan two lockfiles with OSV-Scanner: `pubspec.lock`, and the Rust `Cargo.lock` of the `gogdl_flutter` commit that
`pubspec.lock` pins (most of the code that ships is that Rust, built into the app).

- **Any vulnerability fails the job**, whatever its severity, unless it is accepted (below).
- **RUSTSEC informational advisories** (`unmaintained`, `unsound`, `notice`) are printed in the log and kept in the
  `osv-scanner.json` artifact, but never fail it.
- A scanner or network error fails the job too.
- A newly published advisory turns every open MR red until it is fixed or accepted. That is intended: `main` must
  not take merges while a known vulnerability is unaddressed.

A bridge finding can only be fixed by a `gogdl_flutter` release, so it is usually accepted for a while.

### Accepting a finding

Add an entry to `osv-scanner.toml` with the advisory id, a `reason`, and an `ignoreUntil` date (a month or less
unless a fix is known to be further away), so the finding comes back on its own:

```toml
[[IgnoredVulns]]
id = "RUSTSEC-2026-0285"
ignoreUntil = 2026-11-06
reason = "why it is acceptable, and what is needed to fix it"
```

Ignoring an id also ignores its aliases. For a bridge finding, add a follow-up to `gogdl_flutter`'s GAPS.

## Secrets

`secrets` runs gitleaks with `.gitleaks.toml` (default rules, no allowlist) on every MR over the MR's own commits,
and on a `v*` tag pipeline over every branch and tag. A red `secrets` blocks the merge.

- A false positive gets a narrow allowlist entry (`targetRules` plus `paths` or `regexes`, with a comment saying why),
  reviewed in the MR. Never a blanket path.
- Whatever reaches `main` or a `v*` tag is public on GitHub within minutes. A leak found after that is rotated
  first and dealt with in history second. A history rewrite changes every SHA and tag, so it is a decision of its
  own, not a cleanup step.

## Branches and hotfixes

`main` is protected: nobody pushes to it, and it takes only MRs with a green pipeline and resolved threads. A
`v1.3.x` hotfix goes: branch `hotfix/v1.3.x` from the `v1.3.0` tag, fix, push the `v1.3.x` tag (its tag pipeline is
the hotfix's CI, since a branch with no MR gets no pipeline), then cherry-pick the fix (`git cherry-pick -x`) onto a
fresh branch from `main` and merge that through a normal MR. Delete the hotfix branch once tagged. Never rebase the
tagged branch onto `main`: semi-linear merges would land different SHAs than the ones tagged.

## If a package we use is reported compromised

1. **Find it.** Check `pubspec.lock` and the bridge's `Cargo.lock` (the `bridge-lock` artifact) for the bad name and
   versions, on `main` and on open branches.
2. **Did it run?** Look at the CI logs of `lint`, `test` and `bridge-lock` since the bad version was published, and at
   the local `~/.pub-cache` and `.dart_tool` dates. A package's build hooks and the Rust build script run at
   `pub get`, `analyze` and `test` time.
3. **Rotate secrets** if it could have run: `RENOVATE_TOKEN` and `GITHUB_COM_TOKEN` (protected and scoped to the
   `renovate` environment; the `renovate` job runs a package manager against `pubspec.yaml` too), the GitHub mirror token (a new fine-grained token, `Contents: read and write` on `lumen` only, with an expiry,
   pasted into Settings → Repository → Mirroring repositories), and any local tokens or SSH keys the machine
   could reach.
4. **Pin a known-good version.** A direct dependency gets an exact version in `pubspec.yaml`; a transitive one gets a
   `dependency_overrides` entry. Merge through an MR as usual.
5. **Scan.** Run the weekly scan by hand (CI/CD → Schedules → "Weekly scan" → Play) and check `scan` and `scan-gate`.
6. **Release.** If a shipped build contained it, cut a patch tag from the fixed `main`.
