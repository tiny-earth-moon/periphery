---
description: Keep code on purpose with outskirts comment commands: ignore a declaration, a file or parameters, explain why, and override the reported kind and location.
---

# Comment commands

Some code is meant to stay even though nothing reaches it yet: an API waiting for its first caller, a hook called by a tool outskirts cannot see. Comment commands in the source keep such declarations out of the results, next to the code they describe.

Every command is written `// outskirts:<command>`. The `// periphery:` prefix keeps working and is equivalent for every command below.

## Ignore a declaration

Place an ignore comment on the line directly above a declaration to ignore it and all its descendant declarations:

```swift
// outskirts:ignore
class MyClass {}
```

## Ignore parameters

Ignore specific unused function parameters by name, separated by commas:

```swift
// outskirts:ignore:parameters unusedOne,unusedTwo
func someFunc(
    used: String,
    unusedOne: String,
    unusedTwo: String
) {
    print(used)
}
```

## Ignore a whole file

Place `// outskirts:ignore:all` at the top of a source file to ignore its entire contents. The comment must come before any code, including import statements. `--retain-files` does the same for every file matching a glob, see [Retaining file declarations](excluding-files.md#retaining-file-declarations).

```swift
// outskirts:ignore:all
import Foundation

struct GeneratedClient {}
```

## Explain why

Comment commands accept a trailing comment after a hyphen, so the reason stays on the same line:

```swift
// outskirts:ignore - called by the plugin host
class MyClass {}
```

## Superfluous ignore comments

An ignore comment on a declaration that is referenced ignores nothing, and outskirts reports it so that comments do not outlive their reason. See [Superfluous ignore comments](analysis.md#superfluous-ignore-comments).

## Override the result kind and location

In generated code that is too low-level to be reported usefully, override the `kind` and the `location` of a result to report it at a more meaningful place:

```swift
// outskirts:override kind="Thing" location="Gen.swift:42:1"
func generatedFunction() {}
```

The `kind` override sets a custom kind that is shown in the result. The `location` override uses the format `file:line:column` (line and column default to 1 when left out); a relative path is resolved from the project root. This is useful to report results at a higher-level definition rather than at the low-level generated code.

## Other ways to keep code

- [`--retain-attributes`](framework-conventions.md#retaining-by-attribute) keeps every declaration that has a given attribute.
- [`report_exclude`](excluding-files.md#excluding-results) hides results by file and kind.
- A [baseline](baselines.md) records today's results so that only new ones are reported.
