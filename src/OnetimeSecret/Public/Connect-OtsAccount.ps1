function Connect-OtsAccount {
    <#
    .SYNOPSIS
        Establishes the connection that other OnetimeSecret cmdlets use.

    .DESCRIPTION
        Validates the server URI and credential, then stores the resulting
        connection as the module default so subsequent cmdlets need no
        -Connection argument. Use -PassThru to also return the connection object,
        which can be passed explicitly when talking to several servers at once.

        Authentication is HTTP Basic: the credential's username is your customer
        extid (the "ur..." identifier at the bottom of the user menu when signed
        in) or your account email, and the password is your API token from the
        account's API settings page.

        Alternatively, set the ONETIME_BASE_URL, ONETIME_CUSTOMER_EXTID and
        ONETIME_API_TOKEN environment variables and skip this cmdlet entirely;
        the module connects on first use.

        Onetime Secret runs region-isolated deployments, so there is no default
        server. Pick your region's host (https://us.onetimesecret.com,
        https://eu.onetimesecret.com, https://ca.onetimesecret.com,
        https://uk.onetimesecret.com, https://nz.onetimesecret.com), your
        self-hosted instance or your custom domain.

    .PARAMETER ServerUri
        Base URL of the API host, for example https://eu.onetimesecret.com.
        The apex domain onetimesecret.com is the website and is rejected.

    .PARAMETER Credential
        PSCredential whose username is the customer extid (or account email) and
        whose password is the API token.

    .PARAMETER Anonymous
        Connect without credentials. Only the guest endpoints are available
        (create, reveal, burn, show); listing receipts and setting memos are not.

    .PARAMETER TimeoutSec
        Per-request timeout in seconds. Defaults to 30.

    .PARAMETER UserAgent
        Override the User-Agent header. Defaults to a string identifying this
        module and the PowerShell version.

    .PARAMETER PassThru
        Return the connection object in addition to setting it as the default.

    .EXAMPLE
        Connect-OtsAccount -ServerUri https://eu.onetimesecret.com -Credential (Get-Credential -UserName 'ur1abc23def' -Message 'API token')

        Prompts for the API token and connects as the given customer.

    .EXAMPLE
        $token = ConvertTo-SecureString $env:ONETIME_API_TOKEN -AsPlainText -Force
        $cred  = [pscredential]::new('ur1abc23def', $token)
        Connect-OtsAccount https://us.onetimesecret.com -Credential $cred

        Connects non-interactively from an automation script.

    .EXAMPLE
        $eu = Connect-OtsAccount https://eu.onetimesecret.com -Anonymous -PassThru
        New-OtsSecret -Secret 'hunter2' -Connection $eu

        Uses an explicit anonymous connection for a single call.

    .OUTPUTS
        OnetimeSecret.Connection (only with -PassThru)

    .LINK
        https://api.onetimesecret.com/doc/api-v2/authentication
    #>
    [CmdletBinding(DefaultParameterSetName = 'Credential')]
    [OutputType('OnetimeSecret.Connection')]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [Alias('BaseUrl', 'Server', 'Uri')]
        [string] $ServerUri,

        [Parameter(Mandatory, ParameterSetName = 'Credential')]
        [System.Management.Automation.Credential()]
        [pscredential] $Credential,

        [Parameter(Mandatory, ParameterSetName = 'Anonymous')]
        [switch] $Anonymous,

        [Parameter()]
        [ValidateRange(1, 3600)]
        [int] $TimeoutSec = 30,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $UserAgent,

        [Parameter()]
        [switch] $PassThru
    )

    try {
        $parameters = @{
            ServerUri  = $ServerUri
            TimeoutSec = $TimeoutSec
        }
        if ($PSCmdlet.ParameterSetName -eq 'Credential') { $parameters['Credential'] = $Credential }
        if ($PSBoundParameters.ContainsKey('UserAgent')) { $parameters['UserAgent'] = $UserAgent }

        $connection = New-OtsConnectionObject @parameters
        $script:DefaultConnection = $connection

        if ($connection.IsAnonymous) {
            Write-Verbose ('Connected anonymously to {0}' -f $connection.ServerUri)
        }
        else {
            Write-Verbose ('Connected to {0} as {1}' -f $connection.ServerUri, $connection.Username)
        }

        if ($PassThru) { return $connection }
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}
