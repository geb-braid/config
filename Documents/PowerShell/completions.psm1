function Enable-DockerCompletions {
  # Install-Module DockerCompletion -Scope CurrentUser # first time only
  Import-Module DockerCompletion
}
function Enable-KubeCtlCompletions {
  & 'kubectl' 'completion' 'powershell' | Out-String | Invoke-Expression
}
function Enable-KubeLoginCompletions {
  # winget install -e --id Microsoft.Azure.Kubelogin
  & 'kubelogin' 'completion' 'powershell' | Out-String | Invoke-Expression
}
function Enable-BatCompletions {
  # winget install -e --id sharkdp.bat
  & 'bat' '--completion' 'ps1' | Out-String | Invoke-Expression
}
function Enable-FdCompletions {
  # winget install -e --id sharkdp.fd
  & 'fd' '--gen-completions' | Out-String | Invoke-Expression
}
function Enable-NpmCompletions {
  # npm completion # unix version only
  # for powershell use:
  # Install-Module npm-completion -Scope CurrentUser # first time only
  Import-Module npm-completion # maybe not needed
}
function Enable-RgCompletions {
  # winget install -e --id BurntSushi.ripgrep.MSVC
  & 'rg' '--generate=complete-powershell' | Out-String | Invoke-Expression
}

Set-Alias -Name 'docker-complete' -Value 'Enable-DockerCompletions'
Set-Alias -Name 'kubectl-complete' -Value 'Enable-KubeCtlCompletions'
Set-Alias -Name 'kubelogin-complete' -Value 'Enable-KubeLoginCompletions'
Set-Alias -Name 'bat-complete' -Value 'Enable-BatCompletions'
Set-Alias -Name 'fd-complete' -Value 'Enable-FdCompletions'
Set-Alias -Name 'npm-complete' -Value 'Enable-NpmCompletions'
