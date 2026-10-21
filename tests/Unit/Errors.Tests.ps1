[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingConvertToSecureStringWithPlainText', '', Justification = 'Test fixtures use throwaway values.')]
param()

BeforeAll {
    $repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    Get-Module OnetimeSecret | Remove-Module -Force
    Import-Module (Join-Path (Join-Path (Join-Path $repoRoot 'src') 'OnetimeSecret') 'OnetimeSecret.psd1') -Force
    Import-Module (Join-Path $PSScriptRoot 'TestHelpers.psm1') -Force

    Connect-OtsAccount -ServerUri 'https://eu.onetimesecret.com' -Anonymous
}

AfterAll {
    Disconnect-OtsAccount -Confirm:$false
    Remove-Module TestHelpers -Force -ErrorAction SilentlyContinue
}

Describe 'API error handling' {
    It 'maps a 404 to ObjectNotFound with the server error type' {
        Mock -ModuleName OnetimeSecret Invoke-WebRequest {
            throw (New-FakeApiErrorRecord -StatusCode 404 -Body @{ error = 'Unknown secret'; error_type = 'RecordNotFound'; request_id = 'req-1' })
        }

        $failure = $null
        try { Get-OtsSecret -SecretId missing -ErrorAction Stop } catch { $failure = $_ }

        $failure | Should -Not -BeNullOrEmpty
        $failure.FullyQualifiedErrorId | Should -Match '^OnetimeSecret\.Api\.RecordNotFound'
        $failure.CategoryInfo.Category | Should -Be 'ObjectNotFound'
        $failure.Exception.Message | Should -Match '404 \(RecordNotFound\): Unknown secret'
        $failure.Exception.Message | Should -Match 'request_id: req-1'
        $failure.Exception.Data['StatusCode'] | Should -Be 404
        $failure.Exception.Data['ErrorType'] | Should -Be 'RecordNotFound'
        $failure.Exception.Data['RequestId'] | Should -Be 'req-1'
        $failure.Exception.Data['Uri'] | Should -Be 'https://eu.onetimesecret.com/api/v2/guest/secret/missing'
    }

    It 'maps a 401 to AuthenticationError with a recommended action' {
        Mock -ModuleName OnetimeSecret Invoke-WebRequest {
            throw (New-FakeApiErrorRecord -StatusCode 401 -Body @{ error = 'Authentication required'; error_type = 'Unauthorized' })
        }

        $failure = $null
        try { Get-OtsSecret -SecretId abc -ErrorAction Stop } catch { $failure = $_ }

        $failure.CategoryInfo.Category | Should -Be 'AuthenticationError'
        $failure.ErrorDetails.RecommendedAction | Should -Match 'extid'
    }

    It 'maps a 422 with a field to InvalidData' {
        Mock -ModuleName OnetimeSecret Invoke-WebRequest {
            throw (New-FakeApiErrorRecord -StatusCode 422 -Body @{ error = 'Incorrect payload format'; error_type = 'FormError'; field = 'ttl' })
        }

        $failure = $null
        try { New-OtsSecret -Secret 'x' -ErrorAction Stop } catch { $failure = $_ }

        $failure.CategoryInfo.Category | Should -Be 'InvalidData'
        $failure.Exception.Data['Field'] | Should -Be 'ttl'
        $failure.Exception.Message | Should -Match '\[field: ttl\]'
    }

    It 'treats requires_account form errors as authentication problems' {
        Mock -ModuleName OnetimeSecret Invoke-WebRequest {
            throw (New-FakeApiErrorRecord -StatusCode 400 -Body @{ error = 'An account is required'; field = 'requires_account' })
        }

        $failure = $null
        try { New-OtsSecret -Secret 'x' -ErrorAction Stop } catch { $failure = $_ }

        $failure.CategoryInfo.Category | Should -Be 'AuthenticationError'
        $failure.ErrorDetails.RecommendedAction | Should -Match 'Connect-OtsAccount'
    }

    It 'falls back to a status label when the body is not JSON' {
        Mock -ModuleName OnetimeSecret Invoke-WebRequest {
            $record = New-FakeApiErrorRecord -StatusCode 502
            $record.ErrorDetails = New-Object System.Management.Automation.ErrorDetails -ArgumentList '<html>Bad Gateway</html>'
            throw $record
        }

        $failure = $null
        try { Receive-OtsSecret -SecretId abc -ErrorAction Stop } catch { $failure = $_ }

        $failure.FullyQualifiedErrorId | Should -Match '^OnetimeSecret\.Api\.Http502'
        $failure.CategoryInfo.Category | Should -Be 'ResourceUnavailable'
    }

    It 'reports connection failures without a status code' {
        Mock -ModuleName OnetimeSecret Invoke-WebRequest { throw 'No such host is known' }

        $failure = $null
        try { Get-OtsStatus -ErrorAction Stop } catch { $failure = $_ }

        $failure.FullyQualifiedErrorId | Should -Match '^OnetimeSecret\.ConnectionError'
        $failure.CategoryInfo.Category | Should -Be 'ConnectionError'
        $failure.Exception.Data['StatusCode'] | Should -Be 0
        $failure.Exception.Message | Should -Match 'No such host'
    }

    It 'retries GETs on 429 and honours Retry-After, then succeeds' {
        Mock -ModuleName OnetimeSecret Start-Sleep { }
        $script:calls = 0
        Mock -ModuleName OnetimeSecret Invoke-WebRequest {
            $script:calls++
            if ($script:calls -eq 1) { throw (New-FakeApiErrorRecord -StatusCode 429 -Body @{ error = 'slow down' } -RetryAfter 7) }
            New-FakeHttpResponse -Body @{ record = (New-FakeSecretRecord) }
        }

        $secret = Get-OtsSecret -SecretId sec2222222222222222222222

        $secret.SecretId | Should -Be 'sec2222222222222222222222'
        Should -Invoke -ModuleName OnetimeSecret Invoke-WebRequest -Times 2 -Exactly
        Should -Invoke -ModuleName OnetimeSecret Start-Sleep -Times 1 -Exactly -ParameterFilter { $Seconds -eq 7 }
    }

    It 'does not retry POSTs' {
        Mock -ModuleName OnetimeSecret Start-Sleep { }
        Mock -ModuleName OnetimeSecret Invoke-WebRequest { throw (New-FakeApiErrorRecord -StatusCode 503 -Body @{ error = 'down' }) }

        { New-OtsSecret -Secret 'x' -ErrorAction Stop } | Should -Throw
        Should -Invoke -ModuleName OnetimeSecret Invoke-WebRequest -Times 1 -Exactly
        Should -Invoke -ModuleName OnetimeSecret Start-Sleep -Times 0
    }

    It 'gives up after the retry budget' {
        Mock -ModuleName OnetimeSecret Start-Sleep { }
        Mock -ModuleName OnetimeSecret Invoke-WebRequest { throw (New-FakeApiErrorRecord -StatusCode 503 -Body @{ error = 'down' }) }

        { Get-OtsSecret -SecretId abc -ErrorAction Stop } | Should -Throw
        Should -Invoke -ModuleName OnetimeSecret Invoke-WebRequest -Times 3 -Exactly
    }

    It 'writes non-terminating errors per item so a batch continues' {
        $script:n = 0
        Mock -ModuleName OnetimeSecret Invoke-WebRequest {
            $script:n++
            if ($script:n -eq 1) { throw (New-FakeApiErrorRecord -StatusCode 404 -Body @{ error = 'gone'; error_type = 'RecordNotFound' }) }
            New-FakeHttpResponse -Body @{ record = (New-FakeSecretRecord -SecretId 'secOK') }
        }

        $errors = @()
        $results = @(Get-OtsSecret -SecretId 'secGONE', 'secOK' -ErrorAction SilentlyContinue -ErrorVariable errors)

        $results.Count | Should -Be 1
        $results[0].SecretId | Should -Be 'secOK'
        # -ErrorVariable also records the internal exceptions that were caught
        # and translated, so look for the one the cmdlet actually surfaced.
        @($errors | Where-Object { $_.FullyQualifiedErrorId -like 'OnetimeSecret.Api.RecordNotFound*' }).Count | Should -BeGreaterOrEqual 1
    }
}

Describe 'Identifier parsing' {
    It 'extracts <Expected> from <Value>' -ForEach @(
        @{ Value = 'abc123'; Expected = 'abc123' }
        @{ Value = 'https://eu.onetimesecret.com/secret/abc123'; Expected = 'abc123' }
        @{ Value = 'https://eu.onetimesecret.com/secret/abc123#hash'; Expected = 'abc123' }
        @{ Value = 'https://secrets.example.com/receipt/rcp999'; Expected = 'rcp999' }
        @{ Value = 'https://eu.onetimesecret.com/private/rcp999'; Expected = 'rcp999' }
        @{ Value = '/secret/abc123'; Expected = 'abc123' }
        @{ Value = '  abc123  '; Expected = 'abc123' }
    ) {
        InModuleScope OnetimeSecret -Parameters @{ Value = $Value } {
            ConvertTo-OtsIdentifier -Value $Value
        } | Should -Be $Expected
    }

    It 'rejects values that are neither identifiers nor links' {
        InModuleScope OnetimeSecret {
            { ConvertTo-OtsIdentifier -Value 'not valid!' } | Should -Throw -ExpectedMessage '*not a valid*'
        }
    }

    It 'does not accept a secret link where a receipt is required' {
        InModuleScope OnetimeSecret {
            { ConvertTo-OtsIdentifier -Value 'https://eu.onetimesecret.com/secret/abc123' -Kind Receipt } | Should -Throw
        }
    }
}

Describe 'Value coercion' {
    It 'converts epoch numbers, epoch strings and ISO strings to local DateTime' {
        InModuleScope OnetimeSecret {
            (ConvertFrom-OtsTimestamp 1792538905.4784453).ToUniversalTime().Year | Should -Be 2026
            (ConvertFrom-OtsTimestamp '1792538905').ToUniversalTime().Year | Should -Be 2026
            (ConvertFrom-OtsTimestamp '2026-10-20T14:00:00Z').ToUniversalTime().Hour | Should -Be 14
            ConvertFrom-OtsTimestamp $null | Should -BeNullOrEmpty
            ConvertFrom-OtsTimestamp '' | Should -BeNullOrEmpty
            ConvertFrom-OtsTimestamp 0 | Should -BeNullOrEmpty
        }
    }

    It 'converts seconds to TimeSpan' {
        InModuleScope OnetimeSecret {
            ConvertFrom-OtsDuration 300 | Should -Be ([timespan]::FromMinutes(5))
            ConvertFrom-OtsDuration '300' | Should -Be ([timespan]::FromMinutes(5))
            ConvertFrom-OtsDuration $null | Should -BeNullOrEmpty
        }
    }

    It 'normalises booleans' {
        InModuleScope OnetimeSecret {
            ConvertTo-OtsBoolean $true | Should -BeTrue
            ConvertTo-OtsBoolean 'true' | Should -BeTrue
            ConvertTo-OtsBoolean '1' | Should -BeTrue
            ConvertTo-OtsBoolean 'false' | Should -BeFalse
            ConvertTo-OtsBoolean '0' | Should -BeFalse
            ConvertTo-OtsBoolean '' | Should -BeFalse
            ConvertTo-OtsBoolean $null | Should -BeFalse
        }
    }

    It 'normalises recipients' {
        InModuleScope OnetimeSecret {
            @(ConvertTo-OtsStringArray '') | Should -HaveCount 0
            @(ConvertTo-OtsStringArray 'a@x.com, b@x.com') | Should -Be @('a@x.com', 'b@x.com')
            @(ConvertTo-OtsStringArray @('a@x.com')) | Should -Be @('a@x.com')
        }
    }
}
