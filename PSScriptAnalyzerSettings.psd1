@{
    # Shared PSScriptAnalyzer configuration for the module source, tests and
    # build scripts. CI treats any Warning or Error as a failure.
    Severity     = @('Error', 'Warning')

    IncludeRules = @('*')

    ExcludeRules = @(
        # The build script and tests legitimately use Write-Host for progress.
        'PSAvoidUsingWriteHost'
        # Command availability across editions is covered by the Windows
        # PowerShell 5.1 leg of CI; the rule's profiles also flag Pester and
        # Invoke-Build commands in tests and build scripts.
        'PSUseCompatibleCommands'
    )

    Rules        = @{
        PSUseCompatibleSyntax       = @{
            Enable         = $true
            TargetVersions = @('5.1', '7.0')
        }
        PSPlaceOpenBrace            = @{
            Enable             = $true
            OnSameLine         = $true
            NewLineAfter       = $true
            IgnoreOneLineBlock = $true
        }
        PSPlaceCloseBrace           = @{
            Enable             = $true
            NewLineAfter       = $true
            IgnoreOneLineBlock = $true
            NoEmptyLineBefore  = $false
        }
        PSUseConsistentIndentation  = @{
            Enable              = $true
            Kind                = 'space'
            PipelineIndentation = 'IncreaseIndentationForFirstPipeline'
            IndentationSize     = 4
        }
        PSUseConsistentWhitespace   = @{
            Enable                          = $true
            CheckInnerBrace                 = $true
            CheckOpenBrace                  = $true
            CheckOpenParen                  = $true
            CheckOperator                   = $false
            CheckPipe                       = $true
            CheckPipeForRedundantWhitespace = $false
            CheckSeparator                  = $true
            CheckParameter                  = $false
        }
        PSAlignAssignmentStatement  = @{
            Enable         = $false
            CheckHashtable = $false
        }
        PSUseCorrectCasing          = @{
            Enable = $true
        }
    }
}
