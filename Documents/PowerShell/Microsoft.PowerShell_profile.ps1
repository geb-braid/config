# TODO use `-Stream` for `echo` or `Out-String` (also in other scripts)
# Write-Host "Microsoft PowerShell" $PSVersionTable.PSVersion # PS7 already does this

Import-Module -Name "$PSScriptRoot\completions.psm1" -Force
Import-Module -Name "$PSScriptRoot\prs.psm1" -Force

# Install-Module powershell-yaml -Scope CurrentUser # first time only
# Import-Module powershell-yaml

# https://github.com/gluons/powershell-git-aliases
Import-Module git-aliases -DisableNameChecking

## begin git custom aliases
#
# EXAMPLE:
# function gds {
#   git diff --staged $args
# }
#
## end git custom aliases

# If you want posh-git to detect your own aliases for git, then you must have
# set the alias before importing posh-git. So if you have Set-Alias g git then
# ensure it is executed before Import-Module posh-git, and g checkout will
# complete as if you'd typed git.
Import-Module posh-git

Import-Module posh-git-alias-completion

# in case of errors: show red `!` for pwsh errors, or program exit code
function global:PromptWriteErrorInfo() {
  if ($global:GitPromptValues.DollarQuestion) { return }

  if ($global:GitPromptValues.LastExitCode) {
    "`n`e[31m(" + $global:GitPromptValues.LastExitCode + ") `e[0m"
  }
  else {
    "`n`e[31m! `e[0m"
  }
}
$global:GitPromptSettings.DefaultPromptBeforeSuffix.Text = '$(PromptWriteErrorInfo)'
# $global:GitPromptSettings.DefaultPromptBeforeSuffix.Text = '`n$(PromptWriteErrorInfo)$([DateTime]::now.ToString("MM-dd HH:mm:ss"))'

function ll { Get-ChildItem -Directory }
function l. { Get-ChildItem -Force .* }
function ll. { Get-ChildItem -Directory -Force .* }

function enc {
  param([EncodingType]$Encoding)
  enum EncodingType { default; ascii; utf; unicode }
  if ($Encoding -eq $null) {
    return [System.Console]::OutputEncoding;
  }

  [System.Console]::OutputEncoding = switch ($Encoding) {
    default { [System.Text.Encoding]::Default }
    ascii { [System.Text.Encoding]::ASCII }
    utf { [System.Text.Encoding]::UTF8 }
    unicode { [System.Text.Encoding]::Unicode }
  }
}

# Undo console state left behind by a native app that died without cleaning up
# (e.g. `less` killed by a broken pipe). The stuck flag is usually
# ENABLE_VIRTUAL_TERMINAL_INPUT, which makes conhost pass raw VT bytes instead of
# key events -> vim loses arrows/pgup/home, PSReadLine loses Ctrl+Backspace.
# Console mode is per-conhost, so it survives `pwsh -NoProfile` in the same tab.
function Reset-ConsoleMode {
  [CmdletBinding()]
  param()

  if (-not ('W32.ConsoleMode' -as [type])) {
    Add-Type -Name 'ConsoleMode' -Namespace 'W32' -MemberDefinition @'
[DllImport("kernel32", SetLastError=true)] public static extern IntPtr GetStdHandle(int n);
[DllImport("kernel32", SetLastError=true)] public static extern bool GetConsoleMode(IntPtr h, out uint m);
[DllImport("kernel32", SetLastError=true)] public static extern bool SetConsoleMode(IntPtr h, uint m);
'@
  }
  $api = [W32.ConsoleMode]

  # input: drop ENABLE_VIRTUAL_TERMINAL_INPUT (0x200), keep ENABLE_PROCESSED_INPUT (0x1) so Ctrl+C works
  # output: ensure PROCESSED (0x1) | WRAP_AT_EOL (0x2) | VIRTUAL_TERMINAL_PROCESSING (0x4),
  #         drop DISABLE_NEWLINE_AUTO_RETURN (0x8)
  foreach ($h in @(
    @{ Name = 'stdin' ; Id = -10; And = 0xFFFFFDFF; Or = 0x001 }
    @{ Name = 'stdout'; Id = -11; And = 0xFFFFFFF7; Or = 0x007 }
  )) {
    $handle = $api::GetStdHandle($h.Id)
    $mode = 0
    if (-not $api::GetConsoleMode($handle, [ref]$mode)) {
      Write-Verbose "$($h.Name): not a console handle (redirected?), skipped"
      continue
    }
    $new = ($mode -band $h.And) -bor $h.Or
    [void]$api::SetConsoleMode($handle, $new)
    Write-Verbose ("{0}: 0x{1:X} -> 0x{2:X}" -f $h.Name, $mode, $new)
  }

  # terminal side: leave alt screen, show cursor, autowrap on, mouse reporting off, reset SGR
  [Console]::Write("`e[?1049l`e[?25h`e[?7h`e[?1000l`e[?1002l`e[?1003l`e[?1006l`e[0m")
}

