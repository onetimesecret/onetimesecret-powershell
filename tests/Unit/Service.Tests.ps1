[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingConvertToSecureStringWithPlainText', '', Justification = 'Test fixtures use throwaway values.')]
param()

BeforeAll {
    $repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    Get-Module OnetimeSecret | Remove-Module -Force
    Import-Module (Join-Path (Join-Path (Join-Path $repoRoot 'src') 'OnetimeSecret') 'OnetimeSecret.psd1') -Force
    Import-Module (Join-Path $PSScriptRoot 'TestHelpers.psm1') -Force

    $token = ConvertTo-SecureString -String 'tok_test' -AsPlainText -Force
    $credential = New-Object System.Management.Automation.PSCredential -ArgumentList 'ur1abc23def', $token
    $script:Anonymous = Connect-OtsAccount -ServerUri 'https://eu.onetimesecret.com' -Anonymous -PassThru
    Connect-OtsAccount -ServerUri 'https://eu.onetimesecret.com' -Credential $credential
}

AfterAll {
    Disconnect-OtsAccount -Confirm:$false
    Remove-Module TestHelpers -Force -ErrorAction SilentlyContinue
}

Describe 'Get-OtsStatus' {
    It 'reads the public status endpoint' {
        Mock -ModuleName OnetimeSecret Invoke-WebRequest { New-FakeHttpResponse -Body @{ success = $true; status = 'nominal'; locale = 'en' } }

        $status = Get-OtsStatus

        Should -Invoke -ModuleName OnetimeSecret Invoke-WebRequest -Times 1 -Exactly -ParameterFilter {
            $Uri -eq 'https://eu.onetimesecret.com/api/v2/status' -and $Method -eq 'GET'
        }
        $status.PSObject.TypeNames | Should -Contain 'OnetimeSecret.ServiceStatus'
        $status.IsHealthy | Should -BeTrue
        $status.Status | Should -Be 'nominal'
    }

    It 'checks several servers from the pipeline without a connection' {
        Mock -ModuleName OnetimeSecret Invoke-WebRequest { New-FakeHttpResponse -Body @{ success = $true; status = 'nominal'; locale = 'en' } }

        $results = @('https://us.onetimesecret.com', 'https://eu.onetimesecret.com' | Get-OtsStatus)

        $results.Count | Should -Be 2
        $results[0].ServerUri.Host | Should -Be 'us.onetimesecret.com'
        Should -Invoke -ModuleName OnetimeSecret Invoke-WebRequest -Times 1 -Exactly -ParameterFilter { -not $Headers.ContainsKey('Authorization') -and $Uri -like 'https://us.*' }
    }
}

Describe 'Get-OtsVersion' {
    It 'reads the version endpoint with Basic auth and projects a [version]' {
        Mock -ModuleName OnetimeSecret Invoke-WebRequest { New-FakeHttpResponse -Body @{ success = $true; version = @(0, 26, 5); locale = 'en' } }

        $result = Get-OtsVersion

        Should -Invoke -ModuleName OnetimeSecret Invoke-WebRequest -Times 1 -Exactly -ParameterFilter {
            $Uri -eq 'https://eu.onetimesecret.com/api/v2/version' -and
            $Method -eq 'GET' -and
            $Headers['Authorization'] -like 'Basic *'
        }
        $result.PSObject.TypeNames | Should -Contain 'OnetimeSecret.ServiceVersion'
        $result.Version | Should -Be ([version] '0.26.5')
        $result.VersionString | Should -Be '0.26.5'
        @($result.VersionComponents) | Should -Be @('0', '26', '5')
        $result.Locale | Should -Be 'en'
        $result.ServerUri.Host | Should -Be 'eu.onetimesecret.com'
    }

    It 'keeps a prerelease component in the string but out of the [version]' {
        Mock -ModuleName OnetimeSecret Invoke-WebRequest { New-FakeHttpResponse -Body @{ success = $true; version = @(1, 0, 0, 'rc1'); locale = 'en' } }

        $result = Get-OtsVersion

        $result.Version | Should -Be ([version] '1.0.0')
        $result.VersionString | Should -Be '1.0.0.rc1'
    }

    It 'surfaces the 401 the server returns to anonymous callers as an AuthenticationError' {
        Mock -ModuleName OnetimeSecret Invoke-WebRequest {
            New-FakeHttpResponse -StatusCode 401 -Body @{ error = 'Authentication Required'; message = '[AUTH_HEADER_MISSING] No authorization header' }
        }

        $failure = $null
        try { Get-OtsVersion -Connection $Anonymous -ErrorAction Stop } catch { $failure = $_ }

        $failure | Should -Not -BeNullOrEmpty
        $failure.CategoryInfo.Category | Should -Be 'AuthenticationError'
        $failure.Exception.Data['StatusCode'] | Should -Be 401
        $failure.Exception.Message | Should -Match 'Authentication Required'
        $failure.ErrorDetails.RecommendedAction | Should -Match 'Connect-OtsAccount'
    }
}

Describe 'Get-OtsSupportedLocale' {
    BeforeEach {
        Mock -ModuleName OnetimeSecret Invoke-WebRequest {
            New-FakeHttpResponse -Body @{ success = $true; locales = @('de', 'en', 'fr_FR'); default_locale = 'en'; locale = 'en' }
        }
    }

    It 'reads the supported-locales endpoint' {
        $result = Get-OtsSupportedLocale

        Should -Invoke -ModuleName OnetimeSecret Invoke-WebRequest -Times 1 -Exactly -ParameterFilter {
            $Uri -eq 'https://eu.onetimesecret.com/api/v2/supported-locales' -and $Method -eq 'GET'
        }
        $result.PSObject.TypeNames | Should -Contain 'OnetimeSecret.SupportedLocales'
        @($result.Locales) | Should -Be @('de', 'en', 'fr_FR')
        $result.DefaultLocale | Should -Be 'en'
        $result.Locale | Should -Be 'en'
    }

    It 'queries a server without connecting first and sends no credentials' {
        $result = Get-OtsSupportedLocale -ServerUri 'https://us.onetimesecret.com'

        $result.ServerUri.Host | Should -Be 'us.onetimesecret.com'
        Should -Invoke -ModuleName OnetimeSecret Invoke-WebRequest -Times 1 -Exactly -ParameterFilter {
            $Uri -eq 'https://us.onetimesecret.com/api/v2/supported-locales' -and -not $Headers.ContainsKey('Authorization')
        }
    }

    It 'returns an empty list when the server reports none' {
        Mock -ModuleName OnetimeSecret Invoke-WebRequest { New-FakeHttpResponse -Body @{ success = $true; locales = @(); default_locale = 'en'; locale = 'en' } }

        $result = Get-OtsSupportedLocale
        @($result.Locales).Count | Should -Be 0
    }
}
