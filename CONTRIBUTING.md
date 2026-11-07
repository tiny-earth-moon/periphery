# Contributing

outskirts (formerly Periphery; `periphery` stays an alias) keeps the Periphery 3.x line building and working with current Xcode/Swift toolchains. There is no functional roadmap: bug reports (with a minimal project) and pull requests are welcome, feature requests should come as a PR.

## Build

```
swift build -c release --product outskirts
.build/release/outskirts version
```

## Test

The full suite is long. Run the tests relevant to your change:

```
swift test --filter <TestCaseName>
```

## Adding an option

An option of `scan` that can also be set in the configuration file touches every item below; `ConfigurationSchemaTest` fails when one is missing.

- The `@Setting` property in `Sources/Configuration/Configuration.swift`, with a one-line `description:` of the key, and its entry in the `settings` array of the same file.
- The `@Option` or `@Flag` in `Sources/Frontend/Commands/ScanCommand.swift`, and its line in `apply(to:)`.
- Its section in `CATEGORIES` of `site/scripts/sync.mjs`, then `npm run sync` in `site/`, which regenerates `docs/options.md` from the schema.
- If it helps a common scenario, a commented use in a file under `examples/`.
- The regenerated schema: `swift run outskirts config schema > outskirts.schema.json` (before `npm run sync`).
- Where it fits, a mention in the page of `docs/` that explains the scenario: the options reference links back to it.
- `swift test --filter ConfigurationSchemaTest`, which compares the settings with the `scan` options, `docs/` and `examples/`, `docs/options.md` with the schema and the `scan` help, and the committed schema with the generated one.

## Documentation

The Markdown files of `docs/` are the documentation: they are published as https://outskirts.dev/docs/ and read as they are on GitHub. Edit `docs/`, never the generated copies:

- `docs/options.md` is generated from `outskirts.schema.json`, and the README sections between `<!-- docs:begin page#anchor -->` and `<!-- docs:end -->` are extracts of `docs/`. After editing `docs/` or the schema, run `npm install` once, then `npm run sync` in `site/`, and commit the result.
- `npm run check` in `site/` builds the site into `site/public/` (not committed), then checks that the generated Markdown is up to date, that every page is in the navigation of `docs/README.md`, and that every link and anchor resolves; the CI runs it.
- The docs follow `master`, so mark what is not in a release yet: every new option gets its version in `SINCE` of `site/scripts/sync.mjs` (keys missing from both `SINCE` and `site/scripts/options-baseline.txt` fail `npm run check`), and every new doc section starts with a paragraph that is exactly `Since X.Y.Z.`, the next version. The site shows "not yet released" next to it while X.Y.Z is above the version in `Sources/Shared/Version.swift`.
- The changelog page is generated from `CHANGELOG.md` at build time.
- Images live under `assets/` and are referenced as `../assets/...`. Keep code lines within 64 characters so that they never wrap on a laptop.
- A link to a page of the site is written `https://outskirts.dev/docs/<page>/#<anchor>`; `SarifFormatterTest` checks the links of the SARIF rules against the headings of `docs/`.

## Commits

Conventional Commits with a scope, in English: `fix(indexer): ...`, `build: ...`, `docs: ...`, `chore(fork): ...`. One logical change per commit.

## Fork process

- One issue = one PR = one patch version.
- The PR body must contain `Closes #N`, otherwise the issue stays open after the merge.
- Never edit `CHANGELOG.md` in a fix PR (it conflicts on every merge). Only the release commit fills it.
- Release commit `chore(release): X.Y.Z`: move the `## master` section into `## X.Y.Z (date)` and leave an empty `## master` (same template as the previous release); bump the version in `Sources/Shared/Version.swift`.
- Real-project check before every release (added after #135, 2026-11-01): run the release candidate read-only on an existing index of a real project (`outskirts scan --skip-build --format json` on a large project you maintain, using its existing index store) and compare the number of results per kind with the previous release; a sudden drop or jump (e.g. 376 unused `localized_string` keys to 0) blocks the release until explained. A fixture-only green run is not enough: the regression of 3.12.10 was invisible to the SwiftPM fixtures.
- Release steps: merge, push the tag `X.Y.Z` (it starts the Bottle workflow; for an existing tag, run it by hand with `gh workflow run bottle.yml -f tag=X.Y.Z`), `gh release create`, then once the workflow is green:
  - download the bottles and the archive: `gh run download <run-id> -p 'outskirts-bottle-X.Y.Z-*' -p outskirts-archive-X.Y.Z`;
  - attach them to the release: `gh release upload X.Y.Z outskirts-X.Y.Z.*.bottle.tar.gz outskirts-X.Y.Z-macos-arm64.tar.gz outskirts-X.Y.Z-macos-arm64.tar.gz.sha256` (one bottle per tag: `arm64_golden_gate`, `arm64_tahoe`, `arm64_sequoia`);
  - update the formula in the `tiny-earth-moon/homebrew-tap` tap: tag tarball url + sha256, and the `bottle do` block of the workflow's "Merged bottle block" job, or `scripts/bottle-block.sh` run on every `outskirts--X.Y.Z.*.bottle.json`, newest macOS first;
  - bump the pinned version in the downstream projects' Brewfiles.
- Homebrew bottles (`.github/workflows/bottle.yml`, read-only; on release tags (not on master pushes, to keep macOS runners free) and as a pull request check only when the build changes: `Package.swift`, `Package.resolved`, the workflow or the bottle scripts): arm64, built by Homebrew from the formula printed by `scripts/bottle-formula.sh`, whose install, caveats and test blocks the tap formula must keep identical; one matrix job per tag, with the Xcode version prefix and bottle tag as parameters (Xcode 27.2 on `xcode-27` for `arm64_golden_gate`, the newest Xcode 26.x on `macos-26` for `arm64_tahoe` and on `macos-15` for `arm64_sequoia`). The bottled binary loads `libIndexStore.dylib` from `/Applications/Xcode.app`, or else from the Command Line Tools (rpaths added at link time; Apple's library is never bundled). With neither installed there, install from source: `brew reinstall --build-from-source outskirts`. The Xcode 27 job also packages that binary, the `periphery` symlink and `LICENSE.md` as `outskirts-X.Y.Z-macos-arm64.tar.gz` with its `.sha256`; the archive job runs it and scans a fixture package on `macos-26` with `/Applications/Xcode.app` as the only Xcode. `scripts/tests/test-bottle-block.sh` tests the block script.
- Pull requests run the Xcode 27 macOS job, both Linux jobs, the site and the release scripts; the macOS job on the minimum Xcode 26 runs on master and on manual runs (`gh workflow run Test --ref <branch>`), as macOS runners are scarce.
- External contributions: cherry-pick keeping the original author, add a `Co-authored-by` trailer, and thank the contributor on the original PR.
- CI (`.github/workflows/test.yml`): macOS job (build, strict self-scan with `.outskirts.yml`, full tests, swiftformat, swiftlint), minimum-Xcode job (Xcode 26.x: build and tests), release scripts job and site job (`npm run check`) must be green before merging.

## Importing changes from other forks

- Use `git merge` or `git cherry-pick -x` so the original author and commit stay in the history; never rewrite an author.
- Add a row to [docs/credits.md](docs/credits.md): fix, author, original commit.
- The MIT license applies: keep the original copyright notice ([LICENSE.md](LICENSE.md)) on imported code.

## Reporting issues

Use the [bug report template](.github/ISSUE_TEMPLATE/bug.md). Labels: `imported` (copied from another tracker, original reference and reporter kept), `needs-repro` (waiting for a minimal project), `P1` to `P3` (priority, P1 first).
