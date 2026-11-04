function Disconnect-OtsAccount {
    <#
    .SYNOPSIS
        Forgets the default connection set by Connect-OtsAccount.

    .DESCRIPTION
        Clears the module-level default connection. Connection objects you
        obtained with -PassThru are unaffected; there is no server-side session
        to end because the API is authenticated per request.

    .EXAMPLE
        Disconnect-OtsAccount

    .OUTPUTS
        None
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([void])]
    param()

    if ($null -eq $script:DefaultConnection) {
        Write-Verbose 'No default connection to clear.'
        return
    }

    $target = $script:DefaultConnection.ServerUri.ToString()
    if ($PSCmdlet.ShouldProcess($target, 'Clear default connection')) {
        $script:DefaultConnection = $null
    }
}
