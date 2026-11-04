# Configuration examples

Commented `.outskirts.yml` configuration files for common scenarios. Each header states the scenario and the expected result. Every key exists in `Sources/Configuration/Configuration.swift` (checked against 3.15.0). Use one with `outskirts scan --config examples/<file>`, or copy it to `.outskirts.yml` at the project root (`.periphery.yml` is still read). The first line of each file points editors at the [JSON Schema](../outskirts.schema.json) of the configuration file, and `outskirts config check --config examples/<file>` checks a file without scanning.

| File | Scenario |
|------|----------|
| `xcode-project.outskirts.yml` | Minimal Xcode project: project, schemes, excluded targets and tests |
| `swiftpm-package.outskirts.yml` | Swift package: no project or scheme, build arguments |
| `types-only.outskirts.yml` | Report only unused types (`report_exclude` by kind, `jq` filtering on JSON `kind`) |
| `ci-strict.outskirts.yml` | CI gate: `strict`, `quiet`, machine-readable format, `write_results` |
| `library-public-api.outskirts.yml` | Library: `retain_public`, `retain_objc_accessible`, `retain_attributes`, `retain_unused_parameters_without_default` |
| `cache-and-skip-build.outskirts.yml` | Reuse an existing build: `skip_build`, `index_store_path`, `cache_max_age_days` |

An unknown key only logs a warning (`invalid key`), so run `outskirts scan --help` to see the options of your version.
