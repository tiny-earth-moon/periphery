---
description: Move from Periphery to outskirts without changing anything: the periphery alias, .periphery.yml, comment commands and baselines keep working.
---

# Migrating from Periphery

outskirts started as a fork of [peripheryapp/periphery](https://github.com/peripheryapp/periphery), archived in August 2026, and became an independent project. It was renamed from Periphery in 3.16.0 (2026-11), and the rename breaks nothing.

## In short

There is nothing to do: the rename to outskirts (3.16.0) breaks nothing.

- **New names**: the executable is `outskirts`, the Homebrew formula is `tiny-earth-moon/tap/outskirts`, the configuration file is `.outskirts.yml` and comment commands are written `// outskirts:ignore`.
- **The `periphery` alias**: outskirts also installs a `periphery` executable, which behaves exactly like `outskirts`. It prints no warning and has no announced end date, so existing scripts, CI jobs and Xcode run scripts keep working.
- **Configuration file**: `.periphery.yml` is still read next to `.outskirts.yml`. Rename it whenever you like.
- **Comment commands**: `// periphery:ignore`, `// periphery:ignore:all`, `// periphery:ignore:parameters` and `// periphery:override` are equivalent to their `outskirts:` form.
- **Baselines**: baseline files written by Periphery keep matching, see [Baselines](baselines.md).
- **Update check**: it now points at the outskirts repository.

## Installing over Periphery

- **From this fork's former tap** (`tiny-earth-moon/tap/periphery`): `brew upgrade` moves you to `outskirts`.
- **From homebrew-core or the original tap**: the outskirts formula installs a `periphery` alias, so it conflicts on purpose with the Periphery formulae. Uninstall the one you have, then install outskirts:

```sh
brew uninstall periphery
brew install tiny-earth-moon/tap/outskirts
```

- **Mint**: install `tiny-earth-moon/outskirts`; both `outskirts` and `periphery` are linked, see [Mint](getting-started.md#mint).

## What changed since Periphery 3.x

Most changes are additions; the following ones may need a look when you come from an older upstream release.

- **Bazel**: the Bazel mode (`--bazel` and every `--bazel-*` option) was removed in 3.13.0. Passing one of these options, or a `bazel` or `bazel_*` key in the configuration file, fails with an explicit error. See [Bazel](getting-started.md#bazel) for the alternative.
- **Build arguments**: commands are run without a shell since 3.12.12. Each element of `build_arguments`, `xcode_list_arguments` and of the arguments after `--` is passed as exactly one argument, so an element such as `"-destination generic/platform=iOS"` must be written as two elements.
- **Build cache**: it lives in `~/Library/Caches/com.github.tiny-earth-moon.outskirts`. The first scan moves a cache left under the former directory, so nothing is rebuilt.
- **Configuration values**: values are checked when the file is loaded, and a value of the wrong type or an unknown key is reported instead of being ignored. Run [`outskirts config check`](configuration.md#checking-a-configuration-file) once to see what your file contains.
- **SARIF**: the SARIF driver is named `outskirts`, and the fingerprint key keeps its `peripheryResult/v1` name, so the alerts already tracked by GitHub code scanning keep matching. See [Output formats](output-formats.md#sarif).

The [changelog](../CHANGELOG.md) lists every change, version by version.

## Relationship with Periphery

Periphery was created by [Ian Leitch](https://github.com/ileitch), whom we thank for years of excellent work and for keeping the project open source. See [Credits](credits.md) for the full attribution, including the sibling fork [agoodkind/periphery](https://github.com/agoodkind/periphery).

The original author now develops [Periphery Pro](https://periphery.pro), a separate closed-source product. outskirts takes no code from it and does not follow its roadmap. It is not affiliated with, nor endorsed by, the original author or Periphery Pro. The `periphery` name is kept as an alias and for the configuration file and comment commands for compatibility; it is not a claim on the Periphery brand.
