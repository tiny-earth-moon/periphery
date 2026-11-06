---
name: outskirts
description: Find and safely remove unused Swift code with outskirts (a maintained fork of Periphery, also run as `periphery`). Use when asked to find dead code, unused declarations, files, imports or parameters in a Swift, iOS or macOS project, to clean up a Swift codebase, or to triage, fix or silence outskirts or Periphery scan results.
---

# outskirts: find and remove unused Swift code

outskirts builds the project, reads the index store and reports declarations nothing uses. The `periphery` command is an alias with the same options.

## 1. Run the right scan

- Swift package: from the package root, `outskirts scan`.
- Xcode project or workspace: `outskirts scan --project MyApp.xcodeproj --schemes MyApp` (pass the `.xcworkspace` for a workspace; list every scheme whose code should count as a use).
- Index already fresh (you just built with Xcode or `xcodebuild`): `outskirts scan --skip-build --index-store-path <DerivedData>/<Project>/Index.noindex/DataStore` skips the build.
- A `.outskirts.yml` (or `.periphery.yml`) at the root holds the options: read it before passing flags, and prefer adding options there.
- To parse results, add `--format json`: each result carries its kind, name, location and hints.

## 2. Triage every result before touching code

A result means the index saw no reference, not that the code is unreachable. Check each one:

- Dynamic uses the index cannot see: `@objc`/`dynamic` members reached through selectors or KVO, `NSClassFromString`, reflection (`Mirror`), Interface Builder and storyboards (`@IBAction`, `@IBOutlet`, custom classes), `Codable` properties decoded by string keys, resource or localization keys built at runtime. `--retain-objc-accessible`, `--retain-objc-annotated`, `--retain-codable-properties` and `--retain-runtime-localized-keys` cover whole classes of these.
- Public API of a library: declarations used only by clients outside the scanned project. Use `--retain-public` (`retain_public` in the configuration). Since 3.21.0, `retain_public_modules` limits this to a list of modules.
- Code for another platform or build configuration: code behind `#if os(...)` or a compilation flag the scanned scheme does not build looks unused. Scan each platform and configuration, and remove only what is unused in all of them.

When unsure, read the troubleshooting guide: https://github.com/tiny-earth-moon/outskirts/blob/master/docs/troubleshooting.md

## 3. Remove in a safe order

1. Wholly unused files (every declaration in the file is reported).
2. Unused declarations, then unused parameters and imports.
3. Last, accessibility that could be narrower and other suggestions.

After each batch: rebuild every scheme and platform, run the tests, then scan again, since removing code often reveals more unused code. Keep batches small enough to revert.

## 4. False positives: keep the code on purpose

Never delete code just to silence a result you have not confirmed. For a real use the index cannot see:

- Add a comment command with a reason on the line above the declaration: `// outskirts:ignore - created from the storyboard`. The `// periphery:ignore` spelling works the same. `// outskirts:ignore:parameters a,b` covers parameters, and `// outskirts:ignore:all` at the top of a file covers the whole file.
- Or set the matching `retain_*` option in the configuration when the case is a pattern rather than a single declaration.

If a false positive reproduces on a small example, report it at https://github.com/tiny-earth-moon/outskirts/issues with the snippet, the command and the output of `outskirts version`.
