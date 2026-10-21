function ConvertTo-OtsIdentifier {
    <#
    .SYNOPSIS
        Accepts a bare identifier or a share/receipt URL and returns the identifier.
    .DESCRIPTION
        People paste the link they were given at least as often as the key
        inside it, so every cmdlet that takes an identifier accepts
        "https://eu.onetimesecret.com/secret/abc123", "/secret/abc123" or
        plain "abc123". The identifier is the path segment after /secret/ or
        /receipt/ (and the legacy /private/ alias).
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string] $Value,

        [Parameter()]
        [ValidateSet('Secret', 'Receipt', 'Any')]
        [string] $Kind = 'Any'
    )

    $candidate = $Value.Trim()

    $segments = switch ($Kind) {
        'Secret' { 'secret' }
        'Receipt' { 'receipt|private|metadata' }
        default { 'secret|receipt|private|metadata' }
    }

    $pattern = '(?:^|/)(?:{0})/(?<id>[A-Za-z0-9_-]+)' -f $segments
    if ($candidate -match $pattern) {
        return $Matches['id']
    }

    if ($candidate -match '^[A-Za-z0-9_-]+$') {
        return $candidate
    }

    throw ("'{0}' is not a valid Onetime Secret identifier or link." -f $Value)
}
