# Contributing

This fork keeps Periphery building and working with current Xcode/Swift toolchains. There is no functional roadmap: bug reports (with a minimal project) and pull requests are welcome, feature requests should come as a PR.

## Build

```
swift build -c release --product periphery
.build/release/periphery version
```

## Test

The full suite is long. Run the tests relevant to your change:

```
swift test --filter <TestCaseName>
```

## Commits

Conventional Commits with a scope, in English: `fix(indexer): ...`, `build: ...`, `docs: ...`, `chore(fork): ...`. One logical change per commit.

## Fork process

- One issue = one PR = one patch version.
- The PR body must contain `Closes #N`, otherwise the issue stays open after the merge.
- Never edit `CHANGELOG.md` in a fix PR (it conflicts on every merge). Only the release commit fills it.
- Release commit `chore(release): X.Y.Z`: move the `## master` section into `## X.Y.Z (date)` and leave an empty `## master` (same template as the previous release); bump the version in `Version.swift`.
- Real-project check before every release (added after #135, 2026-11-01): run the release candidate read-only on an existing index of a real project (`periphery scan --skip-build --format json` on a large project you maintain, using its existing index store) and compare the number of results per kind with the previous release; a sudden drop or jump (e.g. 376 unused `localized_string` keys to 0) blocks the release until explained. A fixture-only green run is not enough: the regression of 3.12.10 was invisible to the SwiftPM fixtures.
- Release steps: merge, push the tag `X.Y.Z` (it starts the Bottle workflow; for an existing tag, run it by hand with `gh workflow run bottle.yml -f tag=X.Y.Z`), `gh release create`, download the bottle once the workflow is green (`gh run download <run-id> -n periphery-bottle-X.Y.Z`) and attach it to the release (`gh release upload X.Y.Z periphery-X.Y.Z.*.bottle.tar.gz`), update the formula in the `tiny-earth-moon/homebrew-tap` tap (tag tarball url + sha256, and the `bottle do` block printed by `scripts/bottle-block.sh periphery--X.Y.Z.*.bottle.json`), then bump the pinned version in the downstream projects' Brewfiles.
- Homebrew bottle (`.github/workflows/bottle.yml`, read-only, also a pull request check): arm64, built by Homebrew with Xcode 27.2 from the formula printed by `scripts/bottle-formula.sh`, whose install, caveats and test blocks the tap formula must keep identical. The bottled binary loads `libIndexStore.dylib` from `/Applications/Xcode.app` (rpath added at link time; Apple's library is never bundled). With Xcode installed elsewhere, install from source: `brew reinstall --build-from-source periphery`.
- External contributions: cherry-pick keeping the original author, add a `Co-authored-by` trailer, and thank the contributor on the original PR.
- CI (`.github/workflows/test.yml`): macOS job (build, full tests, swiftformat, swiftlint) must be green before merging.

## Importing changes from other forks

- Use `git merge` or `git cherry-pick -x` so the original author and commit stay in the history; never rewrite an author.
- Add a row to [README § Credits](README.md#credits): fix, author, original commit.
- The MIT license applies: keep the original copyright notice ([LICENSE.md](LICENSE.md)) on imported code.

## Reporting issues

Use the [bug report template](.github/ISSUE_TEMPLATE/bug.md). Labels: `imported` (copied from another tracker, original reference and reporter kept), `needs-repro` (waiting for a minimal project), `P1` to `P3` (priority, P1 first).
