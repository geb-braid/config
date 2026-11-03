@{
    RootModule        = 'posh-git-alias-completion.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = '5d2f8515-8d9b-4a99-9a0a-98c6f0423192'
    Author            = 'nir'
    Description       = 'Extends posh-git tab completion to the aliases exported by powershell-git-aliases. Rewrites each alias into its equivalent git command and delegates to posh-git''s own completion engine.'
    PowerShellVersion = '7.0'

    # Bring the engines we build on with us so completion works after a bare
    # `Import-Module posh-git-alias-completion`, regardless of import order.
    RequiredModules   = @('posh-git', 'git-aliases')

    FunctionsToExport = @('Register-GitAliasCompletion', 'Get-GitAliasInvocation')
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    PrivateData       = @{
        PSData = @{
            Tags       = @('git', 'posh-git', 'git-aliases', 'completion', 'tab-completion', 'PSEdition_Core')
            ProjectUri = 'https://github.com/gluons/powershell-git-aliases'
        }
    }
}
