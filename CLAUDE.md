# CLAUDE.md

Fork of Periphery, renamed outskirts in 3.16.0 (`periphery` stays an alias), kept working with current Xcode/Swift toolchains. Process (issue/PR/version, CHANGELOG, release, tap, external contributions): `CONTRIBUTING.md` § Fork process.

- Commits and PRs in English, Conventional Commits with a scope; conversation with the owner in French.
- Work in a worktree under `.worktrees/`, never push to `master` directly.
- Never touch `CHANGELOG.md` in a fix PR; only the release commit does.
- Tests: `swift test --filter <TestCase>`; the full suite runs under the machine's shared build lock when one is configured.
- Lint: `swiftformat --lint .` and `swiftlint lint --strict` (versions pinned in `.mise.toml`).
