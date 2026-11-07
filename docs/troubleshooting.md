---
description: Fix unexpected outskirts results: stale index stores, code behind #if DEBUG, scanning several platforms or configurations, platform-specific packages, missing index stores, and the Swift index store bugs we checked.
---

# Troubleshooting

Most surprising results come from what the index store saw, or did not see. This page lists the usual causes and the Swift index store bugs that were checked against current toolchains.

## Why a declaration is reported or kept

Since 3.22.0.

`--explain` tells why a declaration is reported, used or retained. It takes a name (`draw()`, `draw` or `Beta.draw()`), a USR or a `file:line` location, can be repeated, and prints its explanation before the results:

```
outskirts scan --explain 'Beta.draw()'
```

Each matching declaration gets one of these explanations:

- **unused**: no reference to it was found. When files of its module have no index data, they are listed, as a reference may live in one of them.
- **reported as unused**: references were found but none is reached from a root, and each is listed with the reason, e.g. a self-reference written inside the declaration, or a reference from a declaration that is itself unused.
- **used**: the shortest reference chain from a root (a retained declaration or top-level code), with the location of each reference.
- **retained**: the retainer and its reason, e.g. `PubliclyAccessibleRetainer, retain_public`, a comment command, or `PlatformConditionalRetainer, name 'draw' written in #if os(iOS) at Sources/Kit/Shapes.swift:7`. A retained member that is used shows the chain that reaches it as well.

The scan records these reasons only when `--explain` is passed, so other scans are as fast as before.

## Results in the wrong place or false positives in one file

The index store can become corrupt or out of sync with the source files, for example when a scan is forcefully interrupted (Ctrl-C). Pass `--clean-build` to remove the existing build artifacts and build again.

### Index data older than its source

Since 3.21.0.

outskirts compares the modification time of each source file with the index data it reads for it. When a file was edited after its last build, for example when you scan with `--skip-build` or `--index-store-path` without building first, it prints a single warning for the scan:

> warning: 2 source files are newer than their index data in .build/out: Sources/Kit/Beta.swift, Sources/Kit/SameName.swift. Results in them may be at the wrong lines or missing: rebuild the project before scanning, or pass '--clean-build' to start from an empty index store.

The warning names each index store with the number of files concerned and the first three of them. The results are left unchanged: the index data is still the only description of these files, but it describes an older version of them, so a result may point to a line that has moved, and a declaration added since is not seen. Build the project again, or scan without `--skip-build` so that outskirts builds it. Index data older than its source file is ignored, without a warning, when another index store holds data for the same file and module written after the last edit.

