---
description: Keep scan options in .outskirts.yml: file lookup, command line precedence, the JSON Schema for editor completion and outskirts config check.
---

# Configuration

Once you have settled on the options your project needs, keep them in a YAML configuration file so that `outskirts scan` alone runs the same scan, in a terminal, in Xcode and in CI.

## The configuration file

outskirts reads `.outskirts.yml` at the project root (`--project-root`, the current directory by default). `.outskirts.yaml`, `.periphery.yml` and `.periphery.yaml` are read too, so existing projects keep working unchanged. `--config <file>` points to another file; a relative path is resolved from `--project-root`.

Every key is the name of a scan option in `snake_case`, e.g. `--retain-public` is `retain_public`. The [options reference](options.md) lists every key with its type and default.

```yaml
project: MyApp.xcodeproj
schemes:
  - MyApp
exclude_tests: true
retain_public: false
report_exclude:
  - "**/Generated/**"
```

### Writing the file from a scan

The simplest way to write the file is to run a scan with the options you want and `--verbose`. Near the beginning of the output, the `[configuration:begin]` section shows your configuration formatted as YAML. Copy it into `.outskirts.yml` at the root of your project. The guided setup (`outskirts scan --setup`) offers to write the file for you.

### Examples

The [`examples/`](https://github.com/tiny-earth-moon/outskirts/tree/master/examples) folder holds commented files for common scenarios:

| File | Scenario |
|------|----------|
| `xcode-project.outskirts.yml` | Minimal Xcode project |
| `swiftpm-package.outskirts.yml` | Swift package |
| `types-only.outskirts.yml` | Report only unused types |
| `ci-strict.outskirts.yml` | CI gate with a machine-readable report |
| `library-public-api.outskirts.yml` | Library with a public API |
| `cache-and-skip-build.outskirts.yml` | Reuse an existing build |

Use one with `outskirts scan --config examples/<file>`, or copy it to `.outskirts.yml`.

## Command line and file

The command line takes precedence over the configuration file, which takes precedence over the defaults:

- An option given on the command line wins even when its value is the default: `--format xcode` wins over `format: json` in the file.
- An option that is not given leaves the value of the file untouched.
- Every boolean option has a `--no-` form to switch off, for one run, what the file enables: `--no-strict`, `--no-retain-public`, `--no-quiet`...
- A list given on the command line replaces the list of the file; the default `index_exclude` patterns are always kept.
- `--setup`, `--project-root` and `--config` are command line only, and `xcode_list_arguments` is configuration file only.

## Validation

Values are checked when the file is loaded:

- A value that does not suit its key, such as a number for a boolean (`strict: 1`), a format that does not exist (`format: xml`) or a quoted number for an integer, is reported on stderr as `<file>: 'strict' expects a boolean, got the integer 1`, and the default is kept.
- A key that is not an option is reported too, with the closest option when there is one: `invalid key 'retain_pubic' (did you mean 'retain_public'?)`.
- The file only has to be a mapping, otherwise the scan stops with an error.

Two shapes are accepted in place of the exact one: a single value for an option that takes a list (`exclude_targets: Demo` is `exclude_targets: [Demo]`), and the strings `"true"` and `"false"` for a boolean, which is also reported.

## Schema and editor completion

The keys, their types and their defaults are published as a JSON Schema, [`outskirts.schema.json`](https://github.com/tiny-earth-moon/outskirts/blob/master/outskirts.schema.json), also printed by `outskirts config schema`. Editors that use the YAML language server (the YAML extension of VS Code, among others) offer completion, descriptions and type checks when the first line of the file is:

```yaml
# yaml-language-server: $schema=https://raw.githubusercontent.com/tiny-earth-moon/outskirts/master/outskirts.schema.json
```

The files written by `outskirts scan --setup` and the files under `examples/` start with this line.

## Checking a configuration file

To check a file without scanning, run:

```sh
outskirts config check
outskirts config check --config <file> \
  --project-root <dir>
```

It reports on stderr, in the same words as a scan, unknown keys with the closest option, values of the wrong type, invalid `report_exclude` and `retain_attributes` entries, and baseline and output paths a scan would refuse. It prints `<file>: ok` and exits with status 0 when there is nothing to report, and exits with status 1 when it finds a problem or no configuration file.

## Paths

Relative paths of the file and of the command line are resolved from `--project-root`, not from the directory the command was typed in: `--config`, `--baseline`, `--write-baseline`, `--write-results`, `--index-store-path`, `--json-package-manifest-path`, `--generic-project-config` and `--relative-to`. Globs (`index_exclude`, `report_exclude`, `report_include`, `retain_files`) are relative to the project directory or absolute, see [Excluding files](excluding-files.md).
