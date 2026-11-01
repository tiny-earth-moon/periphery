# Security Policy

## Supported versions

Only the latest release receives security fixes.

## Reporting a vulnerability

Please report vulnerabilities privately through GitHub Security Advisories:
<https://github.com/tiny-earth-moon/periphery/security/advisories/new>

Do not open a public issue for a security problem. This is a volunteer-maintained fork: expect an initial response within about 7 days. There is no bug bounty.

## Scanning untrusted projects

A scan runs `xcodebuild`, `swift build` or `bazel` on the project being analysed, which can execute arbitrary code from that project (build scripts, plugins, macros). Only scan projects you trust.
