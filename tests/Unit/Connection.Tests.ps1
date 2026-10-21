[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingConvertToSecureStringWithPlainText', '', Justification = 'Test fixtures use throwaway values.')]
param()

BeforeAll {
    $repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    Get-Module OnetimeSecret | Remove-Module -Force
    Import-Module (Join-Path (Join-Path (Join-Path $repoRoot 'src') 'OnetimeSecret') 'OnetimeSecret.psd1') -Force

    $script:Token = ConvertTo-SecureString -String 'tok_test' -AsPlainText -Force
    $script:Credential = New-Object System.Management.Automation.PSCredential -ArgumentList 'ur1abc23def', $Token
}

AfterAll {
    Disconnect-OtsAccount -Confirm:$false
    Remove-Item Env:ONETIME_BASE_URL, Env:ONETIME_CUSTOMER_EXTID, Env:ONETIME_API_TOKEN -ErrorAction SilentlyContinue
}

Describe 'Connect-OtsAccount' {
    BeforeEach {
        Disconnect-OtsAccount -Confirm:$false
        Remove-Item Env:ONETIME_BASE_URL, Env:ONETIME_CUSTOMER_EXTID, Env:ONETIME_API_TOKEN -ErrorAction SilentlyContinue
    }

    It 'returns nothing by default and sets the default connection' {
        $result = Connect-OtsAccount -ServerUri 'https://eu.onetimesecret.com' -Credential $Credential
        $result | Should -BeNullOrEmpty
        (Get-OtsConnection).ServerUri.Host | Should -Be 'eu.onetimesecret.com'
    }

    It 'returns the connection with -PassThru' {
        $connection = Connect-OtsAccount -ServerUri 'https://eu.onetimesecret.com' -Credential $Credential -PassThru
        $connection.PSObject.TypeNames | Should -Contain 'OnetimeSecret.Connection'
        $connection.Username | Should -Be 'ur1abc23def'
        $connection.IsAnonymous | Should -BeFalse
        $connection.ApiVersion | Should -Be 'v2'
    }

    It 'supports anonymous connections' {
        $connection = Connect-OtsAccount -ServerUri 'https://eu.onetimesecret.com' -Anonymous -PassThru
        $connection.IsAnonymous | Should -BeTrue
        $connection.Username | Should -BeNullOrEmpty
    }

    It 'normalises a trailing slash' {
        $connection = Connect-OtsAccount 'https://eu.onetimesecret.com/' -Anonymous -PassThru
        $connection.ServerUri.AbsoluteUri | Should -Be 'https://eu.onetimesecret.com/'
    }

    It 'keeps a path prefix for reverse-proxied installs' {
        $connection = Connect-OtsAccount 'https://intranet.example.com/ots/' -Anonymous -PassThru
        $connection.ServerUri.AbsoluteUri | Should -Be 'https://intranet.example.com/ots'
    }

    It 'rejects the apex website host' {
        { Connect-OtsAccount -ServerUri 'https://onetimesecret.com' -Anonymous } | Should -Throw -ExpectedMessage '*website, not an API host*'
    }

    It 'rejects a relative or non-http URI' {
        { Connect-OtsAccount -ServerUri 'eu.onetimesecret.com' -Anonymous } | Should -Throw -ExpectedMessage '*absolute http(s) URL*'
        { Connect-OtsAccount -ServerUri 'ftp://eu.onetimesecret.com' -Anonymous } | Should -Throw
    }

    It 'rejects a username that is neither an extid nor an email' {
        $bad = New-Object System.Management.Automation.PSCredential -ArgumentList 'not-an-extid', $Token
        { Connect-OtsAccount -ServerUri 'https://eu.onetimesecret.com' -Credential $bad } | Should -Throw -ExpectedMessage '*customer extid*'
    }

    It 'accepts an email username' {
        $email = New-Object System.Management.Automation.PSCredential -ArgumentList 'me@example.com', $Token
        { Connect-OtsAccount -ServerUri 'https://eu.onetimesecret.com' -Credential $email } | Should -Not -Throw
    }

    It 'sets a descriptive User-Agent' {
        $connection = Connect-OtsAccount 'https://eu.onetimesecret.com' -Anonymous -PassThru
        $connection.UserAgent | Should -Match '^OnetimeSecret-PowerShell/\d+\.\d+\.\d+ \(PowerShell/'
    }
}

Describe 'Connection resolution' {
    BeforeEach {
        Disconnect-OtsAccount -Confirm:$false
        Remove-Item Env:ONETIME_BASE_URL, Env:ONETIME_CUSTOMER_EXTID, Env:ONETIME_API_TOKEN -ErrorAction SilentlyContinue
    }

    It 'Get-OtsConnection returns nothing when not connected' {
        Get-OtsConnection | Should -BeNullOrEmpty
    }

    It 'cmdlets fail clearly when not connected' {
        { Get-OtsReceipt -ReceiptId abc } | Should -Throw -ExpectedMessage '*Connect-OtsAccount*'
    }

    It 'falls back to ONETIME_* environment variables' {
        $env:ONETIME_BASE_URL = 'https://ca.onetimesecret.com'
        $env:ONETIME_CUSTOMER_EXTID = 'ur9env'
        $env:ONETIME_API_TOKEN = 'tok_env'

        $connection = Get-OtsConnection
        $connection.ServerUri.Host | Should -Be 'ca.onetimesecret.com'
        $connection.Username | Should -Be 'ur9env'
        $connection.Credential.GetNetworkCredential().Password | Should -Be 'tok_env'
    }

    It 'uses an anonymous connection when only ONETIME_BASE_URL is set' {
        $env:ONETIME_BASE_URL = 'https://ca.onetimesecret.com'
        (Get-OtsConnection).IsAnonymous | Should -BeTrue
    }

    It 'prefers an explicit -Connection over the default' {
        Connect-OtsAccount 'https://eu.onetimesecret.com' -Anonymous
        $other = Connect-OtsAccount 'https://us.onetimesecret.com' -Anonymous -PassThru
        # Connect-OtsAccount also replaced the default; put the EU one back.
        Connect-OtsAccount 'https://eu.onetimesecret.com' -Anonymous

        InModuleScope OnetimeSecret -Parameters @{ Other = $other } {
            (Resolve-OtsConnection -Connection $Other).ServerUri.Host | Should -Be 'us.onetimesecret.com'
            (Resolve-OtsConnection).ServerUri.Host | Should -Be 'eu.onetimesecret.com'
        }
    }

    It 'Disconnect-OtsAccount clears the default' {
        Connect-OtsAccount 'https://eu.onetimesecret.com' -Anonymous
        Disconnect-OtsAccount -Confirm:$false
        Get-OtsConnection | Should -BeNullOrEmpty
    }
}
