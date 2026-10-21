<#
    Module-level quality gates: the manifest is valid, the public surface
    matches the manifest, every public cmdlet has usable help, and
    PSScriptAnalyzer is clean. These run before the behavioural tests so a
    broken manifest fails fast.
#>

BeforeDiscovery {
    $script:RepoRoot = Split-Path -Parent $PSScriptRoot
    $script:ModulePath = Join-Path (Join-Path $RepoRoot 'src') 'OnetimeSecret'
    $script:ManifestPath = Join-Path $ModulePath 'OnetimeSecret.psd1'

    $script:PublicFunctions = @(Get-ChildItem -Path (Join-Path $ModulePath 'Public') -Filter '*.ps1' | ForEach-Object BaseName)
    $script:SourceFiles = @(
        Get-ChildItem -Path $ModulePath -Recurse -Include '*.ps1', '*.psm1', '*.psd1'
        Get-ChildItem -Path (Join-Path $RepoRoot 'tests') -Recurse -Filter '*.ps1'
        Get-ChildItem -Path $RepoRoot -Filter '*.ps1'
    ) | ForEach-Object { @{ Path = $_.FullName; Name = $_.Name } }
}

BeforeAll {
    $script:RepoRoot = Split-Path -Parent $PSScriptRoot
    $script:ModulePath = Join-Path (Join-Path $RepoRoot 'src') 'OnetimeSecret'
    $script:ManifestPath = Join-Path $ModulePath 'OnetimeSecret.psd1'

    Get-Module OnetimeSecret | Remove-Module -Force
    $script:Module = Import-Module $ManifestPath -Force -PassThru
}

Describe 'Module manifest' {
    It 'is valid' {
        { Test-ModuleManifest -Path $ManifestPath -ErrorAction Stop } | Should -Not -Throw
    }

    It 'has a semantic version' {
        $manifest = Test-ModuleManifest -Path $ManifestPath
        $manifest.Version.ToString() | Should -Match '^\d+\.\d+\.\d+$'
    }

    It 'exports exactly the functions in Public/' {
        $manifest = Test-ModuleManifest -Path $ManifestPath
        $exported = @($manifest.ExportedFunctions.Keys | Sort-Object)
        $expected = @($PublicFunctions | Sort-Object)
        $exported | Should -Be $expected
    }

    It 'declares both Desktop and Core editions' {
        $manifest = Test-ModuleManifest -Path $ManifestPath
        $manifest.CompatiblePSEditions | Should -Contain 'Desktop'
        $manifest.CompatiblePSEditions | Should -Contain 'Core'
    }

    It 'has gallery metadata' {
        $data = Import-PowerShellDataFile -Path $ManifestPath
        $data.PrivateData.PSData.ProjectUri | Should -Not -BeNullOrEmpty
        $data.PrivateData.PSData.LicenseUri | Should -Not -BeNullOrEmpty
        $data.PrivateData.PSData.Tags.Count | Should -BeGreaterThan 3
    }

    It 'loads the format file' {
        $Module.ExportedFormatFiles | Should -Not -BeNullOrEmpty
    }
}

Describe 'Public cmdlet <_>' -ForEach $PublicFunctions {
    BeforeAll {
        $script:Name = $_
        $script:Command = Get-Command -Name $Name -Module OnetimeSecret
        $script:Help = Get-Help -Name $Name -Full
    }

    It 'uses an approved verb' {
        $verb = $Name.Split('-')[0]
        (Get-Verb).Verb | Should -Contain $verb
    }

    It 'uses the Ots noun prefix' {
        $Name | Should -Match '^[A-Z][a-z]+-Ots[A-Z]'
    }

    It 'is an advanced function' {
        $Command.CmdletBinding | Should -BeTrue
    }

    It 'has a synopsis' {
        $Help.Synopsis | Should -Not -BeNullOrEmpty
        $Help.Synopsis | Should -Not -Match ('^\s*' + [regex]::Escape($Name))
    }

    It 'has a description' {
        $Help.Description | Should -Not -BeNullOrEmpty
    }

    It 'has at least one example' {
        $Help.Examples.example.Count | Should -BeGreaterOrEqual 1
    }

    It 'documents every parameter' {
        $common = [System.Management.Automation.PSCmdlet]::CommonParameters + [System.Management.Automation.PSCmdlet]::OptionalCommonParameters
        $parameters = $Command.Parameters.Keys | Where-Object { $_ -notin $common }
        foreach ($parameter in $parameters) {
            $doc = $Help.parameters.parameter | Where-Object Name -eq $parameter
            $doc.Description.Text | Should -Not -BeNullOrEmpty -Because "parameter -$parameter of $Name needs help text"
        }
    }

    It 'declares an output type' {
        $Command.OutputType.Count | Should -BeGreaterOrEqual 1
    }
}

Describe 'PSScriptAnalyzer' {
    BeforeAll {
        $settings = Join-Path (Split-Path -Parent $PSScriptRoot) 'PSScriptAnalyzerSettings.psd1'
        $targets = @(
            (Join-Path $RepoRoot 'src')
            (Join-Path $RepoRoot 'tests')
            (Join-Path $RepoRoot 'OnetimeSecret.build.ps1')
            (Join-Path $RepoRoot 'build.ps1')
        )
        $script:Results = @(foreach ($target in $targets) { Invoke-ScriptAnalyzer -Path $target -Recurse -Settings $settings })
    }

    It '<Name> has no findings' -ForEach $SourceFiles {
        $findings = @($Results | Where-Object ScriptPath -eq $Path)
        $findings | ForEach-Object { Write-Host ('  {0} {1}:{2} {3}' -f $_.Severity, $_.ScriptName, $_.Line, $_.Message) }
        $findings.Count | Should -Be 0
    }
}