function Get-GitIncomingChanges {
  $CurrentBranch = Get-Git-CurrentBranch
  & 'git' 'log' '--stat' "$CurrentBranch..origin/$CurrentBranch"
}

function join {
  param(
    [Parameter(ValueFromPipeline=$True)] [string]$stdin,
    [Parameter(Position=0)] [string]$Prefix='',
    [Parameter(Position=1)] [string]$Separator = ' ',
    [Parameter(Position=2)] [string]$Quote = ''''
  )
  begin {
    $items = @()
  }
  process {
    $items += ($Quote ? ($Quote + $stdin + $Quote) : $stdin)
  }
  end {
    ( (@($Prefix) + $items) | Where { -not [string]::IsNullOrWhiteSpace($_) } ) -join $Separator
  }
}

filter cut {
  param(
    [string]$delimiter='\s+',
    [Nullable[int]]$field
  )

  ($field -eq $null) ? $_ -split $delimiter : ($_ -split $delimiter)[$field]
}

filter grep {
  param(
    [string]$pattern,
    [switch][boolean]$caseSensitive,
    [switch][boolean]$invert
  )

  if (($caseSensitive ? ($_ -cmatch $pattern) : ($_ -match $pattern)) -xor $invert) { $_ }
}

# This works like `xargs -n1`
filter xargs-n1 { ($h,$t) = $args; & $h ($t + $_) }

function nvm-use { & 'nvm' 'use' (Get-Content '.nvmrc') }

function squeeze {
  $input | & 'tr' '--squeeze-repeats' '[:space:]' @args
  # awk s/\s+//g $0
}

function Get-Tips { & 'bat' '-p' 'C:\Users\maozn\Documents\tips.md' }

function Goto-Prog { Set-Location 'C:\Program Files' }
function Goto-Prog86 { Set-Location 'C:\Program Files (x86)' }
function Goto-DBot { Set-Location 'C:\Users\maozn\Documents\Work\dbot' }
function Goto-Rapid { Set-Location 'C:\Users\maozn\Documents\Work\rapid-data' }
function Goto-Nir { Set-Location 'C:\Users\maozn\Documents\Work\nir' }
function Goto-MoveBE { Set-Location 'C:\dev\PO-Move' }
function Goto-MoveApp { Set-Location 'C:\dev\PO-Move-App' }
function Goto-FuneralApp { Set-Location 'C:\dev\funeral-next-app' }
function Goto-Legacy { Set-Location 'C:\Dev\erp\funeral-erp-legacy-api' }
function Goto-Next { Set-Location 'C:\Dev\erp\funeral-erp-core-api' }
function Goto-UI { Set-Location 'C:\Dev\erp\funeral-erp-core-ui' }

function Start-OPPO { & 'C:\Users\maozn\AppData\Local\Android\Sdk\emulator\emulator.exe' '-avd' 'OPPO' }

function Ping-Ms {
  & 'ping' '-n' '1' '8.8.8.8' >nul || echo 'Ping not working.'
  & 'ping' '-n' '1' 'www.microsoft.com' >nul || echo 'DNS not working.'
}

function .. { Set-Location '..' }
function ... { Set-Location '..\..' }
function .... { Set-Location '..\..\..' }
function ..... { Set-Location '..\..\..\..' }

function Show-Tree {
  (& "tree.com" "/a" $args) -replace '\|','│' -replace '\+','├' -replace '-','─' -replace '\\','└'
}

function Restart-Pwsh { Start-Process 'pwsh.exe' exit }

function Start-MultiFzf {
  if ($MyInvocation.ExpectingInput) {
    $input | & 'C:\Users\maozn\vimfiles\plugged\fzf\bin\fzf.exe' '-m' @args
  } else {
    & 'C:\Users\maozn\vimfiles\plugged\fzf\bin\fzf.exe' '-m' @args
  }
}

function Fetch-Man {
  param(
    [Parameter(Position=0)] [string]$Section='all', # should be empty or digit
    [Parameter(Position=1)] [string]$Topic = 'man'
  )
  $res = Invoke-WebRequest 'https://man.he.net/' -Method Post -Body @{ topic = $Topic; section = $Section }
  $res.Content -split '\r?\n' |
    & 'sed' '-ne' '/<PRE>/,/<\/PRE>/ { /<PRE>/ { n; b; }; p }'
}

function Format-Man {
  [CmdletBinding()]
  param([Parameter(ValueFromPipeline)][string]$Line)
  begin {
    $psi = [System.Diagnostics.ProcessStartInfo]::new('bat', '-Snl man')
    $psi.RedirectStandardInput = $true
    $psi.UseShellExecute = $false
    $proc = [System.Diagnostics.Process]::Start($psi)
    $brokenPipe = $false # latch so we can skip remaining processing lines
  }
  process {
    if ($brokenPipe -or $proc.HasExited) { $brokenPipe = $true; return }
    try { $proc.StandardInput.WriteLine($Line) } catch { $brokenPipe = $true }
  }
  end {
    try { $proc.StandardInput.Close() } catch { $brokenPipe = $true } # throws too, if already broken
    if ($brokenPipe) {
      Write-Verbose 'pipe broke'
    }
    $proc.WaitForExit()
  }
}

# NOTE: keep this a *simple* function (no [Parameter()]/[CmdletBinding()]),
# otherwise $input / $MyInvocation.ExpectingInput don't work
function Run-Man {
  param(
    [string]$Topic = 'man',
    [string]$Section='all' # should be empty or digit
  )

  if ($MyInvocation.ExpectingInput) {
    $input | Format-Man
  } else {
    Fetch-Man -Section $Section -Topic $Topic | Format-Man
  }
}

# PATH priorities
Set-Alias -Name 'bash' -Value 'C:/Program Files/Git/bin/bash.exe'
Set-Alias -Name 'fzf' -Value '~/vimfiles/plugged/fzf/bin/fzf.exe'

# Shortcuts
Set-Alias -Name 'man' -Value 'Run-Man'
Set-Alias -Name 'l' -Value 'Get-ChildItem'
Set-Alias -Name 'clip' -Value 'Set-Clipboard'
Set-Alias -Name 'celar' -Value 'Clear-Host'
Set-Alias -Name 'gitincoming' -Value 'Get-GitIncomingChanges'
Set-Alias -Name '**' -Value 'Start-MultiFzf'
Set-Alias -Name 'tips' -Value 'Get-Tips'
Set-Alias -Name 'tree' -Value 'Show-Tree'
Set-Alias -Name 'ms' -Value 'Ping-Ms'
Set-Alias -Name 'source' -Value 'Restart-Pwsh'
Set-Alias -Name 'fixterm' -Value 'Reset-ConsoleMode'

# Custom Scripts
Set-Alias -Name 'hud' -Value '~/Documents/Work/rapid-data/scripts/hud.ps1'
Set-Alias -Name 'fix' -Value '~/fix.ps1'
Set-Alias -Name 'rec' -Value '~/record-event.cmd'
Set-Alias -Name 'repl' -Value '~/Documents/Work/nir/vim-repl/vim-repl.ps1'

Set-Alias -Name 'prog' -Value 'Goto-Prog'
Set-Alias -Name 'prog86' -Value 'Goto-Prog86'
Set-Alias -Name 'dbot' -Value 'Goto-DBot'
Set-Alias -Name 'rapid' -Value 'Goto-Rapid'
Set-Alias -Name 'nir' -Value 'Goto-Nir'
Set-Alias -Name 'legacy' -Value 'Goto-Legacy'
Set-Alias -Name 'next' -Value 'Goto-Next'
Set-Alias -Name 'ui' -Value 'Goto-UI'
Set-Alias -Name 'mobe' -Value 'Goto-MoveBE'
Set-Alias -Name 'mofe' -Value 'Goto-MoveApp'
Set-Alias -Name 'app' -Value 'Goto-FuneralApp'

$env:Path += ';'
$env:Path += 'C:\Program Files (x86)\GnuWin32\bin;' # has make.exe
$env:Path += 'C:\Program Files\Vim;' # before git
$env:Path += 'C:\Program Files\Git\bin;' # before 'usr/bin'
$env:Path += 'C:\Users\maozn\.local\bin;'
$env:Path += 'C:\Program Files\Git\usr\bin;'
$env:Path += 'C:\Users\maozn\AppData\Local\Android\Sdk\platform-tools;' # mainly for adb.exe

# commented this out, because now using Docker Desktop app for Windows
# # see `~/.docker/windows-daemon.json`
# $env:DOCKER_HOST='tcp://0.0.0.0:2375'

$env:EDITOR = "'C:\Program Files\Vim\vim.exe'"

Set-PSReadlineOption -EditMode vi
Set-PSReadLineOption -ViModeIndicator Prompt

$PSDefaultParameterValues['Out-Default:OutVariable'] = 'res' # global, also affects within scripts!
$PSDefaultParameterValues.Disabled = $false

# Set-PSReadLineOption -ViModeIndicator Cursor
#
# . "$PSScriptRoot\UnixCommands.ps1"
# - Conflicting PS aliases (ls/cat/rm/cp/mv/echo/pwd/kill/ps/sort/tee/diff/clear/mkdir/rmdir) are removed before wrapping
# - ssh/scp will use Git's, not Windows OpenSSH — change order or drop them if you prefer the native ones.

# Unresolved:
# - want set/history/man overridden too? (left as PS)
# - prefer native Windows ssh/scp/tar/whoami over Git's?
# - keep PS aliases for kill/ps/sort/tee (more idiomatic in PS pipelines)?
