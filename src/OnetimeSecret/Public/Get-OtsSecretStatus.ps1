function Get-OtsSecretStatus {
    <#
    .SYNOPSIS
        Checks whether secrets still exist and what state they are in.

    .DESCRIPTION
        A lightweight, non-consuming check. Unknown identifiers come back with
        State 'unknown' and Exists $false rather than an error, which makes
        this the right call for polling ("has the recipient picked it up
        yet?"). Several identifiers are checked in a single request.

    .PARAMETER SecretId
        One or more secret identifiers or share links.

    .PARAMETER Connection
        Connection to use instead of the default from Connect-OtsAccount.

    .EXAMPLE
        Get-OtsSecretStatus -SecretId sec3kd9f..., sec8xy2a...

        SecretId     State    Exists Expires
        --------     -----    ------ -------
        sec3kd9f...    new        True 20/10/2026 15:04:05
        sec8xy2a...    unknown   False

    .EXAMPLE
        Get-OtsReceipt | Get-OtsSecretStatus

        Checks every recent receipt's secret in one request.

    .OUTPUTS
        OnetimeSecret.SecretStatus

    .LINK
        https://api.onetimesecret.com/doc/api-v2/operation/operation-v2_listsecretstatus
    #>
    [CmdletBinding()]
    [OutputType('OnetimeSecret.SecretStatus')]
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
            $identifiers = New-Object -TypeName System.Collections.Generic.List[string]
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }

    process {
        foreach ($item in $SecretId) {
            try {
                $identifiers.Add((ConvertTo-OtsIdentifier -Value $item -Kind Secret))
            }
            catch {
                $PSCmdlet.WriteError($_)
            }
        }
    }

    end {
        if ($identifiers.Count -eq 0) { return }

        try {
            if ($identifiers.Count -eq 1) {
                $response = Invoke-OtsRequest -Connection $resolved -Method GET -Path ('secret/{0}/status' -f [uri]::EscapeDataString($identifiers[0]))
                ConvertFrom-OtsSecretStatus -Record (Get-OtsProperty $response 'record') -Details (Get-OtsProperty $response 'details') -RequestedId $identifiers[0] -Connection $resolved
                return
            }

            $response = Invoke-OtsRequest -Connection $resolved -Method POST -Path 'secret/status' -Body @{ identifiers = @($identifiers) }
            $records = @(Get-OtsProperty $response 'records' @())

            # Keep the caller's order and report identifiers the server left out.
            $byId = @{}
            foreach ($record in $records) {
                $key = [string] (Get-OtsProperty $record 'identifier')
                if ($key) { $byId[$key] = $record }
            }

            foreach ($identifier in $identifiers) {
                $record = $null
                if ($byId.ContainsKey($identifier)) { $record = $byId[$identifier] }
                ConvertFrom-OtsSecretStatus -Record $record -RequestedId $identifier -Connection $resolved
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
