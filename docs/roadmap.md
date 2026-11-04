---
description: Where outskirts stands and where it is heading: what shipped recently, what is in progress, and what comes next on the way to 4.0.
---

# Roadmap

outskirts keeps the Periphery 3.x line working with current Xcode and Swift toolchains, and explores further from there. This page is updated by hand when a release ships or a priority changes; the [changelog](../CHANGELOG.md) lists every change, and each item links to its issue.

Issues carry a priority label, from `P1` (first) to `P3`.

## Published

Recent releases, newest first:

- **3.18.1** (2026-11-04): documentation site at outskirts.dev/docs; job pool data race fixed and Swift 6 language mode ([#181](https://github.com/tiny-earth-moon/outskirts/issues/181)); blocking strict self-scan in CI ([#220](https://github.com/tiny-earth-moon/outskirts/issues/220)).
- **3.18.0** (2026-11-04): JSON Schema of the configuration file and `outskirts config check` ([#228](https://github.com/tiny-earth-moon/outskirts/issues/228)); `--changed-since` and `--changed-lines` for pull request checks ([#231](https://github.com/tiny-earth-moon/outskirts/issues/231)); `--quiet` prints nothing when there is no result ([#296](https://github.com/tiny-earth-moon/outskirts/issues/296)).
- **3.17.0** (2026-11-04): Metal functions analysis (`--detect-unused-metal-functions`); the build cache is keyed by the build arguments.
- **3.16.0** (2026-11-03): the project is renamed outskirts, with `periphery` kept as an alias; Linux is built and tested in CI ([#219](https://github.com/tiny-earth-moon/outskirts/issues/219)).
- **3.15.0** (2026-11-03): `--relative-to`, baselines that only shrink (`--prune-baseline`, `--strict-baseline`) ([#215](https://github.com/tiny-earth-moon/outskirts/issues/215)), and the `sarif` format for GitHub code scanning ([#213](https://github.com/tiny-earth-moon/outskirts/issues/213)).
- **3.14.0** (2026-11-02): unused generic parameters of types are opt-in (`--report-unused-type-parameters`).
- **3.13.0** (2026-11-01): Bazel mode removed ([#165](https://github.com/tiny-earth-moon/outskirts/issues/165)).

## In progress

- Documentation site with one source for the README and outskirts.dev, generated options reference and changelog.
- Fix the `JobPool` error data race and adopt the Swift 6 language mode target by target ([#181](https://github.com/tiny-earth-moon/outskirts/issues/181)).
- Regenerate the Linux self-scan baseline and make the step blocking ([#281](https://github.com/tiny-earth-moon/outskirts/issues/281)); detect system modules on Linux ([#280](https://github.com/tiny-earth-moon/outskirts/issues/280)).

## Next

Analysis and retention:

- Assign-only analysis of properties without an explicit type annotation ([#214](https://github.com/tiny-earth-moon/outskirts/issues/214)).
- `retain_public` per module, for packages that mix libraries and apps ([#217](https://github.com/tiny-earth-moon/outskirts/issues/217)).
- Platform `#if` retention limited to the clauses the indexed build did not compile ([#218](https://github.com/tiny-earth-moon/outskirts/issues/218)).
- `scan --explain`, to show why a declaration is reported, used or retained ([#234](https://github.com/tiny-earth-moon/outskirts/issues/234)).
- Opt-in analysis of enum cases only matched in patterns and never constructed ([#224](https://github.com/tiny-earth-moon/outskirts/issues/224)).
- A type in a `where Self ==` protocol extension is retained even when its members are unused ([#223](https://github.com/tiny-earth-moon/outskirts/issues/223)).
- Gate the `appendInterpolation` workaround on the toolchains that need it ([#222](https://github.com/tiny-earth-moon/outskirts/issues/222)).

Tooling and distribution:

- Warn when an index store is older than its sources, and document merging variant stores ([#230](https://github.com/tiny-earth-moon/outskirts/issues/230)).
- A strict self-scan in CI ([#220](https://github.com/tiny-earth-moon/outskirts/issues/220)).
- Prebuilt binaries beyond macOS 27 ([#229](https://github.com/tiny-earth-moon/outskirts/issues/229)).
- CLI polish: `--version`, grouped help and shell completions ([#226](https://github.com/tiny-earth-moon/outskirts/issues/226)).

## Toward 4.0

The 4.0 theme ([#241](https://github.com/tiny-earth-moon/outskirts/issues/241)): what ships on any platform or configuration is used; everything else is reported with a stable id and can be removed safely. These changes are breaking and ship together:

- Scan the union of all platform and configuration variants instead of name-based retention ([#233](https://github.com/tiny-earth-moon/outskirts/issues/233)).
- Configuration v2: schema, strict validation and per-module overrides ([#238](https://github.com/tiny-earth-moon/outskirts/issues/238)).
- Output v2: stable rule-aware ids, relative paths and baseline v2 ([#239](https://github.com/tiny-earth-moon/outskirts/issues/239)).
- Distinct, documented exit codes for findings and failures ([#232](https://github.com/tiny-earth-moon/outskirts/issues/232)).
- Cleanup: drop the hidden `--no-color` flag and the Bazel shims, and a quieter `--index-store-path` mode ([#240](https://github.com/tiny-earth-moon/outskirts/issues/240)).
- A support policy for Xcode, Swift and Linux, enforced by CI ([#235](https://github.com/tiny-earth-moon/outskirts/issues/235)).
- A `fix` command: syntax-only fixes with a dry-run diff by default ([#237](https://github.com/tiny-earth-moon/outskirts/issues/237)), then removal of unused declarations once every variant is scanned ([#236](https://github.com/tiny-earth-moon/outskirts/issues/236)).

Ideas and requests are welcome as [issues](https://github.com/tiny-earth-moon/outskirts/issues).