In CI, pass [`--strict-index`](options.md#--strict-index) (`strict_index: true`) to fail the scan instead of printing the warning.

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
- Scan the index stores of every build configuration together, see [Scanning several platforms or configurations](#scanning-several-platforms-or-configurations).

Platform conditions (`#if os(...)`, `canImport(...)` and the like) are handled differently, see [Platform conditionals](framework-conventions.md#platform-conditionals).

## Scanning several platforms or configurations

Since 3.21.0.

outskirts reads every index store it is given and merges their data per source file. A declaration referenced in any of them is used, so scanning the stores of all your build configurations, or of all your platforms, together reports only the code that none of them uses. This union also covers code compiled in a single configuration (`releaseName` above is used in the Release store, `debugName` in the Debug one) and the imports needed by only one platform.

When every platform is built, also pass [`--disable-platform-conditional-retention`](options.md#--disable-platform-conditional-retention): code under `#if os(...)` is then checked like any other code, instead of being kept because outskirts cannot see the other branches. When only some of them are built, pass [`--platform-conditional-retention auto`](#retaining-only-what-the-missing-builds-may-use) instead.

- **Several index stores**: repeat `--index-store-path`, once per store. It implies `--skip-build`, so build each configuration or platform first.

  ```sh
  outskirts scan --disable-platform-conditional-retention \
    --index-store-path .build-macos/out \
    --index-store-path .build-ios/out
  ```

- **Xcode**: build each destination or configuration into the same `-derivedDataPath`. They all write to one index store, `Index.noindex/DataStore`, which is scanned once.

  ```sh
  xcodebuild build-for-testing -scheme MyScheme \
    -destination 'generic/platform=iOS Simulator' \
    -derivedDataPath ../dd
  xcodebuild build-for-testing -scheme MyScheme \
    -destination 'platform=macOS' -derivedDataPath ../dd
  outskirts scan --skip-build \
    --disable-platform-conditional-retention \
    --index-store-path ../dd/Index.noindex/DataStore
  ```

  Add `-configuration Release COMPILER_INDEX_STORE_ENABLE=YES` to build another configuration into the same store: Xcode only indexes Debug builds by default.

- **Swift packages**: give each platform its own `--scratch-path` and build it with `--triple` and `--sdk`, see [Swift package is platform-specific](#swift-package-is-platform-specific). With the `swiftbuild` build system (the default since Swift 6.4), the index store of a scratch path is `<scratch-path>/out`.

Build all the stores from the same version of the sources. If one of them was built before an edit, outskirts prints the [warning above](#index-data-older-than-its-source) for the files concerned.

### Retaining only what the missing builds may use

Since 3.22.0.

With [`platform_conditional_retention: auto`](options.md#--platform-conditional-retention), outskirts uses the builds found in the index stores (their target triples, listed by `--verbose` and by `--explain` for a file indexed for several builds) to retain less:

- The names written in an `#if` clause are retained only when no indexed build of the file compiled that clause, including in blocks nested in another `#if` block.
- A declaration marked `@available(X, unavailable)` is no longer retained once its file was indexed for `X` and for a platform where the declaration is available.

```sh
outskirts scan --platform-conditional-retention auto \
  --index-store-path .build-macos/out \
  --index-store-path .build-ios/out
```

Or in `.outskirts.yml`:

```yaml
index_store_path:
  - .build-macos/out
  - .build-ios/out
platform_conditional_retention: auto
```

Code for a platform that is not built, such as an `#if os(watchOS)` clause, stays retained. With a single index store, every clause the build did not compile and every `@available(X, unavailable)` declaration stay retained, as with the default `all-clauses`. Conditions that a target triple cannot answer, such as `#if DEBUG` or `canImport()`, are not narrowed: scanning a Debug and a Release store together covers `#if DEBUG` code.

### Merging the results of separate scans

When the scans cannot share their sources, for example because they run on different machines or checkouts, merge their results instead. Here "merge" means **intersection**, not union: a declaration is only truly unused if **every** scan reports it. Save each report as JSON:

```sh
outskirts scan --format json ... \
  -- -configuration Debug > results-debug.json
outskirts scan --format json ... \
  -- -configuration Release > results-release.json
```

Then compute the intersection with [jq](https://jqlang.github.io/jq/). A result is identified by its `location`, `kind`, `name` and `hints`; add more `results-*.json` files to intersect more scans.

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

The output is a JSON array of the results reported by every scan. If a declaration's line or column differs between scans (e.g. it sits inside a conditional block), use `(.location | sub(":[0-9]+:[0-9]+$"; ""))` in place of `.location` in `id` to compare on the file and name only. Unlike the union of index stores, the intersection never reports code that only one scan compiles.

## Swift package is platform-specific

`swift build` builds for the host by default, which fails for a package that only supports another platform (e.g. iOS only). Pass the target triple and SDK to the build after `--`; outskirts finds the index store of that build on its own:

```sh
outskirts scan -- \
  --triple arm64-apple-ios18.0-simulator \
  --sdk "$(xcrun --sdk iphonesimulator --show-sdk-path)"
```

Use the same arguments with `--skip-build` to scan that build again later. You can also build the package with `xcodebuild`, then scan the index store it produced:

```sh
xcodebuild build-for-testing -scheme MyScheme \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath '../dd'
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
| [56189](https://github.com/swiftlang/swift/issues/56189) | Index store should relate appendInterpolation from string literals | Closed upstream 2026-01. Reference recorded on Swift 6.4 (verified); workaround applied only below Swift 6.4 (every `appendInterpolation` in a struct extension stays retained); unused overloads are reported from 6.4 |
| [56165](https://github.com/swiftlang/swift/issues/56165) | Index store does not relate constructor via literal notation | Still open upstream, but not reproduced: all nine literal initializers are related (verified on 6.4, reported resolved since 6.1.2); no workaround needed, none in outskirts |

The index store also records no `overrideOf` relation for the underscored requirements of some SwiftUI protocols, namely `TextFieldStyle._body(configuration:)` and `ShapeStyle._apply(to:)`. outskirts retains these witnesses by name on conforming types, from a table in `SwiftUIRetainer`.

## Still stuck

Open an [issue](https://github.com/tiny-earth-moon/outskirts/issues/new/choose) with the command you ran, the output with `--verbose`, and if possible a minimal project that shows the result.
