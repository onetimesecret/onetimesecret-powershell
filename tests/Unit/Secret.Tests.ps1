[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingConvertToSecureStringWithPlainText', '', Justification = 'Test fixtures use throwaway values.')]
param()

BeforeAll {
    $repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    Get-Module OnetimeSecret | Remove-Module -Force
    Import-Module (Join-Path (Join-Path (Join-Path $repoRoot 'src') 'OnetimeSecret') 'OnetimeSecret.psd1') -Force
    Import-Module (Join-Path $PSScriptRoot 'TestHelpers.psm1') -Force

    $token = ConvertTo-SecureString -String 'tok_test' -AsPlainText -Force
    $credential = New-Object System.Management.Automation.PSCredential -ArgumentList 'ur1abc23def', $token
    Connect-OtsAccount -ServerUri 'https://eu.onetimesecret.com' -Credential $credential
    $script:Anonymous = Connect-OtsAccount -ServerUri 'https://eu.onetimesecret.com' -Anonymous -PassThru
    Connect-OtsAccount -ServerUri 'https://eu.onetimesecret.com' -Credential $credential

    $script:ConcealResponse = @{
        success = $true
        record  = @{
            receipt      = New-FakeReceiptRecord
            secret       = New-FakeSecretRecord
            share_domain = $null
        }
        details = @{ kind = 'conceal' }
    }
}

AfterAll {
    Disconnect-OtsAccount -Confirm:$false
    Remove-Module TestHelpers -Force -ErrorAction SilentlyContinue
}

Describe 'New-OtsSecret' {
    BeforeEach {
        Mock -ModuleName OnetimeSecret Invoke-WebRequest { New-FakeHttpResponse -Body $ConcealResponse }
    }

    It 'posts the secret under the v2 envelope with Basic auth' {
        $result = New-OtsSecret -Secret 'hunter2'

        Should -Invoke -ModuleName OnetimeSecret Invoke-WebRequest -Times 1 -Exactly -ParameterFilter {
            $Uri -eq 'https://eu.onetimesecret.com/api/v2/secret/conceal' -and
            $Method -eq 'POST' -and
            $Headers['Authorization'] -eq ('Basic ' + [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes('ur1abc23def:tok_test'))) -and
            $Headers['X-Onetime-Client'] -like 'powershell:*' -and
            $ContentType -like 'application/json*' -and
            (Get-SentJsonBody $Body).secret.kind -eq 'conceal' -and
            (Get-SentJsonBody $Body).secret.secret -eq 'hunter2'
        }

        $result.PSObject.TypeNames | Should -Contain 'OnetimeSecret.Receipt'
        $result.ReceiptId | Should -Be 'rcp1111111111111111111111'
        $result.SecretId | Should -Be 'sec2222222222222222222222'
        $result.ShareUrl | Should -Be 'https://eu.onetimesecret.com/secret/sec2222222222222222222222'
        $result.ReceiptUrl | Should -Be 'https://eu.onetimesecret.com/receipt/rcp1111111111111111111111'
        $result.BurnUrl | Should -Be 'https://eu.onetimesecret.com/receipt/rcp1111111111111111111111/burn'
        $result.State | Should -Be 'new'
        $result.HasPassphrase | Should -BeFalse
        $result.SecretTtl | Should -Be ([timespan]::FromHours(1))
        $result.Created | Should -BeOfType [datetime]
        $result.Expires | Should -BeOfType [datetime]
    }

    It 'uses the guest endpoint and no Authorization header on anonymous connections' {
        New-OtsSecret -Secret 'hunter2' -Connection $Anonymous | Out-Null

        Should -Invoke -ModuleName OnetimeSecret Invoke-WebRequest -Times 1 -Exactly -ParameterFilter {
            $Uri -eq 'https://eu.onetimesecret.com/api/v2/guest/secret/conceal' -and
            -not $Headers.ContainsKey('Authorization')
        }
    }

    It 'sends optional fields only when supplied' {
        $pass = ConvertTo-SecureString -String 'pw12' -AsPlainText -Force
        New-OtsSecret -Secret 'x' -Passphrase $pass -Ttl (New-TimeSpan -Minutes 90) -Recipient 'a@example.com', 'b@example.com' -ShareDomain 'secrets.example.com' -DisplayType markdown | Out-Null

        Should -Invoke -ModuleName OnetimeSecret Invoke-WebRequest -Times 1 -Exactly -ParameterFilter {
            $sent = (Get-SentJsonBody $Body).secret
            $sent.passphrase -eq 'pw12' -and
            $sent.ttl -eq 5400 -and
            @($sent.recipient).Count -eq 2 -and
            $sent.share_domain -eq 'secrets.example.com' -and
            $sent.display_type -eq 'markdown'
        }
    }

    It 'omits optional fields by default' {
        New-OtsSecret -Secret 'x' | Out-Null

        Should -Invoke -ModuleName OnetimeSecret Invoke-WebRequest -Times 1 -Exactly -ParameterFilter {
            $sent = (Get-SentJsonBody $Body).secret
            $names = @($sent.PSObject.Properties.Name)
            ($names -notcontains 'passphrase') -and ($names -notcontains 'ttl') -and
            ($names -notcontains 'recipient') -and ($names -notcontains 'share_domain') -and
            ($names -notcontains 'display_type')
        }
    }

    It 'accepts a SecureString secret' {
        $secure = ConvertTo-SecureString -String 'from-secure' -AsPlainText -Force
        New-OtsSecret -SecureSecret $secure | Out-Null

        Should -Invoke -ModuleName OnetimeSecret Invoke-WebRequest -Times 1 -Exactly -ParameterFilter {
            (Get-SentJsonBody $Body).secret.secret -eq 'from-secure'
        }
    }

    It 'accepts the secret from the pipeline' {
        'piped' | New-OtsSecret | Out-Null

        Should -Invoke -ModuleName OnetimeSecret Invoke-WebRequest -Times 1 -Exactly -ParameterFilter {
            (Get-SentJsonBody $Body).secret.secret -eq 'piped'
        }
    }

    It 'rejects a sub-second Ttl (the integer-as-ticks footgun)' {
        { New-OtsSecret -Secret 'x' -Ttl 3600 } | Should -Throw -ExpectedMessage '*at least one second*'
        Should -Invoke -ModuleName OnetimeSecret Invoke-WebRequest -Times 0
    }

    It 'generates with length and character sets, then reads the value back from the receipt' {
        $generated = @{
            success = $true
            record  = @{
                receipt      = New-FakeReceiptRecord
                secret       = New-FakeSecretRecord
                share_domain = $null
            }
        }
        $shown = @{
            record  = New-FakeReceiptRecord
            details = @{ type = 'record'; can_decrypt = $true; secret_value = 'Abc123XYZ' }
        }
        Mock -ModuleName OnetimeSecret Invoke-WebRequest { New-FakeHttpResponse -Body $generated } -ParameterFilter { $Method -eq 'POST' }
        Mock -ModuleName OnetimeSecret Invoke-WebRequest { New-FakeHttpResponse -Body $shown } -ParameterFilter { $Method -eq 'GET' }

        $result = New-OtsSecret -Generate -Length 24 -CharacterSet Uppercase, Numbers -ExcludeAmbiguous

        Should -Invoke -ModuleName OnetimeSecret Invoke-WebRequest -Times 1 -Exactly -ParameterFilter {
            $Method -eq 'GET' -and $Uri -eq 'https://eu.onetimesecret.com/api/v2/receipt/rcp1111111111111111111111'
        }
        Should -Invoke -ModuleName OnetimeSecret Invoke-WebRequest -Times 1 -Exactly -ParameterFilter {
            $sent = (Get-SentJsonBody $Body).secret
            $Uri -eq 'https://eu.onetimesecret.com/api/v2/secret/generate' -and
            $sent.kind -eq 'generate' -and
            $sent.length -eq 24 -and
            $sent.character_sets.uppercase -eq $true -and
            $sent.character_sets.lowercase -eq $false -and
            $sent.character_sets.numbers -eq $true -and
            $sent.character_sets.symbols -eq $false -and
            $sent.character_sets.exclude_ambiguous -eq $true
        }

        $result.Value | Should -Be 'Abc123XYZ'
        $result.ReceiptId | Should -Be 'rcp1111111111111111111111'
    }

    It 'warns but still returns the receipt when the generated value cannot be read back' {
        $generated = @{
            success = $true
            record  = @{ receipt = New-FakeReceiptRecord; secret = New-FakeSecretRecord; share_domain = $null }
        }
        Mock -ModuleName OnetimeSecret Invoke-WebRequest { New-FakeHttpResponse -Body $generated } -ParameterFilter { $Method -eq 'POST' }
        Mock -ModuleName OnetimeSecret Invoke-WebRequest { throw (New-FakeApiErrorRecord -StatusCode 503 -Body @{ error = 'busy' }) } -ParameterFilter { $Method -eq 'GET' }
        Mock -ModuleName OnetimeSecret Start-Sleep { }

        $result = New-OtsSecret -Generate -WarningVariable warnings -WarningAction SilentlyContinue

        $result.ReceiptId | Should -Be 'rcp1111111111111111111111'
        $result.Value | Should -BeNullOrEmpty
        $warnings | Should -Not -BeNullOrEmpty
    }

    It 'builds the share link on the custom domain when one is returned' {
        $withDomain = @{
            success = $true
            record  = @{
                receipt      = New-FakeReceiptRecord
                secret       = New-FakeSecretRecord
                share_domain = 'secrets.example.com'
            }
        }
        Mock -ModuleName OnetimeSecret Invoke-WebRequest { New-FakeHttpResponse -Body $withDomain }

        (New-OtsSecret -Secret 'x').ShareUrl | Should -Be 'https://secrets.example.com/secret/sec2222222222222222222222'
    }

    It 'honours -WhatIf' {
        New-OtsSecret -Secret 'x' -WhatIf
        Should -Invoke -ModuleName OnetimeSecret Invoke-WebRequest -Times 0
    }
}

Describe 'Get-OtsSecret' {
    BeforeEach {
        Mock -ModuleName OnetimeSecret Invoke-WebRequest {
            New-FakeHttpResponse -Body @{ record = (New-FakeSecretRecord -State 'previewed'); details = @{ show_secret = $false } }
        }
    }

    It 'requests metadata by identifier' {
        $secret = Get-OtsSecret -SecretId sec2222222222222222222222

        Should -Invoke -ModuleName OnetimeSecret Invoke-WebRequest -Times 1 -Exactly -ParameterFilter {
            $Uri -eq 'https://eu.onetimesecret.com/api/v2/secret/sec2222222222222222222222' -and $Method -eq 'GET'
        }
        $secret.PSObject.TypeNames | Should -Contain 'OnetimeSecret.Secret'
        $secret.State | Should -Be 'previewed'
        $secret.Value | Should -BeNullOrEmpty
        $secret.Ttl | Should -Be ([timespan]::FromHours(1))
    }

    It 'accepts a share link' {
        Get-OtsSecret 'https://eu.onetimesecret.com/secret/sec2222222222222222222222' | Out-Null

        Should -Invoke -ModuleName OnetimeSecret Invoke-WebRequest -Times 1 -Exactly -ParameterFilter {
            $Uri -eq 'https://eu.onetimesecret.com/api/v2/secret/sec2222222222222222222222'
        }
    }

    It 'binds SecretId from a receipt on the pipeline' {
        $receipt = [PSCustomObject] @{ PSTypeName = 'OnetimeSecret.Receipt'; ReceiptId = 'rcp1'; SecretId = 'secFromPipe' }
        $receipt | Get-OtsSecret | Out-Null

        Should -Invoke -ModuleName OnetimeSecret Invoke-WebRequest -Times 1 -Exactly -ParameterFilter {
            $Uri -like '*/api/v2/secret/secFromPipe'
        }
    }
}

Describe 'Get-OtsSecretStatus' {
    It 'uses the single-status endpoint for one identifier' {
        Mock -ModuleName OnetimeSecret Invoke-WebRequest {
            New-FakeHttpResponse -Body @{ record = (New-FakeSecretRecord); details = @{ current_expiration = 1900000000 } }
        }

        $status = Get-OtsSecretStatus -SecretId sec2222222222222222222222

        Should -Invoke -ModuleName OnetimeSecret Invoke-WebRequest -Times 1 -Exactly -ParameterFilter {
            $Uri -eq 'https://eu.onetimesecret.com/api/v2/secret/sec2222222222222222222222/status' -and $Method -eq 'GET'
        }
        $status.PSObject.TypeNames | Should -Contain 'OnetimeSecret.SecretStatus'
        $status.Exists | Should -BeTrue
        $status.State | Should -Be 'new'
        $status.Expires | Should -BeOfType [datetime]
    }

    It 'reports unknown secrets without erroring' {
        Mock -ModuleName OnetimeSecret Invoke-WebRequest { New-FakeHttpResponse -Body @{ record = @{ state = 'unknown' } } }

        $status = Get-OtsSecretStatus -SecretId nope
        $status.Exists | Should -BeFalse
        $status.State | Should -Be 'unknown'
        $status.SecretId | Should -Be 'nope'
    }

    It 'batches several identifiers into one POST and preserves order' {
        Mock -ModuleName OnetimeSecret Invoke-WebRequest {
            New-FakeHttpResponse -Body @{
                records = @(
                    (New-FakeSecretRecord -SecretId 'bbbbbbbbbb' -State 'received')
                    (New-FakeSecretRecord -SecretId 'aaaaaaaaaa')
                )
                count   = 2
            }
        }

        $statuses = @('aaaaaaaaaa', 'bbbbbbbbbb', 'cccccccccc' | Get-OtsSecretStatus)

        Should -Invoke -ModuleName OnetimeSecret Invoke-WebRequest -Times 1 -Exactly -ParameterFilter {
            $Uri -eq 'https://eu.onetimesecret.com/api/v2/secret/status' -and
            $Method -eq 'POST' -and
            @((Get-SentJsonBody $Body).identifiers).Count -eq 3
        }
        $statuses.Count | Should -Be 3
        $statuses[0].SecretId | Should -Be 'aaaaaaaaaa'
        $statuses[0].State | Should -Be 'new'
        $statuses[1].State | Should -Be 'received'
        $statuses[2].Exists | Should -BeFalse
    }
}

Describe 'Receive-OtsSecret' {
    BeforeEach {
        Mock -ModuleName OnetimeSecret Invoke-WebRequest {
            New-FakeHttpResponse -Body @{ record = (New-FakeSecretRecord -State 'revealed' -Value 'hunter2'); details = @{ show_secret = $true } }
        }
    }

    It 'posts continue=true and returns the value' {
        $secret = Receive-OtsSecret -SecretId sec2222222222222222222222

        Should -Invoke -ModuleName OnetimeSecret Invoke-WebRequest -Times 1 -Exactly -ParameterFilter {
            $Uri -eq 'https://eu.onetimesecret.com/api/v2/secret/sec2222222222222222222222/reveal' -and
            $Method -eq 'POST' -and
            (Get-SentJsonBody $Body).continue -eq $true
        }
        $secret.Value | Should -Be 'hunter2'
        $secret.State | Should -Be 'revealed'
    }

    It 'sends the passphrase' {
        $pass = ConvertTo-SecureString -String 'pw12' -AsPlainText -Force
        Receive-OtsSecret sec2222222222222222222222 -Passphrase $pass | Out-Null

        Should -Invoke -ModuleName OnetimeSecret Invoke-WebRequest -Times 1 -Exactly -ParameterFilter {
            (Get-SentJsonBody $Body).passphrase -eq 'pw12'
        }
    }

    It 'returns a SecureString with -AsSecureString' {
        $secret = Receive-OtsSecret sec2222222222222222222222 -AsSecureString
        $secret.Value | Should -BeOfType [securestring]
        (New-Object System.Management.Automation.PSCredential -ArgumentList 'x', $secret.Value).GetNetworkCredential().Password | Should -Be 'hunter2'
    }

    It 'uses the guest endpoint anonymously' {
        Receive-OtsSecret sec2222222222222222222222 -Connection $Anonymous | Out-Null
        Should -Invoke -ModuleName OnetimeSecret Invoke-WebRequest -Times 1 -Exactly -ParameterFilter {
            $Uri -eq 'https://eu.onetimesecret.com/api/v2/guest/secret/sec2222222222222222222222/reveal'
        }
    }

    It 'does nothing with -WhatIf' {
        Receive-OtsSecret sec2222222222222222222222 -WhatIf
        Should -Invoke -ModuleName OnetimeSecret Invoke-WebRequest -Times 0
    }
}

Describe 'Get-OtsStatus' {
    It 'reports a healthy service' {
        Mock -ModuleName OnetimeSecret Invoke-WebRequest { New-FakeHttpResponse -Body @{ success = $true; status = 'nominal'; locale = 'en' } }

        $status = Get-OtsStatus
        Should -Invoke -ModuleName OnetimeSecret Invoke-WebRequest -Times 1 -Exactly -ParameterFilter {
            $Uri -eq 'https://eu.onetimesecret.com/api/v2/status'
        }
        $status.IsHealthy | Should -BeTrue
        $status.Status | Should -Be 'nominal'
    }

    It 'checks arbitrary servers without connecting' {
        Mock -ModuleName OnetimeSecret Invoke-WebRequest { New-FakeHttpResponse -Body @{ success = $true; status = 'nominal'; locale = 'en' } }

        $statuses = @('https://us.onetimesecret.com', 'https://ca.onetimesecret.com' | Get-OtsStatus)
        $statuses.Count | Should -Be 2
        $statuses[1].ServerUri.Host | Should -Be 'ca.onetimesecret.com'
    }
}
