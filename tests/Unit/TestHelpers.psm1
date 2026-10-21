[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Factories for in-memory test fixtures.')]
param()

# Shared helpers for unit tests: canned API payloads and a way to read the
# JSON body a cmdlet sent, so tests assert on the wire format rather than on
# implementation details.

function New-FakeHttpResponse {
    <#
        Shapes a response like Invoke-WebRequest returns it. With a 4xx/5xx
        -StatusCode it models the PowerShell 7 -SkipHttpErrorCheck path, where
        HTTP failures come back as a response instead of an exception.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [object] $Body,

        [Parameter()]
        [int] $StatusCode = 200,

        [Parameter()]
        [hashtable] $Headers = @{}
    )

    $allHeaders = @{ 'Content-Type' = 'application/json' } + $Headers
    $content = if ($null -eq $Body) { '' } else { ConvertTo-Json -InputObject $Body -Depth 10 -Compress }

    [PSCustomObject] @{
        StatusCode = $StatusCode
        Content    = $content
        Headers    = $allHeaders
    }
}

function Get-SentJsonBody {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [object] $Body
    )

    if ($null -eq $Body) { return $null }
    if ($Body -is [byte[]]) { $Body = [System.Text.Encoding]::UTF8.GetString($Body) }
    return ($Body | ConvertFrom-Json)
}

function New-FakeReceiptRecord {
    [CmdletBinding()]
    param(
        [string] $ReceiptId = 'rcp1111111111111111111111',
        [string] $SecretId = 'sec2222222222222222222222',
        [string] $State = 'new',
        [int] $Ttl = 3600
    )

    $now = [long] [math]::Floor(((Get-Date).ToUniversalTime() - [datetime]::new(1970, 1, 1)).TotalSeconds)
    [ordered] @{
        identifier        = $ReceiptId
        key               = $ReceiptId
        shortid           = $ReceiptId.Substring(0, [math]::Min(8, $ReceiptId.Length))
        state             = $State
        secret_identifier = $SecretId
        secret_shortid    = $SecretId.Substring(0, [math]::Min(8, $SecretId.Length))
        secret_ttl        = $Ttl
        receipt_ttl       = $Ttl * 2
        lifespan          = $Ttl
        created           = $now
        updated           = $now
        recipients        = ''
        share_domain      = $null
        memo              = $null
        has_passphrase    = $false
        is_viewed         = $false
        is_received       = $false
        is_burned         = ($State -eq 'burned')
        is_expired        = $false
        is_orphaned       = $false
        is_destroyed      = ($State -eq 'burned')
        kind              = 'conceal'
    }
}

function New-FakeSecretRecord {
    [CmdletBinding()]
    param(
        [string] $SecretId = 'sec2222222222222222222222',
        [string] $State = 'new',
        [string] $Value,
        [int] $Ttl = 3600
    )

    $record = [ordered] @{
        identifier     = $SecretId
        key            = $SecretId
        shortid        = $SecretId.Substring(0, [math]::Min(8, $SecretId.Length))
        state          = $State
        has_passphrase = $false
        display_type   = 'text'
        secret_ttl     = $Ttl
        lifespan       = $Ttl
        created        = [string] [long] [math]::Floor(((Get-Date).ToUniversalTime() - [datetime]::new(1970, 1, 1)).TotalSeconds)
        updated        = [string] [long] [math]::Floor(((Get-Date).ToUniversalTime() - [datetime]::new(1970, 1, 1)).TotalSeconds)
        is_viewed      = $false
        is_received    = $false
    }
    if ($PSBoundParameters.ContainsKey('Value')) { $record['secret_value'] = $Value }
    return $record
}

function New-FakeApiErrorRecord {
    <#
        Builds an ErrorRecord shaped like the ones Invoke-WebRequest throws,
        with a fake Response carrying the status code and the JSON body in
        ErrorDetails (the PowerShell 7 shape).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [int] $StatusCode,

        [Parameter()]
        [object] $Body,

        [Parameter()]
        [int] $RetryAfter
    )

    $headers = [PSCustomObject] @{ RetryAfter = $null }
    if ($RetryAfter -gt 0) {
        $headers = [PSCustomObject] @{ RetryAfter = [PSCustomObject] @{ Delta = [timespan]::FromSeconds($RetryAfter) } }
    }

    $exception = New-Object -TypeName System.Exception -ArgumentList ('Response status code does not indicate success: {0}' -f $StatusCode)
    $exception | Add-Member -MemberType NoteProperty -Name Response -Value ([PSCustomObject] @{ StatusCode = $StatusCode; Headers = $headers })

    $record = New-Object -TypeName System.Management.Automation.ErrorRecord -ArgumentList $exception, 'WebCmdletWebResponseException', 'InvalidOperation', $null
    if ($null -ne $Body) {
        $record.ErrorDetails = New-Object -TypeName System.Management.Automation.ErrorDetails -ArgumentList (ConvertTo-Json -InputObject $Body -Compress)
    }
    return $record
}

Export-ModuleMember -Function New-FakeHttpResponse, Get-SentJsonBody, New-FakeReceiptRecord, New-FakeSecretRecord, New-FakeApiErrorRecord
