---
description: Every outskirts output format, from Xcode warnings to JSON, CSV, Checkstyle, GitHub, GitLab Code Quality, Code Climate and SARIF, with their path rules.
---

# Output formats

Select a format with `--format` (`format` in the configuration file). The default is `xcode`. The report goes to stdout; progress and `--verbose` messages go to stderr with every format other than `xcode`, so stdout carries only the report.

| Format | Consumer | Relative paths |
|--------|----------|----------------|
| `xcode` | Xcode build log and terminal, with colors | `--relative-results` |
| `csv` | Spreadsheets and scripts | `--relative-results` |
| `json` | Scripts, e.g. `jq` | `--relative-results` |
| `checkstyle` | Tools that read Checkstyle XML | `--relative-results` |
| `github-markdown` | Pull request comments and job summaries | `--relative-results` |
| `github-actions` | GitHub Actions annotations | always |
| `sarif` | GitHub code scanning | always |
| `gitlab-codequality` | GitLab Code Quality report | always |
| `codeclimate` | Code Climate JSON | always |
| `agent` | AI coding agents | always |

## Paths

"always" means paths are relative to the project root (or to `--relative-to`) without passing `--relative-results`, because the CI services that read these formats match results to files in the repository. `agent` uses them too, as a coding agent works from the project root and the short paths keep the report small. The other formats report absolute paths unless `--relative-results` (`relative_results`) is passed.

`--relative-to <dir>` (`relative_results_base`) sets the directory the paths are relative to; a relative value is resolved from `--project-root`. In a repository that holds several projects, pass the repository root, e.g. `--relative-to "$GITHUB_WORKSPACE"` on GitHub Actions or `--relative-to "$CI_PROJECT_DIR"` on GitLab CI. With `--project-root pkg`, a result reported as `Sources/Demo/main.swift` becomes `pkg/Sources/Demo/main.swift`.

## Writing to a file

- `--write-results <file>` (`write_results`) also writes the report to a file.
- `--skip-stdout-results` then keeps it off stdout; it requires `--write-results`.
- With `--quiet`, a scan with no result prints nothing on stdout, and `--quiet --write-results <file>` writes the report to the file only. The file always holds the complete report, an empty document included.

## Summary

Since 3.22.0.

With the `xcode` format, a summary follows the results on stdout:

```text
* Summary: 4 results (unused: 3, missingFinal: 1)
* Unused lines (estimate): 16
* Files entirely unused: 1
  Sources/Legacy/OldParser.swift (22 lines)
```

- The count of each result kind, named as in the `hints` of the `json` format, most frequent first.
- The unused lines: an estimate of the lines that deleting the unused declarations and empty extensions would remove, their attributes and the doc comments right above them included. A line covered by several reported declarations, e.g. a nested one, counts once. Accessibility, `final`, assign-only and the other results are counted but add no lines, and neither does an unused parameter or one name of `case a, b`.
- The files entirely unused: the Swift files whose every top-level declaration, imports excepted, is reported as unused, with their line count, so that they can be deleted whole. A file with top-level statements, e.g. `main.swift`, is never listed.

The summary covers the reported results, after the baseline, `--report-exclude` and `--changed-since`. It is a message like the progress lines, left out in quiet mode, it is not printed when nothing is found or when the results stay off stdout, and `--write-results` writes the results without it. `--no-summary` turns it off, and the output is then the same as without the summary.

With `--format json --summary`, the report becomes an object that holds the array of results under `results` and the summary under `summary`, with the same paths as the results:

```json
{
  "results" : [],
  "summary" : {
    "counts" : { "missingFinal" : 1, "unused" : 3 },
    "unusedLines" : 16,
    "total" : 4,
    "unusedFiles" : [
      {
        "lines" : 22,
        "path" : "Sources/Legacy/OldParser.swift"
      }
    ]
  }
}
```

`results` is shortened here. Without `--summary`, the `json` report stays the bare array of results. The other formats never hold a summary, so that the tools that read them are unaffected; `--summary` with one of them prints a warning.

## xcode

One line per result in the format Xcode and most editors understand, colored in a terminal (`--color auto`, `always` or `never`):

