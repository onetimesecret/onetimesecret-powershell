function Get-OtsPathPrefix {
    <#
    .SYNOPSIS
        Returns 'guest/' for anonymous connections, '' otherwise.
    .DESCRIPTION
        The v2 API mirrors the secret and receipt endpoints under /guest for
        unauthenticated use. Endpoints without a guest twin (listing receipts,
        updating a memo, status checks) do not call this helper.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [PSTypeName('OnetimeSecret.Connection')]
        $Connection
    )

    if ($Connection.IsAnonymous) { return 'guest/' }
    return ''
}

function Assert-OtsAuthenticated {
    <#
    .SYNOPSIS
        Throws when an authenticated-only operation is attempted anonymously.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSTypeName('OnetimeSecret.Connection')]
        $Connection,

        [Parameter(Mandatory)]
        [string] $Operation
    )

    if ($Connection.IsAnonymous) {
        throw ('{0} requires an authenticated connection. Run Connect-OtsAccount with -Credential.' -f $Operation)
    }
}
