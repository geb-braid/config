# TODO use `-Stream` for `echo` or `Out-String` (also in other scripts)
# Write-Host "Microsoft PowerShell" $PSVersionTable.PSVersion # PS7 already does this

# Install-Module DockerCompletion -Scope CurrentUser # first time only
# Import-Module DockerCompletion
# kubectl completion powershell | Out-String | Invoke-Expression
# kubelogin completion powershell | Out-String | Invoke-Expression
# bat --completion ps1 | Out-String | Invoke-Expression
# npm completion # not for Pwsh; Can instead use:
#   Install-Module npm-completion -Scope CurrentUser # first time only
#   Import-Module npm-completion # maybe not needed

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

function ll { Get-ChildItem -Directory }

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

function squeeze {
  $input | & 'tr' '--squeeze-repeats' '[:space:]' @args
  # awk s/\s+//g $0
}

function Get-Tips { & 'bat' '-p' 'C:\Users\maozn\Documents\tips.md' }
function Goto-Legacy { Set-Location 'C:\Users\maozn\Documents\Work\rapid-data\funeral-erp-legacy-api' }
function Goto-Next { Set-Location 'C:\Users\maozn\Documents\Work\rapid-data\funeral-erp-core-api' }
function Goto-UI { Set-Location 'C:\Users\maozn\Documents\Work\rapid-data\funeral-erp-core-ui' }
function Goto-Nir { Set-Location 'C:\Users\maozn\Documents\Work\nir' }

function Ping-Ms {
  # & 'ping' 'www.microsoft.com'
  # & 'ping' '23.63.193.222'
  & 'ping' '184.27.65.11'
}

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

function Vim-Repl { & '~/Documents/Work/nir/vim-repl/vim-repl.ps1' }

Set-Alias -Name 'l' -Value 'Get-ChildItem'
Set-Alias -Name 'clip' -Value 'Set-Clipboard'
Set-Alias -Name 'celar' -Value 'Clear-Host'
Set-Alias -Name 'gitincoming' -Value 'Get-GitIncomingChanges'
Set-Alias -Name '**' -Value 'Start-MultiFzf'
Set-Alias -Name 'tips' -Value 'Get-Tips'
Set-Alias -Name 'tree' -Value 'Show-Tree'
Set-Alias -Name 'ms' -Value 'Ping-Ms'
Set-Alias -Name 'source' -Value 'Restart-Pwsh'
Set-Alias -Name 'bash' -Value 'C:\Program Files\Git\usr\bin\bash.exe'

Set-Alias -Name 'fix' -Value '~/fix.ps1'
Set-Alias -Name 'rec' -Value '~/record-event.cmd'
Set-Alias -Name 'repl' -Value 'Vim-Repl'

Set-Alias -Name 'nir' -Value 'Goto-Nir'
Set-Alias -Name 'legacy' -Value 'Goto-Legacy'
Set-Alias -Name 'next' -Value 'Goto-Next'
Set-Alias -Name 'ui' -Value 'Goto-UI'

$env:Path += ';'
$env:Path += 'C:\Program Files (x86)\GnuWin32\bin;'
$env:Path += 'C:\Program Files\Git\bin;'
$env:Path += 'C:\Users\maozn\.local\bin;'
$env:Path += 'C:\Program Files\Git\usr\bin;'

# commented this out, because now using Docker Desktop app for Windows
# # see `~/.docker/windows-daemon.json`
# $env:DOCKER_HOST='tcp://0.0.0.0:2375'

Set-Variable EDITOR 'C:\Program Files\Git\usr\bin\vim.exe'

Set-PSReadlineOption -EditMode vi
Set-PSReadLineOption -ViModeIndicator Prompt
# Set-PSReadLineOption -ViModeIndicator Cursor
