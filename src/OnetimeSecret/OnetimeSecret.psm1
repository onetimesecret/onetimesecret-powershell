#Requires -Version 5.1
<#
    OnetimeSecret module loader (development layout).

    During development the module is loaded straight from src/ and this file
    dot-sources every function in Private/ and Public/. The release build
    (see OnetimeSecret.build.ps1) concatenates those same files into a single
    psm1 so the published module has no runtime file discovery to do.
#>

Set-StrictMode -Version Latest

$script:ModuleRoot        = $PSScriptRoot
$script:ModuleVersion     = [string] (Import-PowerShellDataFile -Path (Join-Path $PSScriptRoot 'OnetimeSecret.psd1')).ModuleVersion
$script:DefaultConnection = $null

# Windows PowerShell 5.1 inherits the .NET Framework default protocol list,
# which on older Windows builds still excludes TLS 1.2. Opt in without
# removing anything the host already allows.
if ($PSVersionTable.PSEdition -ne 'Core') {
    try {
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12
    }
    catch {
        Write-Verbose ('Could not enable TLS 1.2: {0}' -f $_.Exception.Message)
    }
}

$private = @(Get-ChildItem -Path (Join-Path $PSScriptRoot 'Private') -Filter '*.ps1' -ErrorAction SilentlyContinue)
$public  = @(Get-ChildItem -Path (Join-Path $PSScriptRoot 'Public')  -Filter '*.ps1' -ErrorAction SilentlyContinue)

foreach ($file in ($private + $public)) {
    try {
        . $file.FullName
    }
    catch {
        throw "Failed to load $($file.FullName): $($_.Exception.Message)"
    }
}

Export-ModuleMember -Function $public.BaseName
