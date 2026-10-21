function Remove-OtsSecret {
    <#
    .SYNOPSIS
        Burns a secret before anyone reads it.

    .DESCRIPTION
        Permanently destroys an unread secret using its receipt identifier (the
        creator's handle; the secret identifier in the share link does not
        work here). Returns the updated receipt. Supports -WhatIf and -Confirm.

    .PARAMETER ReceiptId
        The receipt identifier, or the receipt link it appears in. Receipt
        objects from New-OtsSecret and Get-OtsReceipt bind this from the pipeline.

    .PARAMETER Passphrase
        The passphrase the secret was created with, if any.

    .PARAMETER PassThru
        Return the updated receipt. By default nothing is returned, in keeping
        with other Remove-* cmdlets.

    .PARAMETER Connection
        Connection to use instead of the default from Connect-OtsAccount.

    .EXAMPLE
        Remove-OtsSecret -ReceiptId rcp5f8d...

    .EXAMPLE
        Get-OtsReceipt | Where-Object State -eq 'new' | Remove-OtsSecret -Confirm:$false

        Burns every unread secret the account created in the last 30 days.

    .EXAMPLE
        $receipt = New-OtsSecret -Secret 'oops'
        $receipt | Remove-OtsSecret -PassThru

        Creates and immediately burns a secret, returning the burned receipt.

    .OUTPUTS
        OnetimeSecret.Receipt (only with -PassThru)

    .LINK
        https://api.onetimesecret.com/doc/api-v2/operation/operation-v2_receipt_burnsecret
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType('OnetimeSecret.Receipt')]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [Alias('Id', 'Key')]
        [string[]] $ReceiptId,

        [Parameter()]
        [securestring] $Passphrase,

        [Parameter()]
        [switch] $PassThru,

        [Parameter()]
        [PSTypeName('OnetimeSecret.Connection')]
        $Connection
    )

    begin {
        try {
            $resolved = Resolve-OtsConnection -Connection $Connection
            $prefix = Get-OtsPathPrefix -Connection $resolved
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }

    process {
        foreach ($item in $ReceiptId) {
            try {
                $identifier = ConvertTo-OtsIdentifier -Value $item -Kind Receipt

                if (-not $PSCmdlet.ShouldProcess($identifier, 'Burn secret')) { continue }

                $body = @{ continue = $true }
                if ($Passphrase) { $body['passphrase'] = ConvertFrom-OtsSecureString -SecureString $Passphrase }

                $null = Invoke-OtsRequest -Connection $resolved -Method POST -Path ('{0}receipt/{1}/burn' -f $prefix, [uri]::EscapeDataString($identifier)) -Body $body

                if ($PassThru) {
                    # The burn response echoes the receipt as it was before the
                    # burn, so read it again to report the real state.
                    $response = Invoke-OtsRequest -Connection $resolved -Method GET -Path ('{0}receipt/{1}' -f $prefix, [uri]::EscapeDataString($identifier))
                    ConvertFrom-OtsReceipt -Record (Get-OtsProperty $response 'record') -Details (Get-OtsProperty $response 'details') -Connection $resolved
                }
            }
            catch {
                $PSCmdlet.WriteError($_)
            }
        }
    }
}
