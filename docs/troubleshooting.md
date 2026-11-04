---
description: Fix unexpected outskirts results: stale index stores, code behind #if DEBUG, platform-specific packages, missing index stores, and the Swift index store bugs we checked.
---

# Troubleshooting

Most surprising results come from what the index store saw, or did not see. This page lists the usual causes and the Swift index store bugs that were checked against current toolchains.

## Results in the wrong place or false positives in one file

The index store can become corrupt or out of sync with the source files, for example when a scan is forcefully interrupted (Ctrl-C). Pass `--clean-build` to remove the existing build artifacts and build again.

## Code referenced only in an #if DEBUG branch

outskirts builds your project with the default build configuration, typically Debug. Code behind other compilation conditions is invisible: only the branches that are compiled are indexed. In the example below, `releaseName` is reported as unused, as it is only referenced in the non-debug branch.

```swift
struct BuildInfo {
    let debugName = "debug"
    let releaseName = "release" // 'releaseName' is unused

    var name: String {
        #if DEBUG
        debugName
        #else
        releaseName
        #endif
    }
}
```

There are a few ways around this:

- Use a [comment command](comment-commands.md) to keep `releaseName`.
- Filter the results to remove known instances.
- Run outskirts once for each build configuration and keep only the results common to all of them, see below. Pass arguments to the underlying build after `--`, e.g. `outskirts scan ... -- -configuration Release`.

Platform conditions (`#if os(...)`, `canImport(...)` and the like) are handled differently, see [Platform conditionals](framework-conventions.md#platform-conditionals).

### Merging the results of several build configurations

"Merge" means **intersection**, not union. A declaration used only under `#if DEBUG` is reported as unused in the Release run, yet it is not dead code: it is used in Debug. In the example above, Debug reports `releaseName` and Release reports `debugName`, and neither is unused. A declaration is only truly unused if **every** configuration reports it, so keep only the results present in all of them.

Run one scan per configuration and save each report as JSON:

```sh
outskirts scan --format json ... \
  -- -configuration Debug > results-debug.json
outskirts scan --format json ... \
  -- -configuration Release > results-release.json
```

Then compute the intersection with [jq](https://jqlang.github.io/jq/). A result is identified by its `location`, `kind`, `name` and `hints`; add more `results-*.json` files to intersect more configurations.

```sh
jq -s '
  def id: "\(.location)|\(.kind)|\(.name)|"
    + (.hints | join(","));
  map(map({key: id, value: .}) | from_entries)
    as $sets
  | ($sets | map(keys) | add | group_by(.)
     | map(select(length == ($sets | length))[0]))
    as $common
  | $sets[0]
  | with_entries(select(.key as $k
      | $common | index($k)))
  | [.[]]' results-*.json
```

The output is a JSON array of the results reported by every configuration. If a declaration's line or column differs between configurations (e.g. it sits inside a conditional block), use `(.location | sub(":[0-9]+:[0-9]+$"; ""))` in place of `.location` in `id` to compare on the file and name only.

## Swift package is platform-specific

outskirts uses `swift build` to compile a Swift package, which fails if the package is platform-specific (e.g. iOS only). Build the package with `xcodebuild` instead, then scan the index store it produced with `--skip-build` and `--index-store-path`:

```sh
# 1. Build with xcodebuild
xcodebuild -scheme MyScheme \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -derivedDataPath '../dd' clean build

# 2. Scan the index store it produced
outskirts scan --skip-build \
  --index-store-path '../dd/Index.noindex/DataStore/'
```

## No index store found

With `--skip-build`, outskirts looks for the index store of the last build and lists the locations it tried when it finds none. Build the project first with the same build options, or give the location with `--index-store-path`, see [Finding the index store](getting-started.md#finding-the-index-store).

## A declaration used only by a target that was not built

The index store only describes the targets that were built. For an Xcode project, add the schemes that build every target using the code with `--schemes`; see [How a scan works](getting-started.md#how-a-scan-works).

## Mixed Swift and Objective-C

outskirts cannot analyze Objective-C code. See [Objective-C](framework-conventions.md#objective-c) for the options that keep declarations exposed to the Objective-C runtime, and [Mixed Swift and Objective-C targets](analysis.md#mixed-swift-and-objective-c-targets) for unused imports.

## Known Swift bugs

These Swift index store bugs were checked against the raw index store, before any outskirts rule runs (`KnownSwiftBugsTest`). Verified on Swift 6.4; the CI also runs the tests on 6.1 (the minimum toolchain) and fails when a raw behaviour changes.

| Issue | Title | State |
|-------|-------|-------|
| [56541](https://github.com/swiftlang/swift/issues/56541) | Index store does not relate static property getter used as subscript key | Closed upstream 2026-01. Not reproduced: the reference is recorded (verified on 6.4; no workaround needed, none in outskirts) |
| [56327](https://github.com/swiftlang/swift/issues/56327) | Index store does not relate objc optional protocol method implemented in subclass | Fixed in Swift 6.3 ([swiftlang/swift#86167](https://github.com/swiftlang/swift/pull/86167)); before 6.3 no relation is recorded and outskirts has no workaround |
| [56189](https://github.com/swiftlang/swift/issues/56189) | Index store should relate appendInterpolation from string literals | Closed upstream 2026-01. Reference recorded on Swift 6.4 (verified); workaround kept for older toolchains (every `appendInterpolation` stays retained) |
| [56165](https://github.com/swiftlang/swift/issues/56165) | Index store does not relate constructor via literal notation | Still open upstream, but not reproduced: all nine literal initializers are related (verified on 6.4, reported resolved since 6.1.2); no workaround needed, none in outskirts |

The index store also records no `overrideOf` relation for the underscored requirements of some SwiftUI protocols, namely `TextFieldStyle._body(configuration:)` and `ShapeStyle._apply(to:)`. outskirts retains these witnesses by name on conforming types, from a table in `SwiftUIRetainer`.

## Still stuck

Open an [issue](https://github.com/tiny-earth-moon/outskirts/issues/new/choose) with the command you ran, the output with `--verbose`, and if possible a minimal project that shows the result.
