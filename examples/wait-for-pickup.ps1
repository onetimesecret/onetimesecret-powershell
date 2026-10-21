<#
.SYNOPSIS
    Creates a generated secret, then polls until the recipient has revealed it.
.DESCRIPTION
    Demonstrates Get-OtsSecretStatus as a cheap, non-consuming poll, and
    burning the secret if nobody picks it up in time.

    The connection comes from ONETIME_BASE_URL (for example
    https://eu.onetimesecret.com) plus, optionally, ONETIME_CUSTOMER_EXTID
    and ONETIME_API_TOKEN.
.EXAMPLE
    ./wait-for-pickup.ps1 -TimeoutMinutes 5 -PollSeconds 10
#>
[CmdletBinding()]
param(
    [int] $TimeoutMinutes = 15,

    [int] $PollSeconds = 30
)

$ErrorActionPreference = 'Stop'

# Prefer the module in this clone so the examples run without installing it;
# fall back to an installed copy (Install-Module OnetimeSecret).
$manifest = Join-Path (Split-Path -Parent $PSScriptRoot) 'src/OnetimeSecret/OnetimeSecret.psd1'
if (Test-Path $manifest) { Import-Module $manifest -Force -ErrorAction Stop }
else { Import-Module OnetimeSecret -ErrorAction Stop }

$receipt = New-OtsSecret -Generate -Length 20 -Ttl (New-TimeSpan -Minutes $TimeoutMinutes)
Write-Host ('Send this link: {0}' -f $receipt.ShareUrl)

$deadline = (Get-Date).AddMinutes($TimeoutMinutes)
while ((Get-Date) -lt $deadline) {
    $status = Get-OtsSecretStatus -SecretId $receipt.SecretId
    if ($status.Exists -and $status.State -eq 'new') {
        Start-Sleep -Seconds $PollSeconds
        continue
    }

    # The status check only says the secret is no longer new; the receipt
    # says why (revealed, burned or expired) and when.
    $final = Get-OtsReceipt -ReceiptId $receipt.ReceiptId
    if ($final.IsReceived) {
        Write-Host ('Picked up at {0} (state: {1}).' -f $final.Received, $final.State)
    }
    else {
        Write-Host ('The secret is gone without being read (state: {0}).' -f $final.State)
    }
    return
}

Write-Warning 'Nobody revealed the secret in time; burning it.'
$receipt | Remove-OtsSecret -Confirm:$false
