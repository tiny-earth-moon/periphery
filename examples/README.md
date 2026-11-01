# Configuration examples

Commented `.periphery.yml` files for common scenarios. Each header states the scenario and the expected result. Every key exists in `Sources/Configuration/Configuration.swift` (checked against 3.12.8). Use one with `periphery scan --config examples/<file>`, or copy it to `.periphery.yml` at the project root.

| File | Scenario |
|------|----------|
| `xcode-project.periphery.yml` | Minimal Xcode project: project, schemes, excluded targets and tests |
| `swiftpm-package.periphery.yml` | Swift package: no project or scheme, build arguments |
| `types-only.periphery.yml` | Report only unused types (`report_exclude` by kind, `jq` filtering on JSON `kind`) |
| `ci-strict.periphery.yml` | CI gate: `strict`, `quiet`, machine-readable format, `write_results` |
| `library-public-api.periphery.yml` | Library: `retain_public`, `retain_objc_accessible`, `retain_attributes`, `retain_unused_parameters_without_default` |
| `cache-and-skip-build.periphery.yml` | Reuse an existing build: `skip_build`, `index_store_path`, `cache_max_age_days` |

An unknown key only logs a warning (`invalid key`), so run `periphery scan --help` to see the options of your version.
