<#
.SYNOPSIS
    Shares a file's contents as a one-time secret and prints the link.
.EXAMPLE
    ./share-file.ps1 -Path ./kubeconfig -Hours 2 -Recipient ops@example.com
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $Path,

    [int] $Hours = 1,

    [string[]] $Recipient
)

# Prefer the module in this clone so the examples run without installing it;
# fall back to an installed copy (Install-Module OnetimeSecret).
$manifest = Join-Path (Split-Path -Parent $PSScriptRoot) 'src/OnetimeSecret/OnetimeSecret.psd1'
if (Test-Path $manifest) { Import-Module $manifest -Force -ErrorAction Stop }
else { Import-Module OnetimeSecret -ErrorAction Stop }

$parameters = @{
    Secret      = Get-Content -Path $Path -Raw
    Ttl         = New-TimeSpan -Hours $Hours
    DisplayType = 'markdown'
}
if ($Recipient) { $parameters['Recipient'] = $Recipient }

$receipt = New-OtsSecret @parameters
Write-Host ('Share link : {0}' -f $receipt.ShareUrl)
Write-Host ('Receipt    : {0}' -f $receipt.ReceiptUrl)
Write-Host ('Expires    : {0}' -f $receipt.Expires)
