# Changelog

All notable changes to the `OnetimeSecret` PowerShell module are recorded
here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
and the project uses [Semantic Versioning](https://semver.org/).

The release workflow requires a `## [X.Y.Z]` section matching the tag.

## [Unreleased]

### Fixed

- Failed API calls no longer carry the underlying HTTP exception on the
  error record. On PowerShell 7 that exception holds the full request,
  `Authorization` header included, and reached `$Error` and anything that
  serialised the error. HTTP failures are now read from the response
  (`-SkipHttpErrorCheck`) on 7+ and only the transport error's message is
  kept.

## [0.1.0] - 2026-10-20

Initial release.

### Added

- `Connect-OtsAccount`, `Disconnect-OtsAccount` and `Get-OtsConnection` for
  per-region connections with HTTP Basic auth (customer extid + API token),
  anonymous guest connections, explicit `-Connection` objects, and
  `ONETIME_BASE_URL` / `ONETIME_CUSTOMER_EXTID` / `ONETIME_API_TOKEN`
  environment fallback.
- `New-OtsSecret` to conceal a plain or SecureString value, or `-Generate` a
  random one with length and character-set options; supports passphrase,
  TTL, recipients, custom share domain and display type. A generated value is
  read back from the receipt immediately (the server discloses it once) and
  returned in `Value`.
- `Get-OtsSecret`, `Get-OtsSecretStatus` (batched), `Receive-OtsSecret`
  (reveal, with `-WhatIf`/`-Confirm` and `-AsSecureString`).
- `Get-OtsReceipt` (single or recent), `Set-OtsReceipt` (memo),
  `Remove-OtsSecret` (burn, with `-WhatIf`/`-Confirm`).
- `Get-OtsStatus` service health check for one or more servers.
- Typed output objects (`OnetimeSecret.Receipt`, `.Secret`, `.SecretStatus`,
  `.Connection`, `.ServiceStatus`) with default table views; identifiers
  accepted as bare keys or full links; pipeline binding across cmdlets.
- Structured errors: `OnetimeSecret.Api.<error_type>` error ids, categories
  mapped from HTTP status, and the API error envelope in `Exception.Data`.
- Retries with backoff for idempotent requests on 429/502/503/504.
- Windows PowerShell 5.1 and PowerShell 7+ support; CI on Linux, macOS and
  Windows; PSScriptAnalyzer and Pester quality gates; Gallery release
  workflow.

[Unreleased]: https://github.com/onetimesecret/onetimesecret-powershell/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/onetimesecret/onetimesecret-powershell/releases/tag/v0.1.0
