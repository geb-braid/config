# posh-git-alias-completion
#
# Teaches posh-git's tab-completion engine about the short functions exported by
# powershell-git-aliases (https://github.com/gluons/powershell-git-aliases), so that
#
#     gco ma<TAB>      completes exactly like   git checkout ma<TAB>
#     gbr --<TAB>                               git branch --remote --<TAB>
#     gst <TAB>                                 git status <TAB>
#
# It does NOT reimplement any git-completion logic: every alias is rewritten into the
# equivalent `git ...` command line and handed to posh-git's own `Expand-GitCommand`.
# Neither posh-git nor powershell-git-aliases is modified.

# ---------------------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------------------

# Map of alias name  ->  the literal git prefix it expands to (e.g. 'checkout',
# 'branch --remote', or '' for the bare `g` passthrough). Populated by
# Register-GitAliasCompletion; read by the shared completer script block below.
$script:GitAliasPrefixMap = @{}

# ---------------------------------------------------------------------------------------
# AST analysis: work out which `git` command an alias function actually runs
# ---------------------------------------------------------------------------------------

function Get-GitAliasInvocation {
    <#
    .SYNOPSIS
        Inspect an alias function's AST and return the git subcommand + switches it runs.
    .OUTPUTS
        [pscustomobject] @{ Prefix = 'checkout'; ForwardsArgs = $true }  -- or $null when
        the function contains no direct `git` call (e.g. `ggpnp`, which only calls other
        aliases).
    #>
    [OutputType([psobject])]
    param(
        [Parameter(Mandatory)]
        [System.Management.Automation.FunctionInfo] $Function
    )

    $ast = $Function.ScriptBlock.Ast
    if (-not $ast) { return $null }

    # Every `git <...>` invocation anywhere in the body (loops, if-branches, etc.).
    $gitCommands = @($ast.FindAll(
            {
                param($node)
                ($node -is [System.Management.Automation.Language.CommandAst]) -and
                ($node.GetCommandName() -eq 'git')
            }, $true))

    if ($gitCommands.Count -eq 0) { return $null }

    # An alias may run several git commands (e.g. `gpoat`, `gwip`). The one that forwards
    # the caller's arguments -- the command containing `$args` -- is the one whose
    # completion the user cares about, so prefer it. If none forwards $args (an "action"
    # alias such as `gwip`), fall back to the first git command for a best-effort result.
    $target = $null
    foreach ($cmd in $gitCommands) {
        $forwardsArgs = $cmd.CommandElements | Where-Object {
            ($_ -is [System.Management.Automation.Language.VariableExpressionAst]) -and
            ($_.VariablePath.UserPath -eq 'args')
        }
        if ($forwardsArgs) { $target = $cmd; break }
    }

    $forwards = [bool] $target
    if (-not $target) { $target = $gitCommands[0] }

    # Collect the leading literal tokens after `git` -- the subcommand and any hard-coded
    # switches -- stopping at the first non-literal element. That boundary is exactly
    # where the completable arguments begin: `$args`, or an interpolated value such as
    # `$MainBranch` / `origin/$CurrentBranch` that we cannot (and need not) reproduce for
    # completion. Using each element's verbatim source text keeps `-d`, `--remote`,
    # `--max-count=10`, `--pretty=format:'...'` intact without any string surgery.
    $tokens = [System.Collections.Generic.List[string]]::new()
    for ($i = 1; $i -lt $target.CommandElements.Count; $i++) {
        $element = $target.CommandElements[$i]
        $isLiteral =
            ($element -is [System.Management.Automation.Language.StringConstantExpressionAst]) -or
            ($element -is [System.Management.Automation.Language.CommandParameterAst])
        if (-not $isLiteral) { break }
        $tokens.Add($element.Extent.Text)
    }

    [pscustomobject]@{
        Prefix       = ($tokens -join ' ')
        ForwardsArgs = $forwards
    }
}

# ---------------------------------------------------------------------------------------
# The shared argument completer
# ---------------------------------------------------------------------------------------

# One script block serves every registered alias. It rewrites the typed line into the
# equivalent `git ...` line and defers to posh-git. Defined once, at module scope, so it
# can read $script:GitAliasPrefixMap when invoked later by the completion host.
$script:GitAliasCompleter = {
    param($wordToComplete, $commandAst, $cursorPosition)

    if (-not $commandAst -or $commandAst.CommandElements.Count -lt 1) { return }

    # The alias exactly as typed (handles odd names like `gc!`).
    $aliasElement = $commandAst.CommandElements[0]
    $aliasName = $aliasElement.Extent.Text

    $prefix = $script:GitAliasPrefixMap[$aliasName]
    if ($null -eq $prefix) { return }   # not one of ours

    # Reconstruct the command text from its start up to the cursor. PowerShell strips the
    # trailing space of "gco <TAB>", but posh-git needs it to know a *new* argument is
    # starting, so pad it back exactly as posh-git's own completer does.
    $commandStart = $commandAst.Extent.StartOffset
    $padLength = $cursorPosition - $commandStart
    if ($padLength -lt 0) { return }

    $commandText = $commandAst.ToString()
    if ($padLength -gt $commandText.Length) {
        $commandText = $commandText.PadRight($padLength, ' ')
    }
    $textToCursor = $commandText.Substring(0, $padLength)

    # Replace ONLY the alias token -- its exact AST span -- with `git <prefix>`, leaving
    # everything the user typed after it (quotes, escapes, partial words) byte-for-byte
    # intact. Offsets come from the AST, so there is no fragile find/replace.
    $aliasLength = $aliasElement.Extent.EndOffset - $commandStart
    $rest = $textToCursor.Substring($aliasLength)

    $rewritten = if ([string]::IsNullOrEmpty($prefix)) { "git$rest" } else { "git $prefix$rest" }

    # Hand the synthetic line to posh-git's engine and pass its results straight back.
    Expand-GitCommand $rewritten
}

