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

## Paths

"always" means paths are relative to the project root (or to `--relative-to`) without passing `--relative-results`, because the CI services that read these formats match results to files in the repository. The other formats report absolute paths unless `--relative-results` (`relative_results`) is passed.

`--relative-to <dir>` (`relative_results_base`) sets the directory the paths are relative to; a relative value is resolved from `--project-root`. In a repository that holds several projects, pass the repository root, e.g. `--relative-to "$GITHUB_WORKSPACE"` on GitHub Actions or `--relative-to "$CI_PROJECT_DIR"` on GitLab CI. With `--project-root pkg`, a result reported as `Sources/Demo/main.swift` becomes `pkg/Sources/Demo/main.swift`.

## Writing to a file

- `--write-results <file>` (`write_results`) also writes the report to a file.
- `--skip-stdout-results` then keeps it off stdout; it requires `--write-results`.
- With `--quiet`, a scan with no result prints nothing on stdout, and `--quiet --write-results <file>` writes the report to the file only. The file always holds the complete report, an empty document included.

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
