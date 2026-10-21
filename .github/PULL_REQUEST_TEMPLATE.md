## What

<!-- One or two sentences on what changes and why. Link the issue if there is one. -->

## Checklist

- [ ] `./build.ps1` passes locally (PSScriptAnalyzer + Pester)
- [ ] New or changed parameters have help text and a unit test on the request they send
- [ ] `CHANGELOG.md` has a line under `## [Unreleased]`
- [ ] `docs/cmdlets/` regenerated with `./build.ps1 -Task Docs` if help changed
- [ ] Works on Windows PowerShell 5.1 (or you are relying on CI to confirm)
