# Converters from raw API records to the typed objects the module emits.
# Each output object carries a PSTypeName so OnetimeSecret.Format.ps1xml can
# shape its default view, and keeps the untouched API record in
# RawResponse for anything the typed projection does not cover.

function ConvertFrom-OtsReceipt {
    <#
    .SYNOPSIS
        Projects a receipt record to an 'OnetimeSecret.Receipt' object.
    .PARAMETER Record
        The receipt record from the API (record, or record.receipt for create calls).
    .PARAMETER Details
        The optional details envelope that accompanies show/burn responses.
    .PARAMETER SecretRecord
        For create responses, the sibling secret record (supplies the generated value).
    .PARAMETER Connection
        Used to construct share/receipt/burn URLs when the API omits them.
    #>
    [CmdletBinding()]
    [OutputType('OnetimeSecret.Receipt')]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [object] $Record,

        [Parameter()]
        [AllowNull()]
        [object] $Details,

        [Parameter()]
        [AllowNull()]
        [object] $SecretRecord,

        [Parameter(Mandatory)]
        [PSTypeName('OnetimeSecret.Connection')]
        $Connection,

        [Parameter()]
        [AllowNull()]
        [string] $ShareDomain
    )

    if ($null -eq $Record) { return $null }

    $receiptId = [string] (Get-OtsProperty $Record 'identifier')
    $secretId  = [string] (Get-OtsProperty $Record 'secret_identifier')
    if (-not $secretId -and $null -ne $SecretRecord) {
        $secretId = [string] (Get-OtsProperty $SecretRecord 'identifier')
    }

    if (-not $ShareDomain) { $ShareDomain = [string] (Get-OtsProperty $Record 'share_domain') }

    $base = $Connection.ServerUri.AbsoluteUri.TrimEnd('/')
    $shareBase = $base
    if ($ShareDomain) {
        $shareBase = '{0}://{1}' -f $Connection.ServerUri.Scheme, $ShareDomain
    }

    # After a burn the server reports share_url with an empty identifier, so
    # only trust it when it still names the secret.
    $shareUrl = [string] (Get-OtsProperty $Record 'share_url')
    if ($secretId) {
        if (-not $shareUrl -or $shareUrl -notlike ('*' + $secretId)) { $shareUrl = '{0}/secret/{1}' -f $shareBase, $secretId }
    }
    else {
        $shareUrl = $null
    }

    $receiptUrl = [string] (Get-OtsProperty $Record 'receipt_url')
    if (-not $receiptUrl -and $receiptId) { $receiptUrl = '{0}/receipt/{1}' -f $base, $receiptId }

    $burnUrl = [string] (Get-OtsProperty $Record 'burn_url')
    if (-not $burnUrl -and $receiptId) { $burnUrl = '{0}/receipt/{1}/burn' -f $base, $receiptId }

    # The generated value is reported on the secret record at creation time and
    # under details.secret_value when a receipt is shown shortly afterwards.
    $value = $null
    if ($null -ne $SecretRecord) { $value = Get-OtsProperty $SecretRecord 'secret_value' }
    if ([string]::IsNullOrEmpty([string] $value) -and $null -ne $Details) { $value = Get-OtsProperty $Details 'secret_value' }
    if ([string]::IsNullOrEmpty([string] $value)) { $value = $null }

    $hasPassphrase = Get-OtsProperty $Record 'has_passphrase'
    if ($null -eq $hasPassphrase -and $null -ne $Details) { $hasPassphrase = Get-OtsProperty $Details 'has_passphrase' }

    $expiration = Get-OtsProperty $Record 'expiration'
    $expiresIn  = ConvertFrom-OtsDuration (Get-OtsProperty $Record 'expiration_in_seconds')
    $secretTtl  = ConvertFrom-OtsDuration (Get-OtsProperty $Record 'secret_ttl')
    $expires    = ConvertFrom-OtsTimestamp $expiration
    if ($null -eq $expires -and $null -ne $expiresIn) { $expires = (Get-Date).Add($expiresIn) }
    if ($null -eq $expires -and $null -ne $secretTtl) {
        $created = ConvertFrom-OtsTimestamp (Get-OtsProperty $Record 'created')
        if ($null -ne $created) { $expires = $created.Add($secretTtl) }
    }

    $viewCount = $null
    if ($null -ne $Details) { $viewCount = Get-OtsProperty $Details 'view_count' }

    [PSCustomObject] @{
        PSTypeName        = 'OnetimeSecret.Receipt'
        ReceiptId         = $receiptId
        SecretId          = $secretId
        State             = [string] (Get-OtsProperty $Record 'state')
        ShareUrl          = $shareUrl
        ReceiptUrl        = $receiptUrl
        BurnUrl           = $burnUrl
        ShareDomain       = $ShareDomain
        HasPassphrase     = ConvertTo-OtsBoolean $hasPassphrase
        Recipients        = ConvertTo-OtsStringArray (Get-OtsProperty $Record 'recipients')
        Memo              = [string] (Get-OtsProperty $Record 'memo')
        Kind              = [string] (Get-OtsProperty $Record 'kind')
        Value             = $value
        Created           = ConvertFrom-OtsTimestamp (Get-OtsProperty $Record 'created')
        Updated           = ConvertFrom-OtsTimestamp (Get-OtsProperty $Record 'updated')
        Expires           = $expires
        ExpiresIn         = $expiresIn
        SecretTtl         = $secretTtl
        ReceiptTtl        = ConvertFrom-OtsDuration (Get-OtsProperty $Record 'receipt_ttl')
        NaturalExpiration = [string] (Get-OtsProperty $Record 'natural_expiration')
        IsViewed          = ConvertTo-OtsBoolean (Get-OtsProperty $Record 'is_viewed')
        IsReceived        = ConvertTo-OtsBoolean (Get-OtsProperty $Record 'is_received')
        IsBurned          = ConvertTo-OtsBoolean (Get-OtsProperty $Record 'is_burned')
        IsExpired         = ConvertTo-OtsBoolean (Get-OtsProperty $Record 'is_expired')
        IsOrphaned        = ConvertTo-OtsBoolean (Get-OtsProperty $Record 'is_orphaned')
        IsDestroyed       = ConvertTo-OtsBoolean (Get-OtsProperty $Record 'is_destroyed')
        Received          = ConvertFrom-OtsTimestamp (Get-OtsProperty $Record 'received')
        Burned            = ConvertFrom-OtsTimestamp (Get-OtsProperty $Record 'burned')
        ViewCount         = $viewCount
        ShortId           = [string] (Get-OtsProperty $Record 'shortid')
        SecretShortId     = [string] (Get-OtsProperty $Record 'secret_shortid')
        ServerUri         = $Connection.ServerUri
        RawResponse       = $Record
    }
}

