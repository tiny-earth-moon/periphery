---
description: Choose what outskirts sees and reports: exclude files from indexing, hide results by file and kind with report_exclude, keep only some paths, retain whole files.
---

# Excluding files

outskirts can leave files out at two stages. Files excluded from indexing are invisible: their declarations and references do not exist for the scan. Files excluded from the results are still explored, so what they reference stays used, but nothing is reported in them.

Every exclusion option accepts a Bash v4-style path glob, either absolute or relative to your project directory. Give several globs separated by spaces, e.g. `--report-exclude "Sources/Single.swift" "**/Generated/*.swift" "**/*.{xib,storyboard}"`.

## Excluding results

To hide the results of certain files, pass `--report-exclude <globs>` (`report_exclude`). The files are still indexed.

To hide only some kinds of results, give `report_exclude` an object entry in the configuration file, or append the kinds to the glob with `<glob>:kind1,kind2`. A kind is the result annotation optionally followed by the declaration kind reported in the JSON `kind` field, e.g. `unused.function` (every unused function and method) or `unused.var.parameter`. Entries without kinds exclude every result, and an unknown kind is a configuration error.

```yaml
report_exclude:
  - "**/Generated/**"
  - path: "**/SharedKit/**"
    kinds: [unused.function, unused.var.parameter]
  - "**/Legacy/**:unused.var,redundantProtocol"
```

The result annotations are:

| Annotation | Reported by |
|------------|-------------|
| `unused` | [Unused declarations](analysis.md#unused-declarations) |
| `assignOnlyProperty` | [Assign-only properties](analysis.md#assign-only-properties) |
| `unassignedOptionalProperty` | [Unassigned optional properties](analysis.md#unassigned-optional-properties) |
| `redundantProtocol` | [Redundant protocols](analysis.md#redundant-protocols) |
| `redundantPublicAccessibility` | [Redundant public accessibility](analysis.md#redundant-public-accessibility) |
| `redundantOpenAccessibility` | [Open and final](analysis.md#open-and-final) |
| `missingFinal` | [Open and final](analysis.md#open-and-final) |
| `redundantAccessLevel` | [Redundant access levels](analysis.md#redundant-access-levels) |
| `emptyExtension` | [Empty extensions](analysis.md#empty-extensions) |
| `superfluousIgnoreCommand` | [Superfluous ignore comments](analysis.md#superfluous-ignore-comments) |

## Including results

`--report-include <globs>` (`report_include`) keeps only the results of the matching files; it supersedes `--report-exclude`. The other files are still indexed. To keep only the results of the files a branch changed, see [Pull request checks](ci.md#pull-request-checks).

## Excluding indexed files

Excluding files from indexing means that the declarations and references they contain are not seen by outskirts, which behaves as if the files did not exist. A declaration used only from an excluded file is therefore reported as unused.

- `--exclude-targets "TargetA" "TargetB"` (`exclude_targets`) excludes all source files of the given targets.
- `--exclude-tests` (`exclude_tests`) excludes all test targets.
- `--index-exclude "file.swift" "path/*.swift"` (`index_exclude`) excludes individual source files. The patterns are added to the defaults, `**/*?.build/**/*` and `**/SourcePackages/checkouts/**`, which are always kept.

## Retaining file declarations

To keep every declaration of some files, pass `--retain-files <globs>` (`retain_files`). This is equivalent to an [`// outskirts:ignore:all`](comment-commands.md#ignore-a-whole-file) comment at the top of each file.

## String Catalogs

String Catalogs are excluded from the localized strings analysis by their own option, `--localized-string-catalog-exclude`, see [Unused localized strings](analysis.md#unused-localized-strings).
