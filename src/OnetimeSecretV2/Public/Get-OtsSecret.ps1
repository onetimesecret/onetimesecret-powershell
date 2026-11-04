function Get-OtsSecret {
    <#
    .SYNOPSIS
        Gets a secret's metadata without revealing its value.

    .DESCRIPTION
        Returns state, passphrase requirement and timing for a secret, leaving
        the value untouched. Use Receive-OtsSecret to reveal (and thereby
        destroy) it.

        The server records this access as a preview on the secret's receipt,
        which its creator can see. For a lighter check that only answers "does
        it still exist and what state is it in", use Get-OtsSecretStatus.

    .PARAMETER SecretId
        The secret identifier, or the full share link it appears in.

    .PARAMETER Connection
        Connection to use instead of the default from Connect-OtsAccount.

    .EXAMPLE
        Get-OtsSecret -SecretId 'https://eu.onetimesecret.com/secret/sec3kd9f...'

    .EXAMPLE
        New-OtsSecret -Secret 'hunter2' | Get-OtsSecret

        Reads the metadata of a secret just created, via SecretId on the pipeline.

    .OUTPUTS
        OnetimeSecret.Secret

    .LINK
        https://api.onetimesecret.com/doc/api-v2/operation/operation-v2_showsecret
    #>
    [CmdletBinding()]
    [OutputType('OnetimeSecret.Secret')]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [Alias('Id', 'Key')]
        [string[]] $SecretId,

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
        foreach ($item in $SecretId) {
            try {
                $identifier = ConvertTo-OtsIdentifier -Value $item -Kind Secret
                $response = Invoke-OtsRequest -Connection $resolved -Method GET -Path ('{0}secret/{1}' -f $prefix, [uri]::EscapeDataString($identifier))
                ConvertFrom-OtsSecret -Record (Get-OtsProperty $response 'record') -Connection $resolved
            }
            catch {
                $PSCmdlet.WriteError($_)
            }
        }
    }
}
