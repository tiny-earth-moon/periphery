# Support policy

This page lists the toolchains and platforms outskirts supports, and how support for one of them ends.

## Supported toolchains

outskirts supports the current Xcode major version and the previous one (N and N-1), with the Swift versions they ship:

| Xcode | Swift | Status |
|-------|-------|--------|
| 27.x | 6.4 | Supported, built and tested in CI (Xcode 27.2) |
| 26.x | 6.2 to 6.3 | Supported, built and tested in CI on the newest Xcode 26.x (pushes to `master`) |
| 16.x | 6.1 (6.1.2 or later) | Deprecated, support ends in outskirts 4.0 |

The Swift version is the one of the `swift` found on `PATH`, checked at every scan: below the minimum (6.1.2) the scan stops with an error, and with Swift 6.1 it prints a deprecation warning (silenced by `--quiet`, like the other warnings).

## Index stores

outskirts supports the index stores produced by the toolchains above. A few workarounds for compiler defects depend on the compiler that wrote the store: they follow the compiler version recorded in each index store unit and, when a unit records none (as current Swift compilers do), the `swift` found on `PATH`. When the store is written by another toolchain than the one on `PATH` (`DEVELOPER_DIR`, an index store copied from CI, `--index-store-path`), select the same toolchain for the scan.

## Platforms

- **macOS**: macOS 15 or later as host (`platforms` in `Package.swift`), for Xcode projects and Swift Package Manager projects. Prebuilt binaries have their own requirements, listed in the [installation requirements](https://outskirts.dev/docs/getting-started/#requirements).
- **Linux**: Swift Package Manager projects only. CI builds outskirts and runs its tests on Ubuntu in the official Swift containers, with Swift 6.4 and with the minimum toolchain, Swift 6.1 (deprecated like on macOS).

## Ending support

Support for a toolchain or a platform is dropped only in a minor or a major release, and only after at least one release that prints a deprecation warning for it. The deprecation is announced in the CHANGELOG of the release that adds the warning, and the release that drops the support names the last release that still had it.

Swift 6.1 (Xcode 16.x) is deprecated: outskirts 4.0 raises the minimum to Swift 6.2 (Xcode 26). Projects that stay on Swift 6.1 can keep using outskirts 3.x.