```text
/Project/Sources/Lib/Widget.swift:3:14: warning:
  Unused class 'Widget'
```

Each result is printed on one line; it is wrapped above for reading. Use this format in an [Xcode run script](xcode-integration.md), where the results show up as warnings.

## json

An array of results, each with its `kind` (declaration kind), `name`, `modifiers`, `attributes`, `accessibility`, `ids`, `location`, `hints` (the result annotations) and `modules`:

```json
[
  {
    "accessibility" : "internal",
    "attributes" : ["MainActor"],
    "hints" : ["unused"],
    "ids" : ["s:3Lib6WidgetC"],
    "kind" : "class",
    "location" : "/Project/Sources/Lib/Widget.swift:3:14",
    "modifiers" : ["final", "public"],
    "modules" : ["Lib"],
    "name" : "Widget"
  }
]
```

`--summary` wraps the array in an object with a `summary`, see [Summary](#summary).

Filter it with `jq`, e.g. only the unused types:

```sh
outskirts scan --format json \
  | jq '[.[] | select(.kind == "class"
      or .kind == "struct" or .kind == "enum")]'
```

## csv

One header line, `Kind,Name,Modifiers,Attributes,Accessibility,IDs,Location,Hints`, then one line per result. Fields are quoted as described by RFC 4180.

## checkstyle

Checkstyle XML, one `<file>` element per source file and one `<error>` per result, for the tools and CI plugins that read Checkstyle reports.

## github-markdown

A Markdown table of the results, for a pull request comment or a job summary (`>> "$GITHUB_STEP_SUMMARY"`).

## github-actions

One workflow command per result (`::warning file=…,line=…,col=…,title=…::message`), which GitHub shows as an annotation on the file of the pull request. See [GitHub Actions](ci.md#github-actions).

## sarif

A [SARIF 2.1.0](https://docs.oasis-open.org/sarif/sarif/v2.1.0/sarif-v2.1.0.html) log that GitHub code scanning turns into alerts, which are tracked across commits, can be dismissed with a reason and decorate pull requests. Each rule links to the section of the [Analysis](analysis.md) page that describes it.

Each result carries a `peripheryResult/v1` fingerprint (a SHA-256 of the rule and the ids of the declaration) that GitHub uses to recognise the same alert in the next run. The key keeps its former `peripheryResult/v1` name on purpose, so that the alerts already tracked by code scanning keep matching after the rename. Paths are relative to the project root and resolved against the `%SRCROOT%` base id. See [GitHub code scanning](ci.md#github-code-scanning).

## gitlab-codequality

A [Code Quality](https://docs.gitlab.com/ci/testing/code_quality/) report, which GitLab shows in merge requests. See [GitLab CI](ci.md#gitlab-ci).

## codeclimate

Code Climate JSON issues, each with a `check_name` (the result annotation), a `description`, a `fingerprint`, a `location` and a severity.

## agent

Since 3.22.0.

Compact Markdown meant to be handed as is to a coding agent, much smaller than `json` for the same results. It opens with the rules that avoid damage (rebuild and run the tests after each batch, check dynamic use before deleting, keep the public API of a library, mark a wrong result with `// outskirts:ignore - <reason>` and report it), then lists the results grouped by file in the order they are safest to act on:

1. The files entirely unused (see [Summary](#summary)), to delete whole.
2. Unused code: declarations, imports, parameters, assign-only properties, redundant protocols, empty extensions.
3. Declaration changes: redundant `public` or `open`, `final`, redundant access levels.

Each result gives its line range (doc comments and attributes included), kind and name, the action it calls for and the first line of its declaration:

```markdown
## Delete these files (every declaration unused)

- `Sources/Old.swift` (22 lines): class `OldParser`

## Remove unused code

### `Sources/Lib/Widget.swift`
- L1 import `Combine`: remove import · `import Combine`
- L3-12 class `Widget`: delete · `final class Widget {`

## Change declarations

### `Sources/Lib/Cache.swift`
- L8 class `Cache`: add final · `class Cache {`
```

`--max-results <n>` caps the report at `n` results, a file entirely unused counting all its results and never split. A capped report ends with the number of results left out: act on the results shown, rebuild, run the tests, and run the same scan again for the next batch.
