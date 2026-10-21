function Get-OtsReceipt {
    <#
    .SYNOPSIS
        Gets receipts: the creator-side record of a secret's state and links.

    .DESCRIPTION
        With -ReceiptId, returns the receipt for one or more secrets you
        created, including whether the secret has been viewed, burned or has
        expired, and the share, receipt and burn URLs.

        With no identifier, lists the authenticated account's receipts for
        secrets created in the last 30 days (requires a credential).

    .PARAMETER ReceiptId
        The receipt identifier, or the receipt link it appears in.

    .PARAMETER Connection
        Connection to use instead of the default from Connect-OtsAccount.

    .EXAMPLE
        Get-OtsReceipt

        ReceiptId   SecretId   State    Created              Expires
        ---------   --------   -----    -------              -------
        rcp5f8d...    sec3kd9f...  new      20/10/2026 14:04:05  27/10/2026 14:04:05
        rcp2ab1...    secxx91c...  received 19/10/2026 09:12:33

    .EXAMPLE
        Get-OtsReceipt -ReceiptId rcp5f8d... | Select-Object State, IsReceived, Received

        Checks whether a specific secret has been picked up.

    .EXAMPLE
        Get-OtsReceipt | Where-Object IsReceived | Format-Table ReceiptId, Received, Recipients

    .OUTPUTS
        OnetimeSecret.Receipt

    .LINK
        https://api.onetimesecret.com/doc/api-v2/operation/operation-v2_showreceipt
    .LINK
        https://api.onetimesecret.com/doc/api-v2/operation/operation-v2_listreceipts
    #>
    [CmdletBinding(DefaultParameterSetName = 'Recent')]
    [OutputType('OnetimeSecret.Receipt')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ById', Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [Alias('Id', 'Key')]
        [string[]] $ReceiptId,

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
        if ($PSCmdlet.ParameterSetName -eq 'Recent') {
            try {
                Assert-OtsAuthenticated -Connection $resolved -Operation 'Listing receipts'
                $response = Invoke-OtsRequest -Connection $resolved -Method GET -Path 'receipt/recent'
                foreach ($record in @(Get-OtsProperty $response 'records' @())) {
                    ConvertFrom-OtsReceipt -Record $record -Connection $resolved
                }
            }
            catch {
                $PSCmdlet.ThrowTerminatingError($_)
            }
            return
        }

        foreach ($item in $ReceiptId) {
            try {
                $identifier = ConvertTo-OtsIdentifier -Value $item -Kind Receipt
                $response = Invoke-OtsRequest -Connection $resolved -Method GET -Path ('{0}receipt/{1}' -f $prefix, [uri]::EscapeDataString($identifier))
                ConvertFrom-OtsReceipt -Record (Get-OtsProperty $response 'record') -Details (Get-OtsProperty $response 'details') -Connection $resolved
            }
            catch {
                $PSCmdlet.WriteError($_)
            }
        }
    }
}
