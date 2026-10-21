function Get-OtsConnection {
    <#
    .SYNOPSIS
        Returns the connection the module is currently using.

    .DESCRIPTION
        Returns the default connection set by Connect-OtsAccount, or one built
        from the ONETIME_* environment variables when nothing has been set yet.
        Returns nothing when neither exists.

    .EXAMPLE
        Get-OtsConnection

        ServerUri                      Username     IsAnonymous
        ---------                      --------     -----------
        https://eu.onetimesecret.com/  ur1abc23def        False

    .OUTPUTS
        OnetimeSecret.Connection
    #>
    [CmdletBinding()]
    [OutputType('OnetimeSecret.Connection')]
    param()

    try {
        Resolve-OtsConnection
    }
    catch {
        Write-Verbose $_.Exception.Message
    }
}
