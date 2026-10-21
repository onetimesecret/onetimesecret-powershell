function Receive-OtsSecret {
    <#
    .SYNOPSIS
        Reveals a secret's value. This consumes the secret; it cannot be read again.

    .DESCRIPTION
        Retrieves the secret content and destroys it on the server in the same
        step. Supply -Passphrase when the creator set one. Supports -WhatIf and
        -Confirm because the operation is irreversible.

        By default Value is a plain string so it can be used directly in
        scripts; pass -AsSecureString to receive it as a SecureString instead.

    .PARAMETER SecretId
        The secret identifier, or the full share link it appears in.

    .PARAMETER Passphrase
        The passphrase the creator protected the secret with, if any.

    .PARAMETER AsSecureString
        Return Value as a SecureString.

    .PARAMETER Connection
        Connection to use instead of the default from Connect-OtsAccount.

    .EXAMPLE
        (Receive-OtsSecret -SecretId 'https://eu.onetimesecret.com/secret/sec3kd9f...').Value

        Prints the secret content.

    .EXAMPLE
        $pass = Read-Host -AsSecureString 'Passphrase'
        Receive-OtsSecret sec3kd9f... -Passphrase $pass -AsSecureString

        Reveals a passphrase-protected secret and keeps the value as a SecureString.

    .EXAMPLE
        Receive-OtsSecret sec3kd9f... -WhatIf

        Shows what would happen without consuming the secret.

    .OUTPUTS
        OnetimeSecret.Secret

    .LINK
        https://api.onetimesecret.com/doc/api-v2/operation/operation-v2_secret_revealsecret
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType('OnetimeSecret.Secret')]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [Alias('Id', 'Key')]
        [string] $SecretId,

        [Parameter()]
        [securestring] $Passphrase,

        [Parameter()]
        [switch] $AsSecureString,

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
        try {
            $identifier = ConvertTo-OtsIdentifier -Value $SecretId -Kind Secret

            if (-not $PSCmdlet.ShouldProcess($identifier, 'Reveal and destroy secret')) { return }

            $body = @{ continue = $true }
            if ($Passphrase) { $body['passphrase'] = ConvertFrom-OtsSecureString -SecureString $Passphrase }

            $response = Invoke-OtsRequest -Connection $resolved -Method POST -Path ('{0}secret/{1}/reveal' -f $prefix, [uri]::EscapeDataString($identifier)) -Body $body
            ConvertFrom-OtsSecret -Record (Get-OtsProperty $response 'record') -Connection $resolved -AsSecureString:$AsSecureString
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
