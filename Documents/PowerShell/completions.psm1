function Enable-DockerCompletions {
  # Install-Module DockerCompletion -Scope CurrentUser # first time only
  Import-Module DockerCompletion
}
function Enable-KubeCtlCompletions {
  & 'kubectl' 'completion' 'powershell' | Out-String | Invoke-Expression
}
function Enable-KubeLoginCompletions {
  & 'kubelogin' 'completion' 'powershell' | Out-String | Invoke-Expression
}
function Enable-BatCompletions {
  & 'bat' '--completion' 'ps1' | Out-String | Invoke-Expression
}
function Enable-FdCompletions {
  & 'fd' '--gen-completions' | Out-String | Invoke-Expression
}
function Enable-NpmCompletions {
  # npm completion # unix version only
  # for powershell use:
  # Install-Module npm-completion -Scope CurrentUser # first time only
  Import-Module npm-completion # maybe not needed
}

Set-Alias -Name 'docker-complete' -Value 'Enable-DockerCompletions'
Set-Alias -Name 'kubectl-complete' -Value 'Enable-KubeCtlCompletions'
Set-Alias -Name 'kubelogin-complete' -Value 'Enable-KubeLoginCompletions'
Set-Alias -Name 'bat-complete' -Value 'Enable-BatCompletions'
Set-Alias -Name 'fd-complete' -Value 'Enable-FdCompletions'
Set-Alias -Name 'npm-complete' -Value 'Enable-NpmCompletions'
