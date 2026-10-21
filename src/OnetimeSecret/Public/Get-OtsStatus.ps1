function Get-OtsStatus {
    <#
    .SYNOPSIS
        Reports whether the Onetime Secret service is up.

    .DESCRIPTION
        Calls the unauthenticated status endpoint and returns the service's
        own health report plus the server it came from. Useful as a connectivity
        check before a batch of operations, or in monitoring.

    .PARAMETER Connection
        Connection to use instead of the default from Connect-OtsAccount.

    .PARAMETER ServerUri
        Check a server without connecting first.

    .EXAMPLE
        Get-OtsStatus

        ServerUri                     Status  IsHealthy
        ---------                     ------  ---------
        https://eu.onetimesecret.com/ nominal      True

    .EXAMPLE
        'https://us.onetimesecret.com', 'https://eu.onetimesecret.com' | Get-OtsStatus

        Checks several regions without connecting.

    .OUTPUTS
        OnetimeSecret.ServiceStatus

    .LINK
        https://api.onetimesecret.com/doc/api-v2/operation/operation-v2_systemstatus
    #>
    [CmdletBinding(DefaultParameterSetName = 'Connection')]
    [OutputType('OnetimeSecret.ServiceStatus')]
    param(
        [Parameter(ParameterSetName = 'Connection')]
        [PSTypeName('OnetimeSecret.Connection')]
        $Connection,

        [Parameter(Mandatory, ParameterSetName = 'ServerUri', Position = 0, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [Alias('BaseUrl', 'Server')]
        [string[]] $ServerUri
    )

    process {
        $targets = @()
        try {
            if ($PSCmdlet.ParameterSetName -eq 'ServerUri') {
                foreach ($uri in $ServerUri) { $targets += New-OtsConnectionObject -ServerUri $uri }
            }
            else {
                $targets += Resolve-OtsConnection -Connection $Connection
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }

        foreach ($target in $targets) {
            try {
                $response = Invoke-OtsRequest -Connection $target -Method GET -Path 'status'
                $status = [string] (Get-OtsProperty $response 'status')

                [PSCustomObject] @{
                    PSTypeName  = 'OnetimeSecret.ServiceStatus'
                    ServerUri   = $target.ServerUri
                    Status      = $status
                    IsHealthy   = (ConvertTo-OtsBoolean (Get-OtsProperty $response 'success')) -and ($status -in @('nominal', 'ok', 'healthy'))
                    Locale      = [string] (Get-OtsProperty $response 'locale')
                    RawResponse = $response
                }
            }
            catch {
                $PSCmdlet.WriteError($_)
            }
        }
    }
}