# ---------------------------------------------------------------------------------------
# Public entry point
# ---------------------------------------------------------------------------------------

function Register-GitAliasCompletion {
    <#
    .SYNOPSIS
        Register posh-git tab completion for every function exported by
        powershell-git-aliases.
    .DESCRIPTION
        Discovers the alias functions dynamically, determines the `git` command each one
        runs (via AST analysis), and registers a native argument completer that delegates
        to posh-git's Expand-GitCommand. Safe to call repeatedly; a later call picks up
        aliases added by a newer version of the module.
    .PARAMETER AliasModule
        Name of the powershell-git-aliases module. Auto-detected when omitted (the module
        installs as 'git-aliases').
    .PARAMETER PassThru
        Emit the names of the aliases that were wired up.
    .EXAMPLE
        Import-Module posh-git
        Import-Module git-aliases
        Import-Module posh-git-alias-completion   # auto-registers on import
    .EXAMPLE
        Register-GitAliasCompletion -Verbose      # re-run after upgrading git-aliases
    #>
    [CmdletBinding()]
    param(
        [string] $AliasModule,
        [switch] $PassThru
    )

    # posh-git supplies the engine we delegate to.
    if (-not (Get-Command -Name Expand-GitCommand -ErrorAction SilentlyContinue)) {
        throw "posh-git is not imported (Expand-GitCommand not found). Run 'Import-Module posh-git' first."
    }

    # Locate powershell-git-aliases. Its signature is the exported Get-Git-Aliases helper.
    if ($AliasModule) {
        $module = Get-Module -Name $AliasModule | Select-Object -First 1
        if (-not $module) { throw "Module '$AliasModule' is not imported." }
    }
    else {
        $module = Get-Module |
            Where-Object { $_.ExportedFunctions.ContainsKey('Get-Git-Aliases') } |
            Select-Object -First 1
        if (-not $module) { $module = Get-Module -Name 'git-aliases' | Select-Object -First 1 }
        if (-not $module) {
            throw "powershell-git-aliases is not imported. Run 'Import-Module git-aliases' first, or pass -AliasModule."
        }
    }

    # Enumerate the exported alias functions. Skip the module's Verb-Noun helper functions
    # (Get-Git-CurrentBranch, Get-Git-MainBranch, Get-Git-Aliases); every real alias is a
    # short, dash-free name, so a '-' cleanly distinguishes helpers.
    $functions = Get-Command -Module $module.Name -CommandType Function -ErrorAction Stop |
        Where-Object { $_.Name -notmatch '-' }

    $map = @{}
    $names = [System.Collections.Generic.List[string]]::new()
    $skipped = [System.Collections.Generic.List[string]]::new()

    foreach ($fn in $functions) {
        $info = Get-GitAliasInvocation -Function $fn
        if (-not $info) { $skipped.Add($fn.Name); continue }
        $map[$fn.Name] = $info.Prefix
        $names.Add($fn.Name)
    }

    $script:GitAliasPrefixMap = $map

    if ($names.Count -gt 0) {
        # Native completer -- fires for these functions just as posh-git's own proxy-
        # function completer does. One script block, many command names.
        Microsoft.PowerShell.Core\Register-ArgumentCompleter -CommandName $names -Native -ScriptBlock $script:GitAliasCompleter
    }

    Write-Verbose "posh-git-alias-completion: registered $($names.Count) aliases from module '$($module.Name)'."
    if ($skipped.Count -gt 0) {
        Write-Verbose "posh-git-alias-completion: skipped (no direct git call): $($skipped -join ', ')"
    }

    if ($PassThru) { $names }
}

# ---------------------------------------------------------------------------------------
# Auto-register on import (best effort)
# ---------------------------------------------------------------------------------------

try {
    Register-GitAliasCompletion
}
catch {
    Write-Warning "posh-git-alias-completion: $($_.Exception.Message) Completion not registered; call Register-GitAliasCompletion once both modules are loaded."
}

Export-ModuleMember -Function Register-GitAliasCompletion, Get-GitAliasInvocation
