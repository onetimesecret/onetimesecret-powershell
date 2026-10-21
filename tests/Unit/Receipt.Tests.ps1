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

Describe 'Get-OtsReceipt' {
    It 'lists recent receipts when no identifier is given' {
        Mock -ModuleName OnetimeSecret Invoke-WebRequest {
            New-FakeHttpResponse -Body @{
                records = @(
                    (New-FakeReceiptRecord -ReceiptId 'rcpAAAAAAAAAAAAA' -SecretId 'secAAAAAAAAAAAAA')
                    (New-FakeReceiptRecord -ReceiptId 'rcpBBBBBBBBBBBBB' -SecretId 'secBBBBBBBBBBBBB' -State 'received')
                )
                count   = 2
                details = @{ type = 'list' }
            }
        }

        $receipts = @(Get-OtsReceipt)

        Should -Invoke -ModuleName OnetimeSecret Invoke-WebRequest -Times 1 -Exactly -ParameterFilter {
            $Uri -eq 'https://eu.onetimesecret.com/api/v2/receipt/recent' -and $Method -eq 'GET'
        }
        $receipts.Count | Should -Be 2
        $receipts[1].State | Should -Be 'received'
        $receipts[1].ShareUrl | Should -Be 'https://eu.onetimesecret.com/secret/secBBBBBBBBBBBBB'
    }

    It 'refuses to list anonymously' {
        Mock -ModuleName OnetimeSecret Invoke-WebRequest { throw 'should not be called' }
        { Get-OtsReceipt -Connection $Anonymous } | Should -Throw -ExpectedMessage '*authenticated connection*'
        Should -Invoke -ModuleName OnetimeSecret Invoke-WebRequest -Times 0
    }

    It 'shows a receipt by identifier with its URLs and details' {
        Mock -ModuleName OnetimeSecret Invoke-WebRequest {
            $record = New-FakeReceiptRecord -State 'received'
            $record['is_received'] = $true
            $record['received'] = 1792538905
            $record['share_url'] = 'https://eu.onetimesecret.com/secret/sec2222222222222222222222'
            $record['receipt_url'] = 'https://eu.onetimesecret.com/receipt/rcp1111111111111111111111'
            $record['burn_url'] = 'https://eu.onetimesecret.com/receipt/rcp1111111111111111111111/burn'
            $record['natural_expiration'] = '1 hour'
            $record['expiration_in_seconds'] = 1800
            New-FakeHttpResponse -Body @{ record = $record; details = @{ type = 'record'; view_count = 1; has_passphrase = $false } }
        }

        $receipt = Get-OtsReceipt -ReceiptId rcp1111111111111111111111

        Should -Invoke -ModuleName OnetimeSecret Invoke-WebRequest -Times 1 -Exactly -ParameterFilter {
            $Uri -eq 'https://eu.onetimesecret.com/api/v2/receipt/rcp1111111111111111111111'
        }
        $receipt.IsReceived | Should -BeTrue
        $receipt.Received | Should -BeOfType [datetime]
        $receipt.ExpiresIn | Should -Be ([timespan]::FromMinutes(30))
        $receipt.NaturalExpiration | Should -Be '1 hour'
        $receipt.ViewCount | Should -Be 1
        $receipt.BurnUrl | Should -Be 'https://eu.onetimesecret.com/receipt/rcp1111111111111111111111/burn'
    }

    It 'drops the share link when the server reports it without an identifier' {
        Mock -ModuleName OnetimeSecret Invoke-WebRequest {
            $record = New-FakeReceiptRecord -State 'burned'
            $record['secret_identifier'] = $null
            $record['share_url'] = 'https://eu.onetimesecret.com/secret/'
            New-FakeHttpResponse -Body @{ record = $record }
        }

        $receipt = Get-OtsReceipt -ReceiptId rcp1111111111111111111111
        $receipt.ShareUrl | Should -BeNullOrEmpty
        $receipt.SecretId | Should -BeNullOrEmpty
    }

    It 'accepts receipt links, including the legacy /private/ alias' {
        Mock -ModuleName OnetimeSecret Invoke-WebRequest { New-FakeHttpResponse -Body @{ record = (New-FakeReceiptRecord) } }

        Get-OtsReceipt 'https://eu.onetimesecret.com/receipt/rcp1111111111111111111111' | Out-Null
        Get-OtsReceipt 'https://eu.onetimesecret.com/private/rcp1111111111111111111111' | Out-Null

        Should -Invoke -ModuleName OnetimeSecret Invoke-WebRequest -Times 2 -Exactly -ParameterFilter {
            $Uri -eq 'https://eu.onetimesecret.com/api/v2/receipt/rcp1111111111111111111111'
        }
    }

    It 'uses the guest endpoint anonymously' {
        Mock -ModuleName OnetimeSecret Invoke-WebRequest { New-FakeHttpResponse -Body @{ record = (New-FakeReceiptRecord) } }
        Get-OtsReceipt rcp1111111111111111111111 -Connection $Anonymous | Out-Null
        Should -Invoke -ModuleName OnetimeSecret Invoke-WebRequest -Times 1 -Exactly -ParameterFilter {
            $Uri -eq 'https://eu.onetimesecret.com/api/v2/guest/receipt/rcp1111111111111111111111'
        }
    }
}

