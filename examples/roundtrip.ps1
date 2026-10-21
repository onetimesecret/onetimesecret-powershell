<#
.SYNOPSIS
    Walks a secret through its whole life: conceal, inspect, reveal, confirm.
.DESCRIPTION
    Demonstrates the module end to end against any Onetime Secret server:

      1. connect (anonymously unless credentials are set)
      2. conceal a value with New-OtsSecret and keep the receipt
      3. read the receipt and the secret's status: state is 'new'
      4. reveal the secret with Receive-OtsSecret and compare the value
      5. read the receipt again and confirm the state has changed

    Configuration comes from the environment variables every Onetime Secret
    SDK uses:

      ONETIME_BASE_URL         API host; defaults to https://eu.onetimesecret.com
      ONETIME_CUSTOMER_EXTID   customer extid (the "ur..." id) or account email
      ONETIME_API_TOKEN        API token

    With only ONETIME_BASE_URL (or nothing) set, the guest endpoints are used
    and no account is needed. The revealed value is compared, not printed.
    Nothing is written to disk and no credential is handled by the script
    itself; the module reads the variables.
.PARAMETER Secret
    The value to conceal. Defaults to a random marker string.
.PARAMETER Minutes
    Lifetime of the secret. Defaults to 5 minutes; it is consumed within the
    run anyway.
.EXAMPLE
    ./roundtrip.ps1
.EXAMPLE
    $env:ONETIME_BASE_URL = 'https://us.onetimesecret.com'
    ./roundtrip.ps1 -Secret 'hunter2'
#>
[CmdletBinding()]
param(
    [string] $Secret = ('roundtrip ' + [guid]::NewGuid().ToString('N')),

    [int] $Minutes = 5
)

$ErrorActionPreference = 'Stop'

# Prefer the module in this clone so the examples run without installing it;
# fall back to an installed copy (Install-Module OnetimeSecret).
$manifest = Join-Path (Split-Path -Parent $PSScriptRoot) 'src/OnetimeSecret/OnetimeSecret.psd1'
if (Test-Path $manifest) { Import-Module $manifest -Force -ErrorAction Stop }
else { Import-Module OnetimeSecret -ErrorAction Stop }

# 1. Connect. The module builds its connection from ONETIME_BASE_URL,
#    ONETIME_CUSTOMER_EXTID and ONETIME_API_TOKEN on first use, anonymously
#    when the credential pair is missing. Onetime Secret is region-isolated,
#    so there is no built-in default host; this script falls back to the EU
#    region for the current process when nothing is set.
if ([string]::IsNullOrWhiteSpace($env:ONETIME_BASE_URL)) {
    $env:ONETIME_BASE_URL = 'https://eu.onetimesecret.com'
}

$connection = Get-OtsConnection
if ($null -eq $connection) { throw 'Could not build a connection from the ONETIME_* environment variables.' }
if ($connection.IsAnonymous) {
    Write-Host ('Connected to {0} anonymously (guest endpoints)' -f $connection.ServerUri)
}
else {
    Write-Host ('Connected to {0} as {1}' -f $connection.ServerUri, $connection.Username)
}

$health = Get-OtsStatus
Write-Host ('Service status: {0} (healthy: {1})' -f $health.Status, $health.IsHealthy)

# 2. Conceal. The receipt is the creator's handle: it carries the share link
#    for the recipient and the receipt id for checking on or burning the secret.
$receipt = New-OtsSecret -Secret $Secret -Ttl (New-TimeSpan -Minutes $Minutes)
Write-Host ''
Write-Host ('Concealed.  ReceiptId: {0}' -f $receipt.ReceiptId)
Write-Host ('            SecretId:  {0}' -f $receipt.SecretId)
Write-Host ('            ShareUrl:  {0}' -f $receipt.ShareUrl)
Write-Host ('            Expires:   {0}' -f $receipt.Expires)

# 3. Inspect before anyone has looked at it.
$before = Get-OtsReceipt -ReceiptId $receipt.ReceiptId
$status = Get-OtsSecretStatus -SecretId $receipt.SecretId
Write-Host ''
Write-Host ('Before reveal: receipt state = {0}, secret state = {1}, exists = {2}' -f $before.State, $status.State, $status.Exists)

# 4. Reveal. This is what the recipient does; it consumes the secret. The
#    value is compared rather than printed so transcripts do not capture it.
$revealed = Receive-OtsSecret -SecretId $receipt.ShareUrl -Confirm:$false
$valueMatches = $revealed.Value -ceq $Secret
Write-Host ''
Write-Host ('Revealed:      secret state = {0}, value matches = {1}, length = {2}' -f $revealed.State, $valueMatches, $revealed.Value.Length)

# 5. Confirm the receipt now reports the pickup.
$after = Get-OtsReceipt -ReceiptId $receipt.ReceiptId
$statusAfter = Get-OtsSecretStatus -SecretId $receipt.SecretId
Write-Host ('After reveal:  receipt state = {0}, received = {1}, secret state = {2}, exists = {3}' -f $after.State, $after.IsReceived, $statusAfter.State, $statusAfter.Exists)

Write-Host ''
if ($valueMatches -and $before.State -eq 'new' -and $after.State -ne 'new') {
    Write-Host ('Round trip complete: state went {0} -> {1}.' -f $before.State, $after.State)
}
else {
    Write-Error ('Round trip failed: value matches = {0}, state went {1} -> {2}.' -f $valueMatches, $before.State, $after.State)
}
