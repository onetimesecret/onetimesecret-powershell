function Get-OtsVersion {
    <#
    .SYNOPSIS
        Reports the version of the Onetime Secret server you are connected to.

    .DESCRIPTION
        Calls the version endpoint and returns the server's build version as
        a [version] plus the server it came from. Useful for confirming which
        release a self-hosted instance runs, or for gating features on it.

        The endpoint requires an authenticated connection. The OpenAPI
        document lists it without a security requirement, but the server
        (onetimesecret.com and current self-hosted releases) withholds the
        build version from anonymous callers because it fingerprints the
        install for CVE matching. Anonymously, or with bad credentials, the
        call fails with an AuthenticationError (HTTP 401). Use Get-OtsStatus
        for an unauthenticated health check.

    .PARAMETER Connection
        Connection to use instead of the default from Connect-OtsAccount.

    .EXAMPLE
        Get-OtsVersion

        ServerUri                     Version Locale
        ---------                     ------- ------
        https://eu.onetimesecret.com/ 0.26.5  en

    .EXAMPLE
        if ((Get-OtsVersion).Version -lt [version] '0.26.0') { throw 'Server too old.' }

        Checks the server release before relying on a newer feature.

    .OUTPUTS
        OnetimeSecret.ServiceVersion

    .LINK
        https://api.onetimesecret.com/doc/api-v2/operation/operation-v2_systemversion
    #>
    [CmdletBinding()]
    [OutputType('OnetimeSecret.ServiceVersion')]
    param(
        [Parameter()]
        [PSTypeName('OnetimeSecret.Connection')]
        $Connection
    )

    process {
        try {
            $resolved = Resolve-OtsConnection -Connection $Connection
            $response = Invoke-OtsRequest -Connection $resolved -Method GET -Path 'version'
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }

        # The server reports [major, minor, patch]; a self-hosted build may
        # append a prerelease label. Keep the raw list, and offer a [version]
        # where the numeric components allow one.
        $components = @(Get-OtsProperty $response 'version' @() | ForEach-Object { [string] $_ })
        $versionText = $components -join '.'
        $version = $null
        $numeric = @($components | Where-Object { $_ -match '^\d+$' })
        if ($numeric.Count -ge 2) {
            try { $version = [version] ($numeric -join '.') } catch { $version = $null }
        }

        [PSCustomObject] @{
            PSTypeName        = 'OnetimeSecret.ServiceVersion'
            ServerUri         = $resolved.ServerUri
            Version           = $version
            VersionString     = $versionText
            VersionComponents = $components
            Locale            = [string] (Get-OtsProperty $response 'locale')
            RawResponse       = $response
        }
    }
}
