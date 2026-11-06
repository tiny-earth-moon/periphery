<p align="center">
<picture>
<source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/tiny-earth-moon/outskirts/master/assets/brand/outskirts-logo-dark.svg">
<img src="https://raw.githubusercontent.com/tiny-earth-moon/outskirts/master/assets/brand/outskirts-logo.svg" alt="outskirts" width="420">
</picture>
</p>

<p align="center">Find what lies at the outskirts of your Swift project: the code nothing reaches.<br>A community-maintained fork of Periphery 3.x.</p>

<p align="center"><a href="https://outskirts.dev/docs/">Documentation</a> · <a href="https://outskirts.dev/docs/changelog/">Changelog</a> · <a href="https://outskirts.dev/docs/roadmap/">Roadmap</a> · <a href="https://github.com/tiny-earth-moon/outskirts/releases">Releases</a></p>

<p align="center"><a href="https://swiftpackageindex.com/tiny-earth-moon/outskirts"><img src="https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Ftiny-earth-moon%2Foutskirts%2Fbadge%3Ftype%3Dswift-versions" alt="Swift versions"></a> <a href="https://swiftpackageindex.com/tiny-earth-moon/outskirts"><img src="https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Ftiny-earth-moon%2Foutskirts%2Fbadge%3Ftype%3Dplatforms" alt="Platforms"></a></p>

outskirts explores your Xcode project or Swift package, builds a map of what refers to what, and reports the declarations that sit beyond every entry point: unused classes, structs, protocols, functions and properties, assign-only properties, unused parameters and imports, redundant `public` accessibility and protocol conformances, unused String Catalog keys and more. A lot of this code is not dead weight: it is often a feature that was never wired up, a leftover from a refactor, or an API waiting for its first caller. outskirts shows you where it is, and you decide.

