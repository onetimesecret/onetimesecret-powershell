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

# Connection comes from ONETIME_BASE_URL / ONETIME_CUSTOMER_EXTID / ONETIME_API_TOKEN.
Import-Module OnetimeSecret -ErrorAction Stop

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
