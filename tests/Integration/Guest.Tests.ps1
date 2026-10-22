<#
    Live tests against a real server using only the guest (anonymous)
    endpoints, so they need no account. They are skipped unless both of these
    are set:

        ONETIME_LIVE = 1
        ONETIME_BASE_URL = https://eu.onetimesecret.com   (or any instance)

    Each run creates a handful of short-lived secrets and burns or reveals
    every one of them before finishing.
#>

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingConvertToSecureStringWithPlainText', '', Justification = 'Test fixtures use throwaway values.')]
param()

BeforeDiscovery {
    $script:RunLive = ($env:ONETIME_LIVE -eq '1') -and -not [string]::IsNullOrWhiteSpace($env:ONETIME_BASE_URL)
}

BeforeAll {
    $repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    Get-Module OnetimeSecret | Remove-Module -Force
    Import-Module (Join-Path (Join-Path (Join-Path $repoRoot 'src') 'OnetimeSecret') 'OnetimeSecret.psd1') -Force

    if ($RunLive) {
        Connect-OtsAccount -ServerUri $env:ONETIME_BASE_URL -Anonymous
    }
}

AfterAll {
    Disconnect-OtsAccount -Confirm:$false
}

Describe 'Guest workflow against <_>' -ForEach @($env:ONETIME_BASE_URL) -Skip:(-not $RunLive) {
    It 'reports the service as healthy' {
        (Get-OtsStatus).IsHealthy | Should -BeTrue
    }

    It 'lists the locales the server supports' {
        $locales = Get-OtsSupportedLocale
        @($locales.Locales).Count | Should -BeGreaterOrEqual 1
        $locales.DefaultLocale | Should -Not -BeNullOrEmpty
        @($locales.Locales) | Should -Contain $locales.DefaultLocale
    }

    It 'withholds the build version from anonymous callers' {
        $failure = $null
        try { Get-OtsVersion -ErrorAction Stop } catch { $failure = $_ }
        $failure | Should -Not -BeNullOrEmpty
        $failure.Exception.Data['StatusCode'] | Should -Be 401
        $failure.CategoryInfo.Category | Should -Be 'AuthenticationError'
    }

    It 'conceals, inspects, reveals and then cannot reveal again' {
        $value = 'onetimesecret-powershell integration ' + [guid]::NewGuid().ToString('N')
        $receipt = New-OtsSecret -Secret $value -Ttl (New-TimeSpan -Minutes 5)

        $receipt.ReceiptId | Should -Not -BeNullOrEmpty
        $receipt.SecretId | Should -Not -BeNullOrEmpty
        $receipt.State | Should -Be 'new'
        $receipt.ShareUrl | Should -Match ('/secret/' + [regex]::Escape($receipt.SecretId) + '$')

        $status = Get-OtsSecretStatus -SecretId $receipt.SecretId
        $status.Exists | Should -BeTrue
        $status.State | Should -Be 'new'

        $metadata = Get-OtsSecret -SecretId $receipt.SecretId
        $metadata.Value | Should -BeNullOrEmpty
        $metadata.HasPassphrase | Should -BeFalse

        $revealed = Receive-OtsSecret -SecretId $receipt.ShareUrl -Confirm:$false
        $revealed.Value | Should -Be $value
        $revealed.State | Should -Be 'revealed'

        (Get-OtsSecretStatus -SecretId $receipt.SecretId).State | Should -Not -Be 'new'

        $failure = $null
        try { Receive-OtsSecret -SecretId $receipt.SecretId -Confirm:$false -ErrorAction Stop } catch { $failure = $_ }
        $failure | Should -Not -BeNullOrEmpty
        $failure.Exception.Data['StatusCode'] | Should -BeIn @(404, 403, 410)
    }

    It 'requires the passphrase to reveal' {
        $pass = ConvertTo-SecureString -String ('pw-' + [guid]::NewGuid().ToString('N')) -AsPlainText -Force
        $receipt = New-OtsSecret -Secret 'protected' -Passphrase $pass -Ttl (New-TimeSpan -Minutes 5)
        $receipt.HasPassphrase | Should -BeTrue

        $wrong = ConvertTo-SecureString -String 'wrong' -AsPlainText -Force
        { Receive-OtsSecret -SecretId $receipt.SecretId -Passphrase $wrong -Confirm:$false -ErrorAction Stop } | Should -Throw

        (Receive-OtsSecret -SecretId $receipt.SecretId -Passphrase $pass -Confirm:$false).Value | Should -Be 'protected'
    }

    It 'generates a secret and reports its value on the receipt' {
        $receipt = New-OtsSecret -Generate -Length 20 -Ttl (New-TimeSpan -Minutes 5)
        $receipt.Value | Should -Not -BeNullOrEmpty
        $receipt.Value.Length | Should -Be 20

        $receipt | Remove-OtsSecret -Confirm:$false
    }

    It 'burns an unread secret via its receipt' {
        $receipt = New-OtsSecret -Secret 'burn me' -Ttl (New-TimeSpan -Minutes 5)

        $burned = $receipt | Remove-OtsSecret -PassThru -Confirm:$false
        $burned.State | Should -Be 'burned'
        $burned.IsBurned | Should -BeTrue
        $burned.ShareUrl | Should -BeNullOrEmpty

        (Get-OtsReceipt -ReceiptId $receipt.ReceiptId).IsBurned | Should -BeTrue
        (Get-OtsSecretStatus -SecretId $receipt.SecretId).Exists | Should -BeFalse
    }

    It 'reports an unknown secret as not existing' {
        $status = Get-OtsSecretStatus -SecretId ('nope' + [guid]::NewGuid().ToString('N'))
        $status.Exists | Should -BeFalse
        $status.State | Should -Be 'unknown'
    }
}
