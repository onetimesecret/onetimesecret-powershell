function Get-OtsSupportedLocale {
    <#
    .SYNOPSIS
        Lists the locales a Onetime Secret server can serve.

    .DESCRIPTION
        Calls the unauthenticated supported-locales endpoint and returns the
        locale codes the server has translations for, its default locale, and
        the locale it chose for this request. Useful when building a share
        link or notification for a recipient in a given language, or when
        checking what a self-hosted instance has enabled.

    .PARAMETER Connection
        Connection to use instead of the default from Connect-OtsAccount.

    .PARAMETER ServerUri
        Query a server without connecting first.

    .EXAMPLE
        Get-OtsSupportedLocale

        ServerUri                     DefaultLocale Locales
        ---------                     ------------- -------
        https://eu.onetimesecret.com/ en            {ar, bg, ca_ES, cs...}

    .EXAMPLE
        (Get-OtsSupportedLocale -ServerUri https://eu.onetimesecret.com).Locales -contains 'de'

        Checks whether German is available before localising a message.

    .OUTPUTS
        OnetimeSecret.SupportedLocales

    .LINK
        https://api.onetimesecret.com/doc/api-v2/operation/operation-v2_getsupportedlocales
    #>
    [CmdletBinding(DefaultParameterSetName = 'Connection')]
    [OutputType('OnetimeSecret.SupportedLocales')]
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
                $response = Invoke-OtsRequest -Connection $target -Method GET -Path 'supported-locales'

                [PSCustomObject] @{
                    PSTypeName    = 'OnetimeSecret.SupportedLocales'
                    ServerUri     = $target.ServerUri
                    Locales       = ConvertTo-OtsStringArray (Get-OtsProperty $response 'locales')
                    DefaultLocale = [string] (Get-OtsProperty $response 'default_locale')
                    Locale        = [string] (Get-OtsProperty $response 'locale')
                    RawResponse   = $response
                }
            }
            catch {
                $PSCmdlet.WriteError($_)
            }
        }
    }
}
