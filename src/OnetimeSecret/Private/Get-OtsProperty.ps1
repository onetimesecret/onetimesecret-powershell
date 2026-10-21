function Get-OtsProperty {
    <#
    .SYNOPSIS
        Reads a property from an API response object without tripping strict mode.
    .DESCRIPTION
        API payloads omit fields freely. This helper returns the property value
        when present (including an explicit null) and $Default otherwise, for
        both PSCustomObject (ConvertFrom-Json output) and hashtable input.
    #>
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Position = 0)]
        [AllowNull()]
        [object] $InputObject,

        [Parameter(Mandatory, Position = 1)]
        [string] $Name,

        [Parameter(Position = 2)]
        [AllowNull()]
        [object] $Default = $null
    )

    if ($null -eq $InputObject) {
        return $Default
    }

    if ($InputObject -is [System.Collections.IDictionary]) {
        if ($InputObject.Contains($Name)) {
            return $InputObject[$Name]
        }
        return $Default
    }

    $property = $InputObject.PSObject.Properties[$Name]
    if ($null -ne $property) {
        return $property.Value
    }

    return $Default
}