> [!NOTE]
>
> outskirts is the new name, since 3.16.0 (2026-11), of the community-maintained successor of [peripheryapp/periphery](https://github.com/peripheryapp/periphery), archived in August 2026. Nothing breaks: the `periphery` command, `.periphery.yml` and `// periphery:ignore` keep working, see [Migrating from Periphery](#migrating-from-periphery).
>
> Periphery was created by [Ian Leitch](https://github.com/ileitch), whom we thank for years of excellent work and for keeping the project open source. The original author now develops [Periphery Pro](https://periphery.pro), a separate closed-source product. This fork takes nothing from it and is not affiliated with, nor endorsed by, the original author or Periphery Pro; the `periphery` name is kept for compatibility, not as a claim on the Periphery brand. Because outskirts installs a `periphery` alias, its Homebrew formula conflicts on purpose with the Periphery formulae: install one or the other.

## Installation

<!-- docs:begin getting-started#install -->

### Requirements

- **Build from source** (Homebrew without a bottle, Mint or `swift build`): macOS 15 or later (`Package.swift`), Swift 6.1.2 or later (checked at every scan) and Xcode 26.0 or later (required by the Homebrew formula). Xcode or the Command Line Tools must be installed, as outskirts loads `libIndexStore.dylib` from the toolchain.
- **Homebrew bottle**: Apple silicon with macOS 27 or later, built with Xcode 27.2. It loads `libIndexStore.dylib` from `/Applications/Xcode.app`, or else from the Command Line Tools.
- **Prebuilt archive**: Apple silicon with macOS 15 or later. Like the bottle, it loads `libIndexStore.dylib` from `/Applications/Xcode.app`, or else from the Command Line Tools.
- **Linux**: Swift Package Manager projects only, see [Platforms](https://outskirts.dev/docs/getting-started/#platforms).

### Homebrew

```sh
brew install tiny-earth-moon/tap/outskirts
```

On a system that meets the bottle [requirements](https://outskirts.dev/docs/getting-started/#requirements), [Homebrew](https://brew.sh/) pours a prebuilt bottle; on other systems it builds from source. With neither Xcode nor the Command Line Tools, the bottle cannot find `libIndexStore.dylib`: build from source with `brew install --build-from-source tiny-earth-moon/tap/outskirts`. Installing by the full name trusts the formula under Homebrew's [tap trust](https://docs.brew.sh/Tap-Trust); after `brew tap tiny-earth-moon/tap`, a short-name install needs `brew trust --formula tiny-earth-moon/tap/outskirts` first.

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

<!-- docs:end -->

## Quick start

<!-- docs:begin getting-started#quick-start -->

From the root of your project, the guided setup detects the project type, asks a few questions, prints the full scan command and runs it:

```sh
outskirts scan --setup
```

Then scan an Xcode project, or a Swift package:

```sh
outskirts scan --project MyApp.xcodeproj --schemes MyApp
outskirts scan
```

Keep your options in a `.outskirts.yml` file at the project root, see [Configuration](https://outskirts.dev/docs/configuration/). To keep a declaration on purpose, add a `// outskirts:ignore` comment above it, see [Comment commands](https://outskirts.dev/docs/comment-commands/). Every option is listed in the [options reference](https://outskirts.dev/docs/options/), and `outskirts help scan` prints them for your version.

The guided setup is meant as an introduction. Once you know which options your project needs, run `outskirts scan` with them, or with a configuration file.

If your project consists of one or more standalone frameworks that do not also contain some kind of application that consumes their interfaces, tell outskirts to assume that all public declarations are used with the `--retain-public` option. For projects that mix Objective-C and Swift, read about [the implications](https://outskirts.dev/docs/framework-conventions/#objective-c) this has on the results.

If your project mixes such libraries with an app, a command line tool or a demo, retain only the public declarations of the libraries with `--retain-public-modules`, so that the unused public declarations of the other modules are still reported:

```sh
outskirts scan --retain-public-modules MyLibrary OtherKit
```

In the configuration file, write `retain_public_modules: [MyLibrary, OtherKit]`, or `retain_public: [MyLibrary, OtherKit]`. `--retain-public` keeps retaining the public declarations of every module, and `--no-retain-public` retains none, the modules of the configuration file included.

<!-- docs:end -->

## Migrating from Periphery

<!-- docs:begin migrating-from-periphery#in-short -->

There is nothing to do: the rename to outskirts (3.16.0) breaks nothing.

- **New names**: the executable is `outskirts`, the Homebrew formula is `tiny-earth-moon/tap/outskirts`, the configuration file is `.outskirts.yml` and comment commands are written `// outskirts:ignore`.
- **The `periphery` alias**: outskirts also installs a `periphery` executable, which behaves exactly like `outskirts`. It prints no warning and has no announced end date, so existing scripts, CI jobs and Xcode run scripts keep working.
- **Configuration file**: `.periphery.yml` is still read next to `.outskirts.yml`. Rename it whenever you like.
- **Comment commands**: `// periphery:ignore`, `// periphery:ignore:all`, `// periphery:ignore:parameters` and `// periphery:override` are equivalent to their `outskirts:` form.
- **Baselines**: baseline files written by Periphery keep matching, see [Baselines](https://outskirts.dev/docs/baselines/).
- **Update check**: it now points at the outskirts repository.

<!-- docs:end -->

The [full guide](https://outskirts.dev/docs/migrating-from-periphery/) covers installing over Periphery and what changed since Periphery 3.x.

## Documentation

The complete documentation lives at [outskirts.dev/docs](https://outskirts.dev/docs/), generated from the Markdown files of [`docs/`](docs/):

<!-- docs:begin nav -->

- **Start**: [Getting started](https://outskirts.dev/docs/getting-started/), [Migrating from Periphery](https://outskirts.dev/docs/migrating-from-periphery/), [Configuration](https://outskirts.dev/docs/configuration/)
- **Explore**: [Analysis](https://outskirts.dev/docs/analysis/), [Framework conventions and retention](https://outskirts.dev/docs/framework-conventions/), [Comment commands](https://outskirts.dev/docs/comment-commands/), [Excluding files](https://outskirts.dev/docs/excluding-files/), [Baselines](https://outskirts.dev/docs/baselines/)
- **Integrate**: [Output formats](https://outskirts.dev/docs/output-formats/), [Continuous integration](https://outskirts.dev/docs/ci/), [Xcode integration](https://outskirts.dev/docs/xcode-integration/)
- **Reference**: [Options](https://outskirts.dev/docs/options/), [Troubleshooting](https://outskirts.dev/docs/troubleshooting/), [FAQ](https://outskirts.dev/docs/faq/)
- **Project**: [Changelog](https://outskirts.dev/docs/changelog/), [Roadmap](https://outskirts.dev/docs/roadmap/), [Credits](https://outskirts.dev/docs/credits/)

<!-- docs:end -->

## Contributing

Bug reports with a minimal project and pull requests are welcome, see [CONTRIBUTING.md](CONTRIBUTING.md). Versions and changes: [CHANGELOG.md](CHANGELOG.md) and the [releases page](https://github.com/tiny-earth-moon/outskirts/releases).

## Credits

Periphery is the work of [Ian Leitch](https://github.com/ileitch) ([peripheryapp/periphery](https://github.com/peripheryapp/periphery), archived, MIT license). This fork is maintained by [tiny-earth-moon](https://github.com/tiny-earth-moon) since 2026-10-25 and renamed outskirts in 3.16.0 (2026-11). The original copyright notice is kept in [LICENSE.md](LICENSE.md). External contributions and the sibling fork [agoodkind/periphery](https://github.com/agoodkind/periphery) are credited on the [credits page](https://outskirts.dev/docs/credits/).
