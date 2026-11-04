---
description: outskirts continues Periphery, created by Ian Leitch. Attribution, external contributions taken into this fork, and the sibling fork.
---

# Credits

Periphery is the work of [Ian Leitch](https://github.com/ileitch) ([peripheryapp/periphery](https://github.com/peripheryapp/periphery), archived, MIT license). This fork is maintained by [tiny-earth-moon](https://github.com/tiny-earth-moon) since 2026-10-25 and renamed outskirts in 3.16.0 (2026-11); the project history, the issues and the credits below are unchanged. The original copyright notice is kept in [LICENSE.md](https://github.com/tiny-earth-moon/outskirts/blob/master/LICENSE.md).

Issues in this repository are imported from the upstream tracker and from periphery-pro/issues, keeping the original reference and reporter.

## External contributions

Changes from other people taken in since 3.8.1, with the original author kept in the git history:

| Change | Author | Where | Version |
|--------|--------|-------|---------|
| Fix infinite recursion when expanding paths of directories named `**` or starting with `**` | Zev Eisenberg | [#22](https://github.com/tiny-earth-moon/outskirts/pull/22) (3b00f30, 9cde22a, ddc54ea, 44e26aa) | 3.8.4 |
| Honor `--clean-build` and control the derived data path when listing Xcode schemes | Lukas Kollmer | [#25](https://github.com/tiny-earth-moon/outskirts/pull/25) (4dded94, 8062d32, 8c2fd27) | 3.8.5 |
| Retain macro `@State` properties used only via `$projectedValue` | rishabhtpdl | [#36](https://github.com/tiny-earth-moon/outskirts/issues/36) (92f0ec4) | 3.8.8 |
| Detect unused String Catalog (`.xcstrings`) keys (upstream commit, cherry-picked unchanged) | Ian Leitch | d865dde | 3.9.0 |
| Test and fixture pinning `buildPartialBlock` retention in result builders (our #30 already retained it) | Alex Goodkind | [agoodkind/periphery@153790b](https://github.com/agoodkind/periphery/commit/153790b2ad4ddd51a8b6a1b53d7d3b847640a553) (agoodkind PR #6, our issue #119) | 3.12.9 |
| Read stdout and stderr of shell commands concurrently (no deadlock on large output) | Alex Goodkind | [agoodkind/periphery@90de96b](https://github.com/agoodkind/periphery/commit/90de96b) ([PR #1](https://github.com/agoodkind/periphery/pull/1)), our [#117](https://github.com/tiny-earth-moon/outskirts/issues/117) | 3.12.9 |
| Ternary String Catalog keys: fixture and tests (our visitor already looked through ternaries) | Alex Goodkind | [agoodkind/periphery@6c57931](https://github.com/agoodkind/periphery/commit/6c57931) (agoodkind PR #11, cherry-picked), our [#120](https://github.com/tiny-earth-moon/outskirts/issues/120) | 3.12.10 |
| Retain String Catalog keys of runtime lookups by literal prefix, scoped to the module for `bundle: .module` (reimplemented) | Alex Goodkind | [agoodkind/periphery@544a77d](https://github.com/agoodkind/periphery/commit/544a77d), [5c5af4c](https://github.com/agoodkind/periphery/commit/5c5af4c), our [#120](https://github.com/tiny-earth-moon/outskirts/issues/120) | 3.12.10 |
| Detect String Catalog keys referenced through Xcode 26+ generated symbols (reimplemented) | Alex Goodkind | [agoodkind/periphery@783b5f8](https://github.com/agoodkind/periphery/commit/783b5f8), [9ca12ad](https://github.com/agoodkind/periphery/commit/9ca12ad), [20f40ce](https://github.com/agoodkind/periphery/commit/20f40ce), our [#120](https://github.com/tiny-earth-moon/outskirts/issues/120) | 3.12.10 |
| SwiftUI `@State` fixture (`StateMacroView`, SPMProjectMacOS) and top-level `$state` reads retained under Xcode 27 (merged into our `MacroWrappedPropertyReferenceBuilder`) | Alex Goodkind | [agoodkind/periphery@e5b4cd2](https://github.com/agoodkind/periphery/commit/e5b4cd24b314467a2b6252f0336c298760d39e80) ([PR #4](https://github.com/agoodkind/periphery/pull/4)), our [#118](https://github.com/tiny-earth-moon/outskirts/issues/118) | 3.12.10 |
| Exclude hidden files and directories (`.build`, `.scratch`) from SwiftPM implicit resource discovery (cherry-picked with a manual conflict resolution; 782a4e2 only touches Bazel for private dependencies, so nothing to port) | Alex Goodkind | [agoodkind/periphery@df83716](https://github.com/agoodkind/periphery/commit/df83716), our [#121](https://github.com/tiny-earth-moon/outskirts/issues/121) | 3.12.11 |
| Bazel resource and framework rules: embedded Apple frameworks and XPC services, all XIB and storyboard resource groups, Core Data model and mapping model files (with parse errors reported and uppercase extensions accepted), plus Swift protocol buffer targets (`ProtobufAPIVersionCheckRetainer`) and the Bazel consumer-scan fixtures (cherry-picked, conflicts resolved to keep our code); the Bazel parts of this import were removed in 3.13.0 ([#165](https://github.com/tiny-earth-moon/outskirts/issues/165)), the Core Data model inputs, the String Catalog error description and the platform conditional collector fix remain | Alex Goodkind | [agoodkind/periphery#21](https://github.com/agoodkind/periphery/pull/21) (b1a49cd, 72b19a3, 8de9900), [#22](https://github.com/agoodkind/periphery/pull/22) (57ebc75, 405fb72), [#23](https://github.com/agoodkind/periphery/pull/23) (a580f96), [#24](https://github.com/agoodkind/periphery/pull/24) (fb3c7db, ecd320d, 6167672, 8043d63, dc63dc3, 281b88b), [ec864a9](https://github.com/agoodkind/periphery/commit/ec864a9) with prerequisites 782a4e2, e090789 and 88a40ce, our [#122](https://github.com/tiny-earth-moon/outskirts/issues/122) | 3.12.16 |
| Test and fixture for same-named members called through an unknown receiver in platform conditional blocks (the receiver-aware narrowing itself was not taken) | Alex Goodkind | [agoodkind/periphery@8662151](https://github.com/agoodkind/periphery/commit/8662151) and our [#166](https://github.com/tiny-earth-moon/outskirts/issues/166) | unreleased |
| CSV output: Modifiers and Attributes columns swapped back, fields quoted per RFC 4180 | Badri Vishal Pandey | [#216](https://github.com/tiny-earth-moon/outskirts/pull/216) (575c79d3b) | master |

## Sibling fork

[agoodkind/periphery](https://github.com/agoodkind/periphery) (the "Forever Free Fork") was forked from the original in August 2026 and imported our 3.10.0 on 2026-10-29, keeping the authors. Anything we take from it is tracked in issues #117 to #123 and credited here, one table row per import (fix, author, original commit).
