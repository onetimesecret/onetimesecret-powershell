# Contributing

Thanks for helping improve the Onetime Secret PowerShell module.

## Getting set up

```powershell
git clone https://github.com/onetimesecret/onetimesecret-powershell
cd onetimesecret-powershell
./build.ps1 -Bootstrap            # InvokeBuild, Pester 5, PSScriptAnalyzer, platyPS
./build.ps1                       # Analyze + Test
Import-Module ./src/OnetimeSecret/OnetimeSecret.psd1 -Force   # try it
```

Windows PowerShell 5.1 and PowerShell 7 are both supported, and CI runs
both. If you only have one locally, the other will be checked on your pull
request.

## Conventions

- **One public cmdlet per file** in `src/OnetimeSecret/Public/`, named after
  the cmdlet. Private helpers live in `Private/` and may group related
  functions in one file.
- **Approved verbs** (`Get-Verb`) and the `Ots` noun prefix. Nouns are
  singular.
- **Advanced functions** with `[CmdletBinding()]`, `[OutputType()]` and
  comment-based help that includes a synopsis, description, every parameter
  and at least one example. `tests/Module.Tests.ps1` enforces this.
- **Destructive operations** declare `SupportsShouldProcess` and call
  `$PSCmdlet.ShouldProcess`.
- **Errors**: throw through `$PSCmdlet.ThrowTerminatingError` for the
  single-item case and `$PSCmdlet.WriteError` per item in loops. API failures
  go through `New-OtsErrorRecord` so callers get a consistent shape.
- **Secrets in parameters** are `[securestring]` unless the plain value is
  the payload itself (`New-OtsSecret -Secret`).
- **Compatibility**: no syntax newer than Windows PowerShell 5.1 in
  `src/` (no ternary, `??`, `-AsPlainText` on `ConvertFrom-SecureString`,
  three-argument `Join-Path`, etc.). PSScriptAnalyzer's compatibility rules
  catch most of it; CI on 5.1 catches the rest.
- **Formatting** is whatever `PSScriptAnalyzerSettings.psd1` says. Run
  `Invoke-Formatter` or your editor's PSScriptAnalyzer integration.
- Manifest `FunctionsToExport` is explicit; add new cmdlets there.

## Tests

- Unit tests mock `Invoke-WebRequest` inside the module
  (`Mock -ModuleName OnetimeSecret`) and assert on the request that would
  have been sent. Add a test for every new parameter that changes the wire
  format.
- Integration tests under `tests/Integration/` hit a real server's guest
  endpoints and run only when `ONETIME_LIVE=1` and `ONETIME_BASE_URL`
  are set.
- Keep `tests/Unit/TestHelpers.psm1` the single source of canned payloads.

## Pull requests

1. Branch from `main`.
2. Add a line under `## [Unreleased]` in `CHANGELOG.md`.
3. Run `./build.ps1` locally.
4. If you changed help text, run `./build.ps1 -Task Docs` and commit the
   regenerated `docs/cmdlets/`.
5. Open the PR; the template asks for the rest.

Releases are cut by maintainers; see [docs/releasing.md](docs/releasing.md).
