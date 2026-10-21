# OnetimeSecret PowerShell module

[![CI](https://github.com/onetimesecret/onetimesecret-powershell/actions/workflows/ci.yml/badge.svg)](https://github.com/onetimesecret/onetimesecret-powershell/actions/workflows/ci.yml)
[![PowerShell Gallery](https://img.shields.io/powershellgallery/v/OnetimeSecret)](https://www.powershellgallery.com/packages/OnetimeSecret)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

The official PowerShell client for the [Onetime Secret](https://onetimesecret.com)
API. Share sensitive information through a link that can only be viewed once.

This repository, **`onetimesecret-powershell`**, is the PowerShell member of
the Onetime Secret SDK family. The module it ships is **`OnetimeSecret`** and
every cmdlet carries the **`Ots`** noun prefix (`New-OtsSecret`,
`Get-OtsReceipt`, …).

- **Idiomatic PowerShell**: approved verbs, pipeline binding, `-WhatIf` on
  anything destructive, typed objects with default views, comment-based help
  for every cmdlet, and errors you can branch on.
- **No dependencies**: built on `Invoke-WebRequest` alone.
- **Windows PowerShell 5.1 and PowerShell 7+** on Windows, macOS and Linux
  (see [Supported PowerShell versions](#supported-powershell-versions)).
- **API v2** only. (v1 is in maintenance mode; the v3 preview is not stable.)

## Installation

```powershell
Install-Module OnetimeSecret -Scope CurrentUser
```

Or, from a clone of this repository:

```powershell
Import-Module ./src/OnetimeSecret/OnetimeSecret.psd1
```

## Supported PowerShell versions

- **Windows PowerShell 5.1** (Desktop edition) on Windows.
- **PowerShell 7.x** (Core edition) on Windows, macOS and Linux.

CI runs every change on all four (7 on Ubuntu, macOS and Windows, plus
5.1), and the published module declares both editions. There are no other
dependencies; HTTP goes through `Invoke-WebRequest`.

The two differ in one place: how a failed HTTP request reaches the module.
On PowerShell 7 requests are sent with `-SkipHttpErrorCheck`, so 4xx/5xx
replies come back as ordinary responses and the `HttpResponseException`,
which carries the whole request including the `Authorization` header, is
never thrown and never lands in `$Error`. Windows PowerShell 5.1 has no such
switch: `Invoke-WebRequest` throws a `WebException`, the module reads the
status, headers and body from its `Response` and discards the exception.
That `WebException` does pass through `$Error`, but it holds only the
response, not the request headers, so the credential stays out of it on both
editions. The error records the module itself raises are identical on both.

On 5.1 the module also opts the process into TLS 1.2 at import, which
older Windows builds do not enable by default.

## Quick start

```powershell
# Onetime Secret is region-isolated, so pick your region's host (or your own
# instance). The credential's username is your customer extid, the password
# is your API token.
Connect-OtsAccount -ServerUri https://eu.onetimesecret.com -Credential (Get-Credential -UserName ur1abc23def)

# Share a value you already have
$receipt = New-OtsSecret -Secret 'hunter2' -Ttl (New-TimeSpan -Hours 1)
$receipt.ShareUrl        # give this to the recipient
$receipt.ReceiptId       # keep this to check on, or burn, the secret

# Or have the server generate one
New-OtsSecret -Generate -Length 24 | Select-Object Value, ShareUrl

# Has it been picked up yet?
Get-OtsSecretStatus -SecretId $receipt.SecretId

# Reveal (this consumes the secret; -WhatIf and -Confirm are supported)
(Receive-OtsSecret -SecretId $receipt.ShareUrl).Value

# Burn an unread secret early
$receipt | Remove-OtsSecret

# What have I shared in the last 30 days?
Get-OtsReceipt
```

No account? Use the guest endpoints:

```powershell
Connect-OtsAccount -ServerUri https://eu.onetimesecret.com -Anonymous
New-OtsSecret -Secret 'hunter2'
```

### Authentication

Authentication is HTTP Basic. The username is your **customer extid**, a
short opaque identifier beginning with `ur` that is shown (with a copy
button) at the bottom of the user menu when you are signed in; your account
email also works. The password is your **API token** from the account's API
settings page.

For automation, build the credential from environment variables or a secret
store rather than typing it:

```powershell
$token = ConvertTo-SecureString $env:ONETIME_API_TOKEN -AsPlainText -Force
$cred  = [pscredential]::new($env:ONETIME_CUSTOMER_EXTID, $token)
Connect-OtsAccount https://us.onetimesecret.com -Credential $cred
```

Or skip `Connect-OtsAccount` entirely: when `ONETIME_BASE_URL` is set (with
`ONETIME_CUSTOMER_EXTID` and `ONETIME_API_TOKEN` for an authenticated
session), the module connects from the environment on first use. These are
the same variable names the other Onetime Secret SDKs use.

Several servers at once:

```powershell
$eu = Connect-OtsAccount https://eu.onetimesecret.com -Credential $euCred -PassThru
$us = Connect-OtsAccount https://us.onetimesecret.com -Credential $usCred -PassThru
New-OtsSecret -Secret 'for europe' -Connection $eu
New-OtsSecret -Secret 'for america' -Connection $us
```

## Cmdlets

| Cmdlet                   | Purpose                                                       |
| ------------------------ | ------------------------------------------------------------- |
| `Connect-OtsAccount`     | Set the server and credential; `-Anonymous` for guest use.    |
| `Disconnect-OtsAccount`  | Forget the default connection.                                |
| `Get-OtsConnection`      | Show the connection in use.                                   |
| `New-OtsSecret`          | Conceal a value, or `-Generate` a random one.                 |
| `Get-OtsSecret`          | Read a secret's metadata without revealing it.                |
| `Get-OtsSecretStatus`    | Cheap existence/state check; several identifiers per request. |
| `Receive-OtsSecret`      | Reveal a secret. Consumes it.                                 |
| `Get-OtsReceipt`         | One receipt by id, or the last 30 days of them.               |
| `Set-OtsReceipt`         | Set the private memo on a receipt.                            |
| `Remove-OtsSecret`       | Burn a secret via its receipt.                                |
| `Get-OtsStatus`          | Service health for a server.                                  |
| `Get-OtsVersion`         | Server build version (authenticated; see below).              |
| `Get-OtsSupportedLocale` | Locales a server can serve.                                   |

`Get-OtsVersion` needs a credential: the server withholds the build version
from anonymous callers (it fingerprints an install for CVE matching), even
though the OpenAPI document lists the endpoint without a security
requirement. Anonymously it fails with an `AuthenticationError` (HTTP 401).
`Get-OtsStatus` and `Get-OtsSupportedLocale` are public.

Full reference: `Get-Help New-OtsSecret -Full`, `Get-Help about_OnetimeSecret`,
or the generated pages under [docs/cmdlets](docs/cmdlets/).

### Vocabulary

A **secret** is the content and the link the recipient opens; its
`SecretId` is the key in that link. A **receipt** is the creator's record of
that secret (state, timing, memo, URLs); its `ReceiptId` is what you use to
check on or **burn** the secret. `New-OtsSecret` returns the receipt, which
carries both ids.

### Pipelines

Every identifier parameter binds from the pipeline by property name, so
objects flow between cmdlets, and bare keys or full links are both accepted:

```powershell
New-OtsSecret -Generate | Set-OtsReceipt -Memo 'temporary SFTP password' -PassThru
Get-OtsReceipt | Where-Object State -eq new | Remove-OtsSecret -Confirm:$false
Get-OtsReceipt | Get-OtsSecretStatus
Get-Content ./kubeconfig -Raw | New-OtsSecret -Ttl '2:00:00' -DisplayType markdown
```

### Errors

API failures are terminating errors with the server's error envelope
attached, so scripts can react precisely:

```powershell
try {
    Receive-OtsSecret -SecretId $id -ErrorAction Stop
}
catch {
    switch ($_.Exception.Data['StatusCode']) {
        404 { 'Already viewed, burned or expired.' }
        429 { 'Rate limited; retry later.' }
        default { throw }
    }
}
```

| Where                         | What                                                                              |
| ----------------------------- | --------------------------------------------------------------------------------- |
| `FullyQualifiedErrorId`       | `OnetimeSecret.Api.<error_type>` (e.g. `OnetimeSecret.Api.RecordNotFound`)        |
| `CategoryInfo.Category`       | Mapped from the status: `ObjectNotFound`, `AuthenticationError`, `LimitsExceeded`… |
| `Exception.Data`              | `StatusCode`, `ErrorType`, `Field`, `ErrorId`, `RequestId`, `Method`, `Uri`, `Response` |
| `ErrorDetails.RecommendedAction` | A hint for the common cases (bad credentials, account required)                |

Cmdlets that accept several identifiers (`Get-OtsSecret`, `Get-OtsReceipt`,
`Remove-OtsSecret`, `Set-OtsReceipt`) write a non-terminating error per failed
item and continue, in the usual PowerShell way. Idempotent GETs are retried
twice on 429/502/503/504 with backoff, honouring `Retry-After`.

### Timing values

`-Ttl` takes a `TimeSpan` (`(New-TimeSpan -Hours 1)`, `'01:00:00'`,
`'1.00:00:00'`). A bare integer is rejected rather than silently read as
ticks. Timestamps on returned objects are local `DateTime`s; durations are
`TimeSpan`s. The untouched API record is always available as `RawResponse`.

## Examples

The scripts in [examples/](examples/) are small, complete programs that run
straight from a clone (they import the module from `src/`, or an installed
copy if `src/` is absent). They read the same environment variables as the
other Onetime Secret SDKs and work anonymously when no credentials are set:

```powershell
$env:ONETIME_BASE_URL = 'https://eu.onetimesecret.com'   # your region or your own instance
# Optional, for an authenticated session:
# $env:ONETIME_CUSTOMER_EXTID = 'ur1abc23def'
# $env:ONETIME_API_TOKEN = '...'

./examples/roundtrip.ps1                          # conceal, inspect, reveal, confirm the state changed
./examples/share-file.ps1 -Path ./notes.txt -Hours 2
./examples/wait-for-pickup.ps1 -TimeoutMinutes 5  # poll until the link is opened, else burn
```

`roundtrip.ps1` defaults to `https://eu.onetimesecret.com` when
`ONETIME_BASE_URL` is unset; the other two require it.

## Development

```powershell
./build.ps1 -Bootstrap        # install InvokeBuild, Pester 5, PSScriptAnalyzer, platyPS
./build.ps1                   # PSScriptAnalyzer + unit tests (run inside pwsh; -Task takes a list)
./build.ps1 -Task Build       # stage a publishable module under output/
./build.ps1 -Task Docs        # regenerate docs/cmdlets from comment-based help
```

Live tests against the guest endpoints (they create, then burn or reveal,
a few five-minute secrets):

```powershell
$env:OTS_INTEGRATION = '1'
$env:ONETIME_BASE_URL = 'https://eu.onetimesecret.com'
./build.ps1 -Task Test
```

Layout:

```
src/OnetimeSecret/        the module (loaded directly during development)
  Public/                 one exported cmdlet per file
  Private/                helpers: HTTP, errors, converters, connection
  en-US/                  about_OnetimeSecret help topic
tests/                    Pester 5 (Module quality gates, Unit, Integration)
examples/                 small end-to-end scripts (see Examples above)
docs/                     releasing.md and generated cmdlet reference
output/                   build output (gitignored)
OnetimeSecret.build.ps1   Invoke-Build tasks; build.ps1 bootstraps and runs them
```

The release build concatenates `Private/` and `Public/` into a single
`.psm1`, so the published module does no file discovery at import time.

See [CONTRIBUTING.md](CONTRIBUTING.md) for conventions and
[docs/releasing.md](docs/releasing.md) for how releases are cut.

## Related

- API documentation: <https://api.onetimesecret.com>
- Ruby SDK: [onetimesecret-ruby](https://github.com/onetimesecret/onetimesecret-ruby)
- Onetime Secret: <https://onetimesecret.com> · [source](https://github.com/onetimesecret/onetimesecret)

## License

MIT. See [LICENSE](LICENSE).
