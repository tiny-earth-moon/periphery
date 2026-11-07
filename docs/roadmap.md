---
description: Where outskirts stands and where it is heading: what shipped recently, what is in progress, and what comes next on the way to 4.0.
---

# Roadmap

outskirts keeps the Periphery 3.x line working with current Xcode and Swift toolchains, and explores further from there. This page is updated by hand when a release ships or a priority changes; the [changelog](../CHANGELOG.md) lists every change, and each item links to its issue.

Issues carry a priority label, from `P1` (first) to `P3`.

## Published

Recent releases, newest first:

- **3.21.0** (2026-11-06): `retain_public` per module; warning (and `--strict-index`) when the index is older than the sources; `--version`, grouped help and shell completions; `appendInterpolation` workaround limited to Swift < 6.4.
- **3.20.0** (2026-11-05): prebuilt archive and bottles for macOS 15, 26 and 27; assign-only analysis without type annotations; platform `#if` retention limited to uncompiled clauses.
- **3.19.1** (2026-11-05): stale index units no longer cause random false positives when an index store is reused; the Swift package is named outskirts.
- **3.19.0** (2026-11-05): bounded build cache, orphaned folders evicted and `cache_max_size_gb` ([#310](https://github.com/tiny-earth-moon/outskirts/issues/310)); types of `where Self ==` protocol extensions reported when unused ([#223](https://github.com/tiny-earth-moon/outskirts/issues/223)).
- **3.18.1** (2026-11-04): documentation site at outskirts.dev/docs; job pool data race fixed and Swift 6 language mode ([#181](https://github.com/tiny-earth-moon/outskirts/issues/181)); blocking strict self-scan in CI ([#220](https://github.com/tiny-earth-moon/outskirts/issues/220)).
- **3.18.0** (2026-11-04): JSON Schema of the configuration file and `outskirts config check` ([#228](https://github.com/tiny-earth-moon/outskirts/issues/228)); `--changed-since` and `--changed-lines` for pull request checks ([#231](https://github.com/tiny-earth-moon/outskirts/issues/231)); `--quiet` prints nothing when there is no result ([#296](https://github.com/tiny-earth-moon/outskirts/issues/296)).
- **3.17.0** (2026-11-04): Metal functions analysis (`--detect-unused-metal-functions`); the build cache is keyed by the build arguments.
- **3.16.0** (2026-11-03): the project is renamed outskirts, with `periphery` kept as an alias; Linux is built and tested in CI ([#219](https://github.com/tiny-earth-moon/outskirts/issues/219)).
- **3.15.0** (2026-11-03): `--relative-to`, baselines that only shrink (`--prune-baseline`, `--strict-baseline`) ([#215](https://github.com/tiny-earth-moon/outskirts/issues/215)), and the `sarif` format for GitHub code scanning ([#213](https://github.com/tiny-earth-moon/outskirts/issues/213)).
- **3.14.0** (2026-11-02): unused generic parameters of types are opt-in (`--report-unused-type-parameters`).
- **3.13.0** (2026-11-01): Bazel mode removed ([#165](https://github.com/tiny-earth-moon/outskirts/issues/165)).

## In progress

3.22.0, merged so far:

- `scan --explain`, to show why a declaration is reported, used or retained ([#234](https://github.com/tiny-earth-moon/outskirts/issues/234)).
- Scan summary: files entirely unused and an estimate of removable lines ([#329](https://github.com/tiny-earth-moon/outskirts/issues/329)).
- An output format for AI coding agents ([#330](https://github.com/tiny-earth-moon/outskirts/issues/330)).
- Opt-in analysis of enum cases only matched in patterns and never constructed ([#224](https://github.com/tiny-earth-moon/outskirts/issues/224)).

## Next

3.22.0, still to do:

- Detect system modules on Linux ([#280](https://github.com/tiny-earth-moon/outskirts/issues/280)).
- A support policy for Xcode, Swift and Linux, enforced by CI ([#235](https://github.com/tiny-earth-moon/outskirts/issues/235)).

3.23.0:

- An `outskirts fix` command with syntax-only fixes and a dry-run diff ([#237](https://github.com/tiny-earth-moon/outskirts/issues/237)).
- Scan the union of all platform and configuration variants ([#233](https://github.com/tiny-earth-moon/outskirts/issues/233)).

## Toward 4.0

The 4.0 theme ([#241](https://github.com/tiny-earth-moon/outskirts/issues/241)): what ships on any platform or configuration is used; everything else is reported with a stable id and can be removed safely. These changes are breaking and ship together:

- Configuration v2: schema, strict validation and per-module overrides ([#238](https://github.com/tiny-earth-moon/outskirts/issues/238)).
- Output v2: stable rule-aware ids, relative paths and baseline v2 ([#239](https://github.com/tiny-earth-moon/outskirts/issues/239)).
- Distinct, documented exit codes for findings and failures ([#232](https://github.com/tiny-earth-moon/outskirts/issues/232)).
- Cleanup: drop the hidden `--no-color` flag and the Bazel shims, and a quieter `--index-store-path` mode ([#240](https://github.com/tiny-earth-moon/outskirts/issues/240)).
- Removal of unused declarations by `outskirts fix` once every variant is scanned ([#236](https://github.com/tiny-earth-moon/outskirts/issues/236)).

Ideas and requests are welcome as [issues](https://github.com/tiny-earth-moon/outskirts/issues).