function ConvertFrom-OtsSecret {
    <#
    .SYNOPSIS
        Projects a secret record to an 'OnetimeSecret.Secret' object.
    #>
    [CmdletBinding()]
    [OutputType('OnetimeSecret.Secret')]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [object] $Record,

        [Parameter(Mandatory)]
        [PSTypeName('OnetimeSecret.Connection')]
        $Connection,

        [Parameter()]
        [switch] $AsSecureString
    )

    if ($null -eq $Record) { return $null }

    $value = Get-OtsProperty $Record 'secret_value'
    if ([string]::IsNullOrEmpty([string] $value)) {
        $value = $null
    }
    elseif ($AsSecureString) {
        $value = ConvertTo-OtsSecureString -Value ([string] $value)
    }

    $secretId = [string] (Get-OtsProperty $Record 'identifier')

    [PSCustomObject] @{
        PSTypeName    = 'OnetimeSecret.Secret'
        SecretId      = $secretId
        State         = [string] (Get-OtsProperty $Record 'state')
        Value         = $value
        HasPassphrase = ConvertTo-OtsBoolean (Get-OtsProperty $Record 'has_passphrase')
        DisplayType   = [string] (Get-OtsProperty $Record 'display_type' 'text')
        Ttl           = ConvertFrom-OtsDuration (Get-OtsProperty $Record 'secret_ttl')
        Lifespan      = [string] (Get-OtsProperty $Record 'lifespan')
        Created       = ConvertFrom-OtsTimestamp (Get-OtsProperty $Record 'created')
        Updated       = ConvertFrom-OtsTimestamp (Get-OtsProperty $Record 'updated')
        IsViewed      = ConvertTo-OtsBoolean (Get-OtsProperty $Record 'is_viewed')
        IsReceived    = ConvertTo-OtsBoolean (Get-OtsProperty $Record 'is_received')
        ShortId       = [string] (Get-OtsProperty $Record 'shortid')
        ShareUrl      = '{0}/secret/{1}' -f $Connection.ServerUri.AbsoluteUri.TrimEnd('/'), $secretId
        ServerUri     = $Connection.ServerUri
        RawResponse   = $Record
    }
}

function ConvertFrom-OtsSecretStatus {
    <#
    .SYNOPSIS
        Projects a status record to an 'OnetimeSecret.SecretStatus' object.
    #>
    [CmdletBinding()]
    [OutputType('OnetimeSecret.SecretStatus')]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [object] $Record,

        [Parameter()]
        [AllowNull()]
        [object] $Details,

        [Parameter()]
        [AllowEmptyString()]
        [string] $RequestedId,

        [Parameter(Mandatory)]
        [PSTypeName('OnetimeSecret.Connection')]
        $Connection
    )

    $state = [string] (Get-OtsProperty $Record 'state' 'unknown')
    $secretId = [string] (Get-OtsProperty $Record 'identifier')
    if (-not $secretId) { $secretId = $RequestedId }

    $currentExpiration = $null
    if ($null -ne $Details) { $currentExpiration = ConvertFrom-OtsTimestamp (Get-OtsProperty $Details 'current_expiration') }

    [PSCustomObject] @{
        PSTypeName    = 'OnetimeSecret.SecretStatus'
        SecretId      = $secretId
        State         = $state
        Exists        = ($state -ne 'unknown')
        HasPassphrase = ConvertTo-OtsBoolean (Get-OtsProperty $Record 'has_passphrase')
        Expires       = $currentExpiration
        Ttl           = ConvertFrom-OtsDuration (Get-OtsProperty $Record 'secret_ttl')
        Created       = ConvertFrom-OtsTimestamp (Get-OtsProperty $Record 'created')
        IsViewed      = ConvertTo-OtsBoolean (Get-OtsProperty $Record 'is_viewed')
        IsReceived    = ConvertTo-OtsBoolean (Get-OtsProperty $Record 'is_received')
        ServerUri     = $Connection.ServerUri
        RawResponse   = $Record
    }
}
