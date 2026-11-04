---
description: Run outskirts in continuous integration: GitHub Actions annotations, SARIF code scanning, GitLab Code Quality, pull request checks with --changed-since.
---

# Continuous integration

In CI, outskirts can fail a job when new unused code appears, annotate pull requests, and feed the code scanning or code quality views of your forge.

## Reusing the build

If your pipeline has already built the project, e.g. to run tests, skip the build phase with `--skip-build` and give the location of the index store with `--index-store-path`. Replace `<path>` in the examples below with the index store directory of your build, found as described in [Finding the index store](getting-started.md#finding-the-index-store). For a Swift package built by Swift 6.4 or later, the index store is found without `--index-store-path`.

Useful options in CI:

- `--strict` exits with status 1 when any result is reported; combine it with a [baseline](baselines.md) to fail only on new results.
- `--quiet` prints only the results, and nothing at all when there is none.
- `--disable-update-check` skips the network check for a new version.
- `--format` picks a format that your CI service reads, see [Output formats](output-formats.md).

The `github-actions`, `gitlab-codequality`, `codeclimate` and `sarif` formats always report paths relative to the project root, as if `--relative-results` was passed. In a repository that holds several projects, pass the repository root with `--relative-to`, see [Paths](output-formats.md#paths).

## GitHub Actions

On a macOS runner, install outskirts, build with the index store enabled and scan without building again:

```yaml
- run: brew install tiny-earth-moon/tap/outskirts
- run: swift build --build-tests
- run: >-
    outskirts scan --skip-build
    --index-store-path <path>
    --format github-actions
    --strict --baseline baseline.json
```

The `github-actions` format prints one workflow-command warning per result, which GitHub shows as an annotation on the file. `--baseline` is optional, see [Baselines](baselines.md). For a Swift package on Linux, use a `swift` container (`container: swift:6.4-noble`), build the package, and run the built `outskirts` the same way.

What this repository's own CI runs: the tests on a macOS runner (`xcode-27` image, Xcode 27.2, a GitHub preview image) and in the `swift:6.4-noble` and `swift:6.1-noble` containers on `ubuntu-latest`, and, in the Swift 6.4 container, a scan of this repository with `--skip-build --baseline --strict` (advisory, it does not fail the job). The Homebrew install step and the recipe above have not been run on a hosted runner by this repository: adapt them to your runner image, whose macOS and Xcode versions must meet the [requirements](getting-started.md#requirements) of the bottle (otherwise Homebrew builds from source).

## GitHub code scanning

The `sarif` format writes a SARIF 2.1.0 log that GitHub code scanning turns into alerts, tracked across commits and shown on pull requests:

```yaml
- run: >-
    outskirts scan --skip-build
    --index-store-path <path>
    --format sarif
    --write-results outskirts.sarif
    --skip-stdout-results
- uses: github/codeql-action/upload-sarif@v3
  with:
    sarif_file: outskirts.sarif
    category: outskirts
```

The upload needs the `security-events: write` permission. Code scanning is free on public repositories; on private repositories it requires GitHub Code Security. GitHub limits the size of an uploaded SARIF file, so a project with a very large number of results may need to be scanned in parts. See [sarif](output-formats.md#sarif) for the fingerprints.

## GitLab CI

The `gitlab-codequality` format writes a Code Quality report, which GitLab shows in merge requests:

```yaml
outskirts:
  script:
    - >-
      outskirts scan --skip-build
      --index-store-path <path>
      --format gitlab-codequality
      --write-results gl-code-quality-report.json
  artifacts:
    reports:
      codequality: gl-code-quality-report.json
```

Relative paths are implied by this format. GitLab needs paths relative to the repository root, so pass `--relative-to "$CI_PROJECT_DIR"` when the scanned project is in a subdirectory. This recipe is untested: this repository has no GitLab pipeline, and GitLab runners are Linux or macOS machines of your own, with outskirts installed as described in [Install](getting-started.md#install).

## Pull request checks

To look at what a pull request adds, scan the whole project and report only what changed since the branch point:

```sh
outskirts scan --changed-since origin/main \
  --strict --format github-actions
```

Results are kept when their file changed since the merge base with `origin/main`, or has uncommitted or untracked changes; add `--changed-lines` to keep only those on changed lines. The whole project is still analysed, but only the results in changed files are kept: a declaration that a branch leaves unused, in a file the branch did not touch, is not reported. Make sure the ref is fetched, since CI checkouts are often shallow (`fetch-depth: 0` on GitHub Actions). Outside a git work tree, or with a ref that does not exist, the scan stops with an error. The filter is applied after `--baseline` and with the same path rules as `--report-include`, so it needs no committed baseline of its own.

## Quiet reports

With `--quiet`, a job log stays empty when there is nothing to report, in every format. `--quiet --write-results <file>` writes the report to the file only, so a job can archive it or post it as a comment:

```sh
outskirts scan --quiet --format github-markdown \
  --write-results outskirts.md
```

The exit status does not depend on `--quiet`: use `--strict` to fail the job.

## Baseline ratchet

To make a baseline shrink over time, run `--strict --strict-baseline` on every change and `--prune-baseline` on a schedule, see [Baseline ratchet](baselines.md#baseline-ratchet).
