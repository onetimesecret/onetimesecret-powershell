# Small coercion helpers for the loosely typed values the API returns.
# Timestamps arrive as epoch numbers, epoch strings or ISO-8601 strings;
# booleans arrive as true/false, "true"/"false" or null; durations arrive
# as seconds in either numeric or string form.

function ConvertFrom-OtsTimestamp {
    <#
    .SYNOPSIS
        Converts an API timestamp (epoch seconds or ISO-8601) to a local DateTime.
    #>
    [CmdletBinding()]
    [OutputType([datetime])]
    param(
        [Parameter(Position = 0)]
        [AllowNull()]
        [object] $Value
    )

    if ($null -eq $Value) { return $null }

    $text = ([string] $Value).Trim()
    if ($text.Length -eq 0) { return $null }

    $seconds = 0.0
    $isNumber = [double]::TryParse(
        $text,
        [System.Globalization.NumberStyles]::Float,
        [System.Globalization.CultureInfo]::InvariantCulture,
        [ref] $seconds)

    if ($isNumber) {
        if ($seconds -le 0) { return $null }
        $epoch = New-Object -TypeName System.DateTime -ArgumentList 1970, 1, 1, 0, 0, 0, ([System.DateTimeKind]::Utc)
        return $epoch.AddSeconds($seconds).ToLocalTime()
    }

    $parsed = [datetime]::MinValue
    $styles = [System.Globalization.DateTimeStyles]::AssumeUniversal -bor [System.Globalization.DateTimeStyles]::AdjustToUniversal
    if ([datetime]::TryParse($text, [System.Globalization.CultureInfo]::InvariantCulture, $styles, [ref] $parsed)) {
        return [datetime]::SpecifyKind($parsed, [System.DateTimeKind]::Utc).ToLocalTime()
    }

    return $null
}

function ConvertFrom-OtsDuration {
    <#
    .SYNOPSIS
        Converts a duration in seconds (number or numeric string) to a TimeSpan.
    #>
    [CmdletBinding()]
    [OutputType([timespan])]
    param(
        [Parameter(Position = 0)]
        [AllowNull()]
        [object] $Value
    )

    if ($null -eq $Value) { return $null }

    $seconds = 0.0
    $text = ([string] $Value).Trim()
    if ($text.Length -eq 0) { return $null }

    if ([double]::TryParse($text, [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, [ref] $seconds)) {
        return [timespan]::FromSeconds($seconds)
    }

    return $null
}

function ConvertTo-OtsBoolean {
    <#
    .SYNOPSIS
        Normalises the API's mixed boolean representations to [bool].
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Position = 0)]
        [AllowNull()]
        [object] $Value
    )

    if ($null -eq $Value) { return $false }
    if ($Value -is [bool]) { return $Value }

    $text = ([string] $Value).Trim().ToLowerInvariant()
    switch ($text) {
        '' { return $false }
        'false' { return $false }
        '0' { return $false }
        'no' { return $false }
        'true' { return $true }
        '1' { return $true }
        'yes' { return $true }
    }

    # Anything else non-empty (for example a timestamp recorded when an event
    # happened) counts as "it happened".
    return $true
}

function ConvertTo-OtsStringArray {
    <#
    .SYNOPSIS
        Normalises a scalar-or-array API value to a string array.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Position = 0)]
        [AllowNull()]
        [object] $Value
    )

    if ($null -eq $Value) { return @() }

    if ($Value -is [string]) {
        if ($Value.Trim().Length -eq 0) { return @() }
        return @($Value.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    }

    return @($Value | ForEach-Object { [string] $_ } | Where-Object { $_ })
}
