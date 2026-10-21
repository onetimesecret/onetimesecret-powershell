# Connection construction and validation. A connection is a plain
# PSCustomObject tagged with the 'OnetimeSecret.Connection' type name so it
# can be bound with [PSTypeName()] on parameters without a PowerShell class
# (which would not be visible to callers without `using module`).

# The apex domain serves the marketing site; the API lives on the regional
# hosts, self-hosted installs and custom domains.
$script:ApexHosts = @('onetimesecret.com', 'www.onetimesecret.com')
$script:RegionalHosts = @(
    'https://us.onetimesecret.com'
    'https://eu.onetimesecret.com'
    'https://ca.onetimesecret.com'
    'https://uk.onetimesecret.com'
    'https://nz.onetimesecret.com'
)

# A customer external id ("extid") is an opaque, case-insensitive identifier
# that always begins with "ur". The API also accepts the account email.
$script:CustomerExtidPattern = '^ur[a-z0-9]+$'

function Resolve-OtsServerUri {
    <#
    .SYNOPSIS
        Validates and normalises a server base URI.
    #>
    [CmdletBinding()]
    [OutputType([uri])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string] $ServerUri
    )

    $uri = $null
    if (-not [uri]::TryCreate($ServerUri.Trim(), [System.UriKind]::Absolute, [ref] $uri) -or
        $uri.Scheme -notin @('http', 'https')) {
        throw ("ServerUri must be an absolute http(s) URL such as {0}; got '{1}'." -f $script:RegionalHosts[0], $ServerUri)
    }

    if ($uri.Host.ToLowerInvariant() -in $script:ApexHosts) {
        throw ("{0} is the Onetime Secret website, not an API host. Use your region's host ({1}), your self-hosted domain or your custom domain." -f $uri.Host, ($script:RegionalHosts -join ', '))
    }

    # Keep any path prefix (reverse-proxied installs) but drop a trailing slash
    # so request paths can be appended predictably.
    $builder = New-Object -TypeName System.UriBuilder -ArgumentList $uri
    $builder.Path = $builder.Path.TrimEnd('/')
    $builder.Query = ''
    $builder.Fragment = ''
    return $builder.Uri
}

function Test-OtsUsername {
    <#
    .SYNOPSIS
        Returns $true when a Basic-auth username looks like an extid or an email.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [AllowEmptyString()]
        [string] $Username
    )

    if ([string]::IsNullOrWhiteSpace($Username)) { return $false }
    if ($Username -match $script:CustomerExtidPattern) { return $true }
    return ($Username -match '^[^@\s]+@[^@\s]+\.[^@\s]+$')
}

function Get-OtsUserAgent {
    [CmdletBinding()]
    [OutputType([string])]
    param()

    $edition = if ($PSVersionTable.ContainsKey('PSEdition')) { $PSVersionTable.PSEdition } else { 'Desktop' }
    $os = [System.Environment]::OSVersion.Platform
    return 'OnetimeSecret-PowerShell/{0} (PowerShell/{1}; {2}; {3})' -f $script:ModuleVersion, $PSVersionTable.PSVersion, $edition, $os
}

function New-OtsConnectionObject {
    <#
    .SYNOPSIS
        Builds a validated 'OnetimeSecret.Connection' object.
    #>
    [CmdletBinding()]
    [OutputType('OnetimeSecret.Connection')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Builds an in-memory connection object; nothing outside the process changes.')]
    param(
        [Parameter(Mandatory)]
        [string] $ServerUri,

        [Parameter()]
        [AllowNull()]
        [pscredential] $Credential,

        [Parameter()]
        [ValidateRange(1, 3600)]
        [int] $TimeoutSec = 30,

        [Parameter()]
        [AllowEmptyString()]
        [string] $UserAgent
    )

    $resolvedUri = Resolve-OtsServerUri -ServerUri $ServerUri

    if ($null -ne $Credential -and -not (Test-OtsUsername -Username $Credential.UserName)) {
        throw ("'{0}' is not a customer extid or account email. The extid is the ""ur..."" identifier shown at the bottom of the user menu when you are signed in; pass it as the credential's username with your API token as the password." -f $Credential.UserName)
    }

    if ([string]::IsNullOrWhiteSpace($UserAgent)) {
        $UserAgent = Get-OtsUserAgent
    }

    $username = $null
    if ($null -ne $Credential) { $username = $Credential.UserName }

    $connection = [PSCustomObject] @{
        PSTypeName  = 'OnetimeSecret.Connection'
        ServerUri   = $resolvedUri
        Username    = $username
        IsAnonymous = ($null -eq $Credential)
        ApiVersion  = 'v2'
        TimeoutSec  = $TimeoutSec
        UserAgent   = $UserAgent
        Credential  = $Credential
    }

    return $connection
}

function Resolve-OtsConnection {
    <#
    .SYNOPSIS
        Picks the connection a cmdlet should use.
    .DESCRIPTION
        Precedence: an explicit -Connection argument, then the module default
        set by Connect-OtsAccount, then the ONETIME_BASE_URL /
        ONETIME_CUSTOMER_EXTID / ONETIME_API_TOKEN environment variables
        (which become the module default on first use).
    #>
    [CmdletBinding()]
    [OutputType('OnetimeSecret.Connection')]
    param(
        [Parameter(Position = 0)]
        [AllowNull()]
        [object] $Connection
    )

    if ($null -ne $Connection) {
        if ($Connection.PSObject.TypeNames -notcontains 'OnetimeSecret.Connection') {
            throw 'Connection must be an object returned by Connect-OtsAccount -PassThru or Get-OtsConnection.'
        }
        return $Connection
    }

    if ($null -ne $script:DefaultConnection) {
        return $script:DefaultConnection
    }

    $baseUrl = [System.Environment]::GetEnvironmentVariable('ONETIME_BASE_URL')
    if (-not [string]::IsNullOrWhiteSpace($baseUrl)) {
        $credential = $null
        $extid = [System.Environment]::GetEnvironmentVariable('ONETIME_CUSTOMER_EXTID')
        $token = [System.Environment]::GetEnvironmentVariable('ONETIME_API_TOKEN')
        if (-not [string]::IsNullOrWhiteSpace($extid) -and -not [string]::IsNullOrWhiteSpace($token)) {
            $credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $extid, (ConvertTo-OtsSecureString -Value $token)
        }

        Write-Verbose 'No explicit connection; using ONETIME_* environment variables.'
        $script:DefaultConnection = New-OtsConnectionObject -ServerUri $baseUrl -Credential $credential
        return $script:DefaultConnection
    }

    throw 'Not connected. Run Connect-OtsAccount (or set ONETIME_BASE_URL, ONETIME_CUSTOMER_EXTID and ONETIME_API_TOKEN) first.'
}
