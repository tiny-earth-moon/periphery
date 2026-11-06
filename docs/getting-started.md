---
description: Install outskirts with Homebrew, Mint, a prebuilt archive or from source, run the guided setup and your first scan of an Xcode project or a Swift package.
---

# Getting started

outskirts explores a Swift project, builds a map of what refers to what, and reports the declarations that lie beyond every entry point. This page installs it, runs a first scan and explains what happens during one.

## Install

### Requirements

- **Build from source** (Homebrew without a bottle, Mint or `swift build`): macOS 15 or later (`Package.swift`), Swift 6.1.2 or later (checked at every scan) and Xcode 26.0 or later (required by the Homebrew formula). Xcode or the Command Line Tools must be installed, as outskirts loads `libIndexStore.dylib` from the toolchain.
- **Homebrew bottle**: Apple silicon with macOS 27 or later, built with Xcode 27.2. It loads `libIndexStore.dylib` from `/Applications/Xcode.app`, or else from the Command Line Tools.
- **Prebuilt archive**: Apple silicon with macOS 15 or later. Like the bottle, it loads `libIndexStore.dylib` from `/Applications/Xcode.app`, or else from the Command Line Tools.
- **Linux**: Swift Package Manager projects only, see [Platforms](#platforms).

### Homebrew

```sh
brew install tiny-earth-moon/tap/outskirts
```

On a system that meets the bottle [requirements](#requirements), [Homebrew](https://brew.sh/) pours a prebuilt bottle; on other systems it builds from source. With neither Xcode nor the Command Line Tools, the bottle cannot find `libIndexStore.dylib`: build from source with `brew install --build-from-source tiny-earth-moon/tap/outskirts`. Installing by the full name trusts the formula under Homebrew's [tap trust](https://docs.brew.sh/Tap-Trust); after `brew tap tiny-earth-moon/tap`, a short-name install needs `brew trust --formula tiny-earth-moon/tap/outskirts` first.

### Mint

```sh
mint install tiny-earth-moon/outskirts
```

`Package.swift` declares two executable products, `outskirts` and `periphery`, both built from the same target. [Mint](https://github.com/yonaskolb/mint) links the executable products of a package, so both commands are available after the install; `outskirts` is the one to use, `periphery` is the compatibility alias. Pin a release with `tiny-earth-moon/outskirts@<version>`.

### Prebuilt archive

Each release has a plain archive of the bottled binary, for CI scripts and tools that do not use Homebrew. Download it with its checksum, verify, then extract:

```sh
version=X.Y.Z
base=https://github.com/tiny-earth-moon/outskirts/releases/download/$version
curl -fLO "$base/outskirts-$version-macos-arm64.tar.gz"
curl -fLO "$base/outskirts-$version-macos-arm64.tar.gz.sha256"
shasum -a 256 -c "outskirts-$version-macos-arm64.tar.gz.sha256"
tar xzf "outskirts-$version-macos-arm64.tar.gz"
"./outskirts-$version-macos-arm64/outskirts" version
```

The archive holds `outskirts`, the `periphery` compatibility symlink and `LICENSE.md`; put the folder on your `PATH` or copy both entries to it. Without the checksum check, `curl -fL "$base/outskirts-$version-macos-arm64.tar.gz" | tar xz` extracts it in one step. The binary does not bundle `libIndexStore.dylib`: Xcode at `/Applications/Xcode.app` or the Command Line Tools must be installed. It is not signed or notarized; that is fine when fetched with `curl`, which sets no quarantine attribute, but a copy downloaded with a browser is blocked by Gatekeeper until you run `xattr -d com.apple.quarantine` on it.

### From source

```sh
git clone https://github.com/tiny-earth-moon/outskirts.git
cd outskirts
swift build -c release --product outskirts
```

The executable is written to `.build/release/outskirts`. Xcode or the Command Line Tools must be installed: outskirts links `libIndexStore.dylib` through an rpath to the toolchain that built it.

### Shell completions

The Homebrew formula installs the bash, zsh and fish completions. With another install, generate them, e.g. for zsh with `~/.zfunc` in `fpath`:

```sh
outskirts --generate-completion-script zsh > ~/.zfunc/_outskirts
```

## Quick start

From the root of your project, the guided setup detects the project type, asks a few questions, prints the full scan command and runs it:

```sh
outskirts scan --setup
```

Then scan an Xcode project, or a Swift package:

```sh
outskirts scan --project MyApp.xcodeproj --schemes MyApp
outskirts scan
```

Keep your options in a `.outskirts.yml` file at the project root, see [Configuration](configuration.md). To keep a declaration on purpose, add a `// outskirts:ignore` comment above it, see [Comment commands](comment-commands.md). Every option is listed in the [options reference](options.md), and `outskirts help scan` prints them for your version.

The guided setup is meant as an introduction. Once you know which options your project needs, run `outskirts scan` with them, or with a configuration file.

If your project consists of one or more standalone frameworks that do not also contain some kind of application that consumes their interfaces, tell outskirts to assume that all public declarations are used with the `--retain-public` option. For projects that mix Objective-C and Swift, read about [the implications](framework-conventions.md#objective-c) this has on the results.

If your project mixes such libraries with an app, a command line tool or a demo, retain only the public declarations of the libraries with `--retain-public-modules`, so that the unused public declarations of the other modules are still reported:

```sh
outskirts scan --retain-public-modules MyLibrary OtherKit
```

In the configuration file, write `retain_public_modules: [MyLibrary, OtherKit]`, or `retain_public: [MyLibrary, OtherKit]`. `--retain-public` keeps retaining the public declarations of every module, and `--no-retain-public` retains none, the modules of the configuration file included.

## GitHub Actions

On a macOS runner, the [outskirts action](https://github.com/tiny-earth-moon/outskirts-action) installs the latest release, checks the archive checksum and runs `outskirts scan`, with each result shown as an annotation on the pull request:

```yaml
jobs:
  outskirts:
    runs-on: macos-15
    steps:
      - uses: actions/checkout@v4
      - uses: tiny-earth-moon/outskirts-action@v1
        with:
          args: --project MyApp.xcodeproj --schemes MyApp
```

Leave `args` empty for a Swift package, or when a `.outskirts.yml` holds your options. The step fails when results are reported; set `fail-on-results: false` to only annotate, and `version` to pin a release. The action's README lists every input; other CI setups are covered in [Continuous integration](ci.md).

## How a scan works

outskirts first builds your project to generate the index store. The index store contains detailed information about the declarations (class, struct, func, etc.) in your project and their references to other declarations. From this store, outskirts builds an in-memory graph of the relational structure of your project, supplemented with information obtained by parsing each source file. The graph is then adjusted to suit the detection of unused code, e.g. by marking your project's entry points. Finally, the graph is traversed from its roots, and the declarations it never reaches are reported.

> [!TIP]
> The index store only contains information about source files in the build targets compiled during the build phase. If a class is only referenced in a source file that was not compiled, outskirts reports the class as unused. Build all the targets you expect to contain references. For an Xcode project, this is controlled with the `--schemes` option. For a Swift package, all targets are built automatically.

For an Xcode project, outskirts keeps its build in a cache folder that is keyed by the project, the schemes and the build arguments passed after `--`, and by nothing else. Scans that differ only in what they report (`--format`, `--baseline`, `--write-baseline`, `--strict`, `--report-exclude`, `--relative-results` and so on) therefore reuse the same incremental build. If you already have a build, such as the one Xcode produced in its own DerivedData or one made by your CI, reuse it with `--skip-build --index-store-path <path>`; see [Finding the index store](#finding-the-index-store). Unused build caches are evicted after `--cache-max-age-days` days (14 by default), as are those of projects that no longer exist; the least recently used are also evicted once the caches exceed `--cache-max-size-gb` gigabytes (20 by default). `outskirts clear-cache` removes them all.

### Results and messages

The results are written to stdout. With any `--format` other than `xcode`, progress and `--verbose` messages go to stderr, so stdout carries only the report, e.g. `outskirts scan --format json > report.json`. `--write-results <file>` also writes the report to a file, and `--skip-stdout-results` then stops it from being printed to stdout.

With `--quiet`, a scan that finds nothing prints nothing at all on stdout, whatever the format (no "No unused code detected." line, no empty JSON array), and `--quiet --write-results <file>` writes the report to the file only, as if `--skip-stdout-results` were given; the file always holds the complete report, an empty document included. Exit statuses are unchanged.

Interrupting a scan with Ctrl-C (`SIGINT`) or `SIGTERM` stops the running build and exits with status 130 or 143, see [Exit status](#exit-status).

## Finding the index store

### Swift packages

By default, outskirts asks SwiftPM where it places build products (`swift build --show-bin-path`, honouring the `-c`/`--configuration`, `--scratch-path`, `--build-system` and `--triple` options passed after `--`) and looks for the index store next to them:

- Swift 6.4 and later (default `swiftbuild` backend): `<scratch path>/out`, e.g. `.build/out` (it contains `v5/units` and `v5/records`).
- The `native` backend: `<bin path>/index/store`, e.g. `.build/debug/index/store` or `.build/arm64-apple-macosx/debug/index/store`.

Therefore, if you run outskirts directly after `swift test`, you can omit `--index-store-path`: outskirts uses the index store created when the project was built for testing, provided you pass the same build options (e.g. `outskirts scan --skip-build -- -c release`). If no index store is found, outskirts fails and lists the locations it tried. If the project was not built that way, give the location of the index store with `--index-store-path`.

### Xcode projects

The index store generated by `xcodebuild` lives in DerivedData at a location that depends on your project, e.g. `~/Library/Developer/Xcode/DerivedData/YourProject-abc123/Index/DataStore`. For Xcode 14 and later, the `Index` directory is named `Index.noindex`, which suppresses Spotlight indexing.

`--skip-build` without `--index-store-path` finds the DataStore in DerivedData on its own: outskirts looks for `~/Library/Developer/Xcode/DerivedData/<ProjectName>-*/Index.noindex/DataStore` (or `Index/DataStore`) and uses the most recently modified match, so the project must have been built by Xcode there.

Your project may need the `-destination` argument of `xcodebuild`. Pass it after `--`:

```sh
outskirts scan --project MyApp.xcodeproj \
  --schemes MyApp \
  -- -destination "generic/platform=iOS Simulator"
```

### Other build systems

outskirts can analyze projects built with other build systems, though it cannot drive them like SwiftPM and Xcode. Instead, write a configuration file that lists the index stores and the other resource files:

```json
{
  "indexstores": ["path/to/file.indexstore"],
  "test_targets": ["MyTests"],
  "plists": ["path/to/file.plist"],
  "xibs": [
    "path/to/file.xib",
    "path/to/file.storyboard"
  ],
  "xcdatamodels": ["path/to/file.xcdatamodel"],
  "xcmappingmodels": ["path/to/file.xcmappingmodel"],
  "xcstrings": ["path/to/Localizable.xcstrings"]
}
```

Only `indexstores` is required and it must list at least one index store; every other key may be left out. A file that cannot be used is reported as `Invalid generic project config <path>: <reason>`, e.g. `missing key 'indexstores'`. Relative paths are relative to the current directory. Then run:

```sh
outskirts scan --generic-project-config config.json
```

### Bazel

The Bazel mode (`--bazel` and every `--bazel-*` option) was removed in 3.13.0 ([#165](https://github.com/tiny-earth-moon/outskirts/issues/165)). The `periphery` module on the Bazel Central Registry belongs to the archived upstream project and is frozen at 3.8.0, this fork is distributed through its Homebrew tap only, and the Bazel build files and CI jobs had to be updated with every change. [agoodkind/periphery](https://github.com/agoodkind/periphery) maintains a Bazel mode. With outskirts, a Bazel project can still be scanned from the index stores its build produces, through the configuration file described in [Other build systems](#other-build-systems).

## Platforms

outskirts supports both macOS and Linux. macOS supports both Xcode and Swift Package Manager projects, whereas only Swift Package Manager projects are supported on Linux.

Linux is built and tested in CI on Ubuntu, in the official Swift container. Minimum versions: see [Requirements](#requirements).

## Commands

| Command | Meaning |
|---------|---------|
| `outskirts scan` | Scan the project, see the [options](options.md). |
| `outskirts check-update` | Check whether a newer version is available. |
| `outskirts clear-cache` | Clear the build cache of outskirts. |
| `outskirts config check` | Check the configuration file without scanning, exit status 1 on any problem. |
| `outskirts config schema` | Print the JSON Schema of the configuration file. |
| `outskirts version` | Print the version of outskirts, also printed by `outskirts --version`. |

## Exit status

| Status | Meaning |
|--------|---------|
| 0 | The scan completed (results may have been reported). |
| 1 | `--strict` and at least one result was reported, `--strict-baseline` and the baseline holds entries that no longer match, or the scan failed (build error, invalid configuration, unreadable file, options that cannot be combined such as `--skip-stdout-results` without `--write-results`...). |
| 64 | The command line could not be parsed: unknown option, missing or invalid value. |
| 130 | Interrupted with Ctrl-C (`SIGINT`); the running build is stopped first. |
| 143 | Terminated with `SIGTERM`; the running build is stopped first. |
