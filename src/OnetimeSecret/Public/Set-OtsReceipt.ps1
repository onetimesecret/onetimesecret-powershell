function Set-OtsReceipt {
    <#
    .SYNOPSIS
        Updates a receipt's memo.

    .DESCRIPTION
        Sets the private memo on a receipt (up to 500 characters) so you can
        note what a secret was for. Only the receipt's owner can do this, so an
        authenticated connection is required. Returns the updated receipt.

    .PARAMETER ReceiptId
        The receipt identifier, or the receipt link it appears in.

    .PARAMETER Memo
        The memo text. Pass an empty string to clear it.

    .PARAMETER PassThru
        Return the updated receipt.

    .PARAMETER Connection
        Connection to use instead of the default from Connect-OtsAccount.

    .EXAMPLE
        Set-OtsReceipt -ReceiptId rcp5f8d... -Memo 'DB password for the migration on Friday'

    .EXAMPLE
        New-OtsSecret -Generate | Set-OtsReceipt -Memo 'Temporary SFTP credential' -PassThru

    .OUTPUTS
        OnetimeSecret.Receipt (only with -PassThru)

    .LINK
        https://api.onetimesecret.com/doc/api-v2/operation/operation-v2_updatereceipt
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low')]
    [OutputType('OnetimeSecret.Receipt')]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [Alias('Id', 'Key')]
        [string[]] $ReceiptId,

        [Parameter(Mandatory, Position = 1)]
        [AllowEmptyString()]
        [ValidateLength(0, 500)]
        [string] $Memo,

        [Parameter()]
        [switch] $PassThru,

        [Parameter()]
        [PSTypeName('OnetimeSecret.Connection')]
        $Connection
    )

    begin {
        try {
            $resolved = Resolve-OtsConnection -Connection $Connection
            Assert-OtsAuthenticated -Connection $resolved -Operation 'Updating a receipt'
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }

    process {
        foreach ($item in $ReceiptId) {
            try {
                $identifier = ConvertTo-OtsIdentifier -Value $item -Kind Receipt

                if (-not $PSCmdlet.ShouldProcess($identifier, 'Set memo')) { continue }

                $response = Invoke-OtsRequest -Connection $resolved -Method PATCH -Path ('receipt/{0}' -f [uri]::EscapeDataString($identifier)) -Body @{ memo = $Memo }

                if ($PassThru) {
                    ConvertFrom-OtsReceipt -Record (Get-OtsProperty $response 'record') -Details (Get-OtsProperty $response 'details') -Connection $resolved
                }
            }
            catch {
                $PSCmdlet.WriteError($_)
            }
        }
    }
}
