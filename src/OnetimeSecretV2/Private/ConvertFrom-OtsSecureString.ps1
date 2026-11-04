function ConvertFrom-OtsSecureString {
    <#
    .SYNOPSIS
        Extracts the plain-text value of a SecureString.
    .DESCRIPTION
        Works on Windows PowerShell 5.1 and PowerShell 7 alike (the -AsPlainText
        switch of ConvertFrom-SecureString is 7.0+ only). The unmanaged copy is
        zeroed as soon as the managed string has been produced.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [securestring] $SecureString
    )

    $pointer = [System.IntPtr]::Zero
    try {
        $pointer = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString)
        return [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer)
    }
    finally {
        if ($pointer -ne [System.IntPtr]::Zero) {
            [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer)
        }
    }
}

function ConvertTo-OtsSecureString {
    <#
    .SYNOPSIS
        Wraps a plain string in a SecureString without the -Force dance.
    #>
    [CmdletBinding()]
    [OutputType([securestring])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [AllowEmptyString()]
        [string] $Value
    )

    $secure = New-Object -TypeName System.Security.SecureString
    foreach ($char in $Value.ToCharArray()) {
        $secure.AppendChar($char)
    }
    $secure.MakeReadOnly()
    return $secure
}
