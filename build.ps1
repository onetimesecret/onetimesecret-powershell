<#
.SYNOPSIS
    Bootstraps the build dependencies and runs an Invoke-Build task.

.DESCRIPTION
    Entry point for local development and CI. Installs the pinned build
    modules into the current user's scope when they are missing, then hands
    off to OnetimeSecret.build.ps1.

.PARAMETER Task
    One or more Invoke-Build tasks. Defaults to '.' (Analyze + Test).
    Run ./build.ps1 -Task ? to list them.

.PARAMETER Bootstrap
    Install missing build dependencies without running a task.

.PARAMETER Version
    Override the module version for Build, Package and Publish, e.g.
    0.2.0-preview1. Defaults to the manifest's ModuleVersion and Prerelease.

.EXAMPLE
    ./build.ps1
.EXAMPLE
    ./build.ps1 -Task Test
.EXAMPLE
    ./build.ps1 -Task Build, Docs
.EXAMPLE
    ./build.ps1 -Task Package -Version 0.2.0-preview1
#>
[CmdletBinding()]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingCmdletAliases', '', Justification = 'Invoke-Build is the documented entry point; the module exposes it as an alias of its script.')]
param(
    [Parameter(Position = 0)]
    [string[]] $Task = '.',

    [Parameter()]
    [switch] $Bootstrap,

    [Parameter()]
    [string] $Version
)

$ErrorActionPreference = 'Stop'

# Minimum versions of the tooling. Keep in sync with docs/releasing.md.
$requirements = @{
    InvokeBuild      = '5.11.0'
    Pester           = '5.5.0'
    PSScriptAnalyzer = '1.22.0'
    platyPS          = '0.14.2'
}

$missing = foreach ($name in $requirements.Keys) {
    $installed = Get-Module -ListAvailable -Name $name | Where-Object { $_.Version -ge [version] $requirements[$name] }
    if (-not $installed) { $name }
}

if ($missing) {
    Write-Host ('Installing build dependencies: {0}' -f ($missing -join ', '))
    if ((Get-PSRepository -Name PSGallery).InstallationPolicy -ne 'Trusted') {
        Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
    }
    foreach ($name in $missing) {
        $installParameters = @{
            Name           = $name
            MinimumVersion = $requirements[$name]
            Scope          = 'CurrentUser'
            Force          = $true
            AllowClobber   = $true
        }
        if ($name -eq 'Pester') {
            # Pester 6 changed its API; stay on the 5.x line until the tests are migrated.
            $installParameters['MaximumVersion'] = '5.99.99'
            $installParameters['SkipPublisherCheck'] = $true
        }
        Install-Module @installParameters
    }
}

if ($Bootstrap) { return }

Import-Module InvokeBuild -MinimumVersion $requirements.InvokeBuild

# Build script parameters are exposed by Invoke-Build as dynamic parameters.
$buildParameters = @{
    Task = $Task
    File = Join-Path $PSScriptRoot 'OnetimeSecret.build.ps1'
}
if ($PSBoundParameters.ContainsKey('Version')) { $buildParameters['Version'] = $Version }
Invoke-Build @buildParameters
