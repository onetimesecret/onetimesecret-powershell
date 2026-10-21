<#
.SYNOPSIS
    Creates a generated secret, then polls until the recipient has revealed it.
.DESCRIPTION
    Demonstrates Get-OtsSecretStatus as a cheap, non-consuming poll, and
    burning the secret if nobody picks it up in time.
#>
[CmdletBinding()]
param(
    [int] $TimeoutMinutes = 15
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
    if (-not $status.Exists -or $status.State -ne 'new') {
        Write-Host ('Picked up (state: {0}).' -f $status.State)
        return
    }
    Start-Sleep -Seconds 30
}

Write-Warning 'Nobody revealed the secret in time; burning it.'
$receipt | Remove-OtsSecret -Confirm:$false
