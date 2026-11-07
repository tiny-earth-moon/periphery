---
description: Answers to common questions about outskirts: the relation to Periphery, false positives, speed, Linux, safety of removing code, and how to contribute.
---

# FAQ

## Is outskirts the same tool as Periphery?

outskirts started as a fork of the last open-source release of Periphery (3.x), archived in August 2026, and became an independent project under its own name. It keeps the `periphery` command, the `.periphery.yml` file and the `// periphery:ignore` comments working, see [Migrating from Periphery](migrating-from-periphery.md). It is not affiliated with Periphery Pro and takes no code from it and does not follow its roadmap.

## Is it free?

Yes. outskirts is open source under the MIT license, like Periphery. It is a side project with no commercial purpose: there is no paid edition and none is planned.

## Should I remove everything outskirts reports?

Not necessarily. A result is a declaration nothing reaches in the build that was scanned: often a leftover from a refactor, sometimes a feature that was never wired up, an API waiting for its first caller, or code used in a configuration or platform that was not built. outskirts shows you where it is, and you decide. Keep code on purpose with a [comment command](comment-commands.md), or record today's results in a [baseline](baselines.md).

## Why is a declaration I use reported as unused?

Usually because the code that uses it was not indexed: a target outside the scanned schemes, a file excluded with `--index-exclude`, a branch of `#if DEBUG`, Objective-C code, or a call made by a framework through reflection. See [Troubleshooting](troubleshooting.md) and [Framework conventions and retention](framework-conventions.md).

## Why does the scan build my project?

The analysis reads the index store that the compiler writes during a build. outskirts builds the project once and keeps an incremental build cache, so later scans are faster. If you already have a build, reuse it with `--skip-build`, see [How a scan works](getting-started.md#how-a-scan-works).

## Does it work on Linux?

Yes, for Swift Package Manager projects, see [Platforms](getting-started.md#platforms). Xcode projects need macOS.

## Does it analyze Objective-C?

No. Swift declarations used from Objective-C can be kept with `--retain-objc-accessible` or `--retain-objc-annotated`, see [Objective-C](framework-conventions.md#objective-c).

## Does it change my code?

No. outskirts only reads your project and reports. It writes only its build cache and the files you ask for (`--write-results`, `--write-baseline`, `--prune-baseline`, and the configuration file of the guided setup).

## Does it send data anywhere?

The update check asks GitHub whether a newer release exists; turn it off with `--disable-update-check`. Nothing else leaves your machine.

## How do I report a bug or contribute?

Open an [issue](https://github.com/tiny-earth-moon/outskirts/issues) with a minimal project, or a pull request. The process is described in [CONTRIBUTING.md](https://github.com/tiny-earth-moon/outskirts/blob/master/CONTRIBUTING.md), and what is planned is on the [roadmap](roadmap.md).