Describe 'Set-OtsReceipt' {
    BeforeEach {
        Mock -ModuleName OnetimeSecret Invoke-WebRequest {
            $record = New-FakeReceiptRecord
            $record['memo'] = 'hello'
            New-FakeHttpResponse -Body @{ record = $record }
        }
    }

    It 'patches the memo' {
        $result = Set-OtsReceipt -ReceiptId rcp1111111111111111111111 -Memo 'hello' -PassThru

        Should -Invoke -ModuleName OnetimeSecret Invoke-WebRequest -Times 1 -Exactly -ParameterFilter {
            $Uri -eq 'https://eu.onetimesecret.com/api/v2/receipt/rcp1111111111111111111111' -and
            $Method -eq 'PATCH' -and
            (Get-SentJsonBody $Body).memo -eq 'hello'
        }
        $result.Memo | Should -Be 'hello'
    }

    It 'returns nothing without -PassThru' {
        Set-OtsReceipt -ReceiptId rcp1111111111111111111111 -Memo 'hello' | Should -BeNullOrEmpty
    }

    It 'rejects memos over 500 characters' {
        { Set-OtsReceipt -ReceiptId rcp1 -Memo ('x' * 501) } | Should -Throw
    }

    It 'requires authentication' {
        { Set-OtsReceipt -ReceiptId rcp1 -Memo 'x' -Connection $Anonymous } | Should -Throw -ExpectedMessage '*authenticated connection*'
    }
}

Describe 'Remove-OtsSecret' {
    BeforeEach {
        # The burn endpoint echoes the pre-burn record; the follow-up GET has the truth.
        Mock -ModuleName OnetimeSecret Invoke-WebRequest {
            New-FakeHttpResponse -Body @{ record = (New-FakeReceiptRecord -State 'new'); details = @{ type = 'record'; title = 'Secret burned' } }
        } -ParameterFilter { $Method -eq 'POST' }
        Mock -ModuleName OnetimeSecret Invoke-WebRequest {
            New-FakeHttpResponse -Body @{ record = (New-FakeReceiptRecord -State 'burned'); details = @{ type = 'record' } }
        } -ParameterFilter { $Method -eq 'GET' }
    }

    It 'burns via the receipt identifier with continue=true' {
        Remove-OtsSecret -ReceiptId rcp1111111111111111111111

        Should -Invoke -ModuleName OnetimeSecret Invoke-WebRequest -Times 1 -Exactly -ParameterFilter {
            $Uri -eq 'https://eu.onetimesecret.com/api/v2/receipt/rcp1111111111111111111111/burn' -and
            $Method -eq 'POST' -and
            (Get-SentJsonBody $Body).continue -eq $true
        }
    }

    It 'returns nothing and makes no extra request without -PassThru' {
        Remove-OtsSecret -ReceiptId rcp1111111111111111111111 | Should -BeNullOrEmpty
        Should -Invoke -ModuleName OnetimeSecret Invoke-WebRequest -Times 0 -ParameterFilter { $Method -eq 'GET' }
    }

    It 'returns the re-read receipt with -PassThru' {
        $result = Remove-OtsSecret -ReceiptId rcp1111111111111111111111 -PassThru

        Should -Invoke -ModuleName OnetimeSecret Invoke-WebRequest -Times 1 -Exactly -ParameterFilter {
            $Method -eq 'GET' -and $Uri -eq 'https://eu.onetimesecret.com/api/v2/receipt/rcp1111111111111111111111'
        }
        $result.State | Should -Be 'burned'
        $result.IsBurned | Should -BeTrue
    }

    It 'binds ReceiptId from receipts on the pipeline' {
        $receipts = @(
            [PSCustomObject] @{ PSTypeName = 'OnetimeSecret.Receipt'; ReceiptId = 'rcpONE'; SecretId = 'secONE' }
            [PSCustomObject] @{ PSTypeName = 'OnetimeSecret.Receipt'; ReceiptId = 'rcpTWO'; SecretId = 'secTWO' }
        )
        $receipts | Remove-OtsSecret

        Should -Invoke -ModuleName OnetimeSecret Invoke-WebRequest -Times 2 -Exactly
        Should -Invoke -ModuleName OnetimeSecret Invoke-WebRequest -Times 1 -Exactly -ParameterFilter { $Method -eq 'POST' -and $Uri -like '*/receipt/rcpTWO/burn' }
    }

    It 'sends the passphrase' {
        $pass = ConvertTo-SecureString -String 'pw12' -AsPlainText -Force
        Remove-OtsSecret rcp1111111111111111111111 -Passphrase $pass
        Should -Invoke -ModuleName OnetimeSecret Invoke-WebRequest -Times 1 -Exactly -ParameterFilter {
            (Get-SentJsonBody $Body).passphrase -eq 'pw12'
        }
    }

    It 'does nothing with -WhatIf' {
        Remove-OtsSecret rcp1111111111111111111111 -WhatIf
        Should -Invoke -ModuleName OnetimeSecret Invoke-WebRequest -Times 0
    }

    It 'uses the guest endpoint anonymously' {
        Remove-OtsSecret rcp1111111111111111111111 -Connection $Anonymous
        Should -Invoke -ModuleName OnetimeSecret Invoke-WebRequest -Times 1 -Exactly -ParameterFilter {
            $Uri -eq 'https://eu.onetimesecret.com/api/v2/guest/receipt/rcp1111111111111111111111/burn'
        }
    }
}
