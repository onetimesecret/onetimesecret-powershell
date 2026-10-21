<#
.SYNOPSIS
    Shares a file's contents as a one-time secret and prints the link.
.DESCRIPTION
    The connection comes from ONETIME_BASE_URL (for example
    https://eu.onetimesecret.com) plus, for an authenticated session,
    ONETIME_CUSTOMER_EXTID and ONETIME_API_TOKEN. With only the base URL set
    the guest endpoints are used.
.PARAMETER Markdown
    Render the secret as Markdown on the recipient's page instead of plain
    text. Needs a server with markdown display enabled.
.EXAMPLE
    ./share-file.ps1 -Path ./kubeconfig -Hours 2 -Recipient ops@example.com
.EXAMPLE
    ./share-file.ps1 -Path ./runbook.md -Markdown
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $Path,

    [int] $Hours = 1,

    [string[]] $Recipient,

    [switch] $Markdown
)

$ErrorActionPreference = 'Stop'

# Prefer the module in this clone so the examples run without installing it;
# fall back to an installed copy (Install-Module OnetimeSecret).
$manifest = Join-Path (Split-Path -Parent $PSScriptRoot) 'src/OnetimeSecret/OnetimeSecret.psd1'
if (Test-Path $manifest) { Import-Module $manifest -Force -ErrorAction Stop }
else { Import-Module OnetimeSecret -ErrorAction Stop }

$parameters = @{
    Secret = Get-Content -Path $Path -Raw
    Ttl    = New-TimeSpan -Hours $Hours
}
if ($Recipient) { $parameters['Recipient'] = $Recipient }
if ($Markdown) { $parameters['DisplayType'] = 'markdown' }

$receipt = New-OtsSecret @parameters
Write-Host ('Share link : {0}' -f $receipt.ShareUrl)
Write-Host ('Receipt    : {0}' -f $receipt.ReceiptUrl)
Write-Host ('Expires    : {0}' -f $receipt.Expires)
