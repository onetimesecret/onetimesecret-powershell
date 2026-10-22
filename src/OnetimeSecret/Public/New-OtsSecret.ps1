function New-OtsSecret {
    <#
    .SYNOPSIS
        Creates a one-time secret and returns its receipt, including the share link.

    .DESCRIPTION
        Conceals a value you supply (-Secret or -SecureSecret), or asks the
        server to generate a random one (-Generate). The returned receipt object
        has the ShareUrl to hand to the recipient, the ReceiptId you keep to
        check on or burn the secret, and the generated Value when -Generate was
        used.

        Anonymous connections use the guest endpoints and are subject to the
        guest limits (shorter maximum TTL, no custom share domain).

    .PARAMETER Secret
        The secret content as plain text. Accepts pipeline input, so
        `Get-Content token.txt -Raw | New-OtsSecret` works.

    .PARAMETER SecureSecret
        The secret content as a SecureString, for callers that already hold it
        that way.

    .PARAMETER Generate
        Have the server generate a random secret instead of supplying one. The
        generated value is returned in the receipt's Value property. The server
        discloses it only once, so New-OtsSecret reads it back immediately;
        it will not appear on later Get-OtsReceipt calls.

    .PARAMETER Length
        Length of the generated secret (4-128). The server default applies when
        omitted.

    .PARAMETER CharacterSet
        Character classes to draw the generated secret from: Uppercase,
        Lowercase, Numbers, Symbols. The server default applies when omitted.

    .PARAMETER ExcludeAmbiguous
        Leave out look-alike characters (such as 0/O and 1/l) from a generated
        secret.

    .PARAMETER Passphrase
        Optional passphrase the recipient must supply to reveal the secret.

    .PARAMETER Ttl
        How long the secret stays retrievable, as a TimeSpan (for example
        (New-TimeSpan -Hours 1) or '01:00:00'). Integers are not accepted
        because PowerShell would read them as ticks. The server default and
        plan limits apply when omitted.

    .PARAMETER Recipient
        Email address(es) to notify with the share link.

    .PARAMETER ShareDomain
        Custom domain to build the share link on (authenticated accounts with a
        verified domain only).

    .PARAMETER DisplayType
        How the recipient's page renders the secret: 'text' (default) or
        'markdown'.

    .PARAMETER Connection
        Connection to use instead of the default from Connect-OtsAccount.

    .EXAMPLE
        New-OtsSecret -Secret 'hunter2' -Ttl (New-TimeSpan -Hours 1)

        ReceiptId          SecretId           State  Expires              ShareUrl
        ---------          --------           -----  -------              --------
        rcp5f8...            sec3kd...            new    20/10/2026 15:04:05  https://eu.onetimesecret.com/secret/sec3kd...

    .EXAMPLE
        $pass = Read-Host -AsSecureString 'Passphrase'
        $link = (New-OtsSecret -Secret $apiKey -Passphrase $pass -Recipient ops@example.com).ShareUrl

        Protects the secret with a passphrase and emails the link.

    .EXAMPLE
        New-OtsSecret -Generate -Length 24 -CharacterSet Uppercase,Lowercase,Numbers | Select-Object Value, ShareUrl

        Generates a 24-character alphanumeric secret and shows both the value
        and the link to share.

    .EXAMPLE
        Get-Content ./kubeconfig -Raw | New-OtsSecret -Ttl '2:00:00' -DisplayType markdown

        Conceals a file's contents from the pipeline.

    .OUTPUTS
        OnetimeSecret.Receipt

    .LINK
        https://api.onetimesecret.com/doc/api-v2/operation/operation-v2_concealsecret
    .LINK
        https://api.onetimesecret.com/doc/api-v2/operation/operation-v2_generatesecret
    #>
    [CmdletBinding(DefaultParameterSetName = 'Conceal', SupportsShouldProcess, ConfirmImpact = 'Low')]
    [OutputType('OnetimeSecret.Receipt')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', 'Secret',
        Justification = 'The secret content is the payload being shared, not a credential; SecureString input is offered alongside.')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'Conceal', Position = 0, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [Alias('Value', 'Content')]
        [string] $Secret,

        [Parameter(Mandatory, ParameterSetName = 'ConcealSecure')]
        [securestring] $SecureSecret,

        [Parameter(Mandatory, ParameterSetName = 'Generate')]
        [switch] $Generate,

        [Parameter(ParameterSetName = 'Generate')]
        [ValidateRange(4, 128)]
        [int] $Length,

        [Parameter(ParameterSetName = 'Generate')]
        [ValidateSet('Uppercase', 'Lowercase', 'Numbers', 'Symbols')]
        [string[]] $CharacterSet,

        [Parameter(ParameterSetName = 'Generate')]
        [switch] $ExcludeAmbiguous,

        [Parameter()]
        [securestring] $Passphrase,

        [Parameter()]
        [Alias('TimeToLive', 'ExpiresIn')]
        [timespan] $Ttl,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string[]] $Recipient,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $ShareDomain,

        [Parameter()]
        [ValidateSet('text', 'markdown')]
        [string] $DisplayType,

        [Parameter()]
        [PSTypeName('OnetimeSecret.Connection')]
        $Connection
    )

    begin {
        try {
            $resolved = Resolve-OtsConnection -Connection $Connection
            $prefix = Get-OtsPathPrefix -Connection $resolved

            if ($PSBoundParameters.ContainsKey('Ttl') -and $Ttl.TotalSeconds -lt 1) {
                throw 'Ttl must be at least one second. Pass a TimeSpan such as (New-TimeSpan -Hours 1) or ''01:00:00''; a bare integer is interpreted as ticks.'
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }

    process {
        try {
            $isGenerate = $PSCmdlet.ParameterSetName -eq 'Generate'

            $payload = [ordered] @{
                kind = if ($isGenerate) { 'generate' } else { 'conceal' }
            }

            if ($isGenerate) {
                if ($PSBoundParameters.ContainsKey('Length')) { $payload['length'] = $Length }

                $characterSets = [ordered] @{}
                if ($PSBoundParameters.ContainsKey('CharacterSet')) {
                    $characterSets['uppercase'] = [bool] ($CharacterSet -contains 'Uppercase')
                    $characterSets['lowercase'] = [bool] ($CharacterSet -contains 'Lowercase')
                    $characterSets['numbers']   = [bool] ($CharacterSet -contains 'Numbers')
                    $characterSets['symbols']   = [bool] ($CharacterSet -contains 'Symbols')
                }
                if ($ExcludeAmbiguous) { $characterSets['exclude_ambiguous'] = $true }
                if ($characterSets.Count -gt 0) { $payload['character_sets'] = $characterSets }
            }
            else {
                $plain = if ($PSCmdlet.ParameterSetName -eq 'ConcealSecure') { ConvertFrom-OtsSecureString -SecureString $SecureSecret } else { $Secret }
                if ([string]::IsNullOrEmpty($plain)) { throw 'The secret content is empty.' }
                $payload['secret'] = $plain
            }

            if ($Passphrase) { $payload['passphrase'] = ConvertFrom-OtsSecureString -SecureString $Passphrase }
            if ($PSBoundParameters.ContainsKey('Ttl')) { $payload['ttl'] = [int] [math]::Floor($Ttl.TotalSeconds) }
            if ($Recipient) { $payload['recipient'] = @($Recipient) }
            if ($ShareDomain) { $payload['share_domain'] = $ShareDomain }
            if ($DisplayType) { $payload['display_type'] = $DisplayType }

            $description = if ($isGenerate) { 'Generate secret' } else { 'Conceal secret' }
            if (-not $PSCmdlet.ShouldProcess($resolved.ServerUri.ToString(), $description)) { return }

            $path = if ($isGenerate) { '{0}secret/generate' -f $prefix } else { '{0}secret/conceal' -f $prefix }
            $response = Invoke-OtsRequest -Connection $resolved -Method POST -Path $path -Body @{ secret = $payload }

            $record = Get-OtsProperty $response 'record'
            $receipt = Get-OtsProperty $record 'receipt'
            $secretRecord = Get-OtsProperty $record 'secret'
            $details = Get-OtsProperty $response 'details'
            $domain = [string] (Get-OtsProperty $record 'share_domain')

            if ($isGenerate) {
                # The server hands out a generated value exactly once: on the
                # first read of the receipt after creation, not in the create
                # response itself. Fetch it now so the caller gets it in Value;
                # a later Get-OtsReceipt would come back empty.
                $receiptId = [string] (Get-OtsProperty $receipt 'identifier')
                try {
                    $shown = Invoke-OtsRequest -Connection $resolved -Method GET -Path ('{0}receipt/{1}' -f $prefix, [uri]::EscapeDataString($receiptId))
                    $receipt = Get-OtsProperty $shown 'record' $receipt
                    $details = Get-OtsProperty $shown 'details' $details
                }
                catch {
                    # Name the failure by error id and status only: the body
                    # of a failed or garbled receipt read can hold the value.
                    $reason = ($_.FullyQualifiedErrorId -split ',')[0]
                    $status = [int] $_.Exception.Data['StatusCode']
                    if ($status -gt 0) { $reason = '{0}, HTTP {1}' -f $reason, $status }
                    Write-Warning ('The secret was generated but its value could not be read back ({0}). Open {1} to see it.' -f $reason, ('{0}/receipt/{1}' -f $resolved.ServerUri.AbsoluteUri.TrimEnd('/'), $receiptId))
                }
            }

            ConvertFrom-OtsReceipt -Record $receipt -SecretRecord $secretRecord -Details $details -Connection $resolved -ShareDomain $domain
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
