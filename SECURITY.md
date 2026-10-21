# Security policy

## Reporting a vulnerability

Please do not open a public issue for security problems in this module or in
the Onetime Secret service. Email **security@onetimesecret.com** with a
description, steps to reproduce, and the module version (`Get-Module
OnetimeSecret`). We acknowledge reports within three business days.

Onetime Secret's wider policy, including scope and safe-harbour terms, is at
<https://github.com/onetimesecret/onetimesecret/blob/main/SECURITY.md>.

## Supported versions

Only the latest minor release on the PowerShell Gallery receives fixes.

## What this module does with your secrets

- Secret content, passphrases and API tokens are sent to the server you
  connected to over HTTPS and are never written to disk or logs by this
  module. `-Verbose` output includes request URLs but never bodies or
  headers.
- `Receive-OtsSecret` returns the value as a plain string by default so it is
  usable in scripts; pass `-AsSecureString` if you need it protected in
  memory. Be aware that PowerShell transcripts and host history can capture
  anything printed to the console.
- API tokens live in a `PSCredential` on the connection object. Treat that
  object like the token itself.
- Error records raised for failed API calls carry the status code, the
  server's error envelope and the request URL, but not the underlying HTTP
  exception: on PowerShell 7 that object holds the full request, including
  the `Authorization` header, and would leak the token into anything that
  serialises `$Error`. Request URLs do contain secret and receipt
  identifiers, so treat logged errors as you would the links themselves.
