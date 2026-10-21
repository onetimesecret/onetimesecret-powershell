@{
    # Module manifest for OnetimeSecret, the official PowerShell SDK for
    # Onetime Secret (https://onetimesecret.com).

    RootModule           = 'OnetimeSecret.psm1'
    ModuleVersion        = '0.1.0'
    CompatiblePSEditions = @('Desktop', 'Core')
    GUID                 = 'db732d55-d4da-4e0a-b772-f766058f9a4c'
    Author               = 'Delano Mandelbaum'
    CompanyName          = 'Onetime Secret'
    Copyright            = '(c) 2026 Onetime Secret. MIT License.'
    Description          = 'Official PowerShell client for the Onetime Secret API (v2). Create, share, reveal and burn self-destructing secrets from the command line or automation.'
    PowerShellVersion    = '5.1'

    FormatsToProcess     = @('OnetimeSecret.Format.ps1xml')

    # Explicit export lists keep Import-Module fast and make the public
    # surface a deliberate decision. Add new cmdlets here.
    FunctionsToExport    = @(
        'Connect-OtsAccount'
        'Disconnect-OtsAccount'
        'Get-OtsConnection'
        'New-OtsSecret'
        'Get-OtsSecret'
        'Get-OtsSecretStatus'
        'Receive-OtsSecret'
        'Remove-OtsSecret'
        'Get-OtsReceipt'
        'Set-OtsReceipt'
        'Get-OtsStatus'
    )
    CmdletsToExport      = @()
    VariablesToExport    = @()
    AliasesToExport      = @()

    PrivateData          = @{
        PSData = @{
            Tags         = @(
                'OnetimeSecret', 'Onetime', 'Secrets', 'Security', 'Password', 'Sharing',
                'REST', 'API', 'SDK',
                'PSEdition_Desktop', 'PSEdition_Core', 'Windows', 'Linux', 'MacOS'
            )
            LicenseUri   = 'https://github.com/onetimesecret/onetimesecret-powershell/blob/main/LICENSE'
            ProjectUri   = 'https://github.com/onetimesecret/onetimesecret-powershell'
            IconUri      = ''
            ReleaseNotes = 'https://github.com/onetimesecret/onetimesecret-powershell/blob/main/CHANGELOG.md'
            # Set to e.g. 'preview1' to publish a prerelease to the PowerShell Gallery.
            Prerelease   = ''
        }
    }
}
