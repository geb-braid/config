# Ready? Set, Go!
# ~/Documents/PowerShell/prs.psm1

# This needs to support:
# [x] list active PRs to review
# [x] fetch PR remote branch
# [x] get PR commit range for `git diff`
# [x] find PRs by id or by URL
# [ ] purge closed PRs, deleting their *remote* representing branches

# Get reviewers, but not nir's votes
# azps repos pr list --status active \
# | jq '[.[1].reviewers[] \
# | {name: .displayName, uname: .uniqueName, vote: .vote} \
# | select(.uname!="nir.maoz.ext@rapid-data.com") ]'

function Format-PrUrl {
  param([string] $Url)
  # e.g. https://dev.azure.com/rapid-data/Engineering/_git/nova-javahut-national-portal/pullrequest/10549?_a=files
  if ($Url -imatch '/pullrequest/(\d+)\?') {
    return $Matches[1]
  }
}

enum PrStatus { abandoned; active; all; completed }

function Get-Prs {
  param([PrStatus] $Status = 'active', [int] $Top = 10)
  $jqFmt = @(
    '{'
      'id: .codeReviewId,'
      'title: .title,'
      'author: .createdBy.displayName,'
      'status: .status,'
      'source: .sourceRefName,'
      'target: .targetRefName'
    '}'
  ) -join ' '

  & 'azps' 'repos' 'pr' 'list' '--top' $Top '--status' $Status |
    & 'jq' "[.[] | $jqFmt]" |
    ConvertFrom-Json
}

function Get-Pr {
  param([Parameter(ValueFromPipeline=$True)][string] $Id, [switch] $Fetch)
  if ($Id -eq '') {
    Write-Error -Message 'No PR Id given.'
    return
  }

  $jqFmt = @(
    '{'
      'id: .codeReviewId,'
      'title: .title,'
      'author: .createdBy.displayName,'
      'status: .status,'
      'source: .sourceRefName,'
      'target: .targetRefName,'
      'url: .url'
    '}'
  ) -join ' '

  $pr = & 'azps' 'repos' 'pr' 'show' '--id' $Id |
    & 'jq' $jqFmt |
    ConvertFrom-Json

  if ($Fetch) {
    & 'git' 'fetch' 'origin' $pr.source | Write-Information
    & 'git' 'fetch' 'origin' $pr.target | Write-Information
  }
  return $pr
}

function Measure-Prs {
  param([PrStatus] $Status = 'active', [int] $Top = 10)

  function sourceTmp { param([string] $source) return "_measure-source-$($source.Replace('refs/heads/', '').Replace('/', '-'))" }
  function targetTmp { param([string] $target) return "_measure-target-$($target.Replace('refs/heads/', '').Replace('/', '-'))" }

  $prs = Get-Prs -Status $Status -Top $Top
  if (-not $prs) { return }

  # source e.g. 'refs/heads/feature/RE-585' => 'refs/heads/_measure-source-feature-RE-585'
  $srcRefspecs = foreach ($pr in $prs) { "+$($pr.source):refs/heads/$(sourceTmp $pr.source)" }
  # target e.g. 'refs/heads/main' => 'refs/heads/_measure-target-main
  $tgtRefspecs = foreach ($pr in $prs) { "+$($pr.target):refs/heads/$(targetTmp $pr.target)" }

  $refspecs = @($srcRefspecs) + @($tgtRefspecs) | Select-Object -Unique

  $tmps = @(foreach ($pr in $prs) { (sourceTmp $pr.source), (targetTmp $pr.target) }) | Select-Object -Unique

  echo $refspecs
  echo $tmps

  try {
    & 'git' 'fetch' '--quiet' '--force' 'origin' @refspecs | Write-Information

    foreach ($pr in $prs) {
      $tmp = (sourceTmp $pr.source)
      $mergeBase = & 'git' 'merge-base' (targetTmp $pr.target) $tmp
      $stat = & 'git' 'diff' '--shortstat' "$mergeBase..$tmp"

      $stat = if ($stat) { $stat.Trim() } else { 'no changes' }
      [PSCustomObject]@{
        ID      = $pr.id
        changes = $stat
        author  = $pr.author
        title   = $pr.title
      }
    }
  } finally {
    & 'git' 'branch' '-D' @tmps 2>$null | Write-Information
  }
}

function Remove-PrBranch {
  param([Parameter(ValueFromPipeline=$True)]$Pr)
  function asRemote { param([string] $pathSpec) return $pathSpec.Replace('refs/heads/', 'origin/') }

  if ($pr.status -eq 'completed') {
    # & 'git' 'fetch' 'origin' $pr.target
    & 'git' 'branch' '-dr' asRemote($pr.source) | Write-Information
  } else {
    Write-Error -Message 'PR is not yet completed. Aborting operation.'
  }
}

function Format-PrAsRange {
  param([Parameter(ValueFromPipeline=$True)]$Pr, [switch] $AsDiff, [switch] $AsLog)

  function remote { param([string] $headBranchName) return $headBranchName.Replace('refs/heads/', 'refs/remotes/origin/') }

  $src = remote($pr.source)  # e.g. refs/remotes/origin/feature/RE-585
  $dest = remote($pr.target) # e.g. refs/remotes/origin/main

  if ($AsDiff) {
    "$dest...$src"
  } elseif ($AsLog) {
    # for `glol`
    "$dest..$src"
  }
}

# More ideas:
# Switch PR command: Switches below PR related branches, as commit aliases, for
# git command usage:
# - 'com'   PR branch-off point. Common ancsetor with branch destination.
# - 'pr'    Latest reviewed commit.
# - 'prnew' Latest fetched commit.

function pco {
  param([Parameter(ValueFromPipeline=$True)][string] $Id, [switch] $Fetch)

  if (-not $Id) {
    Write-Error -Message 'No PR Id given.'
    return
  }

  # current branch can't be 'com', 'pr', 'prnew'; otherwise, aborts
  $currentBranch = & 'git' 'branch' '--show-current'
  if ($currentBranch -in 'com','pr','prnew') {
    Write-Error -Message "Can't update current branch ('$currentBranch'). Please switch to a different branch."
    return
  }

  function remote { param([string] $headBranchName) return $headBranchName.Replace('refs/heads/', 'refs/remotes/origin/') }
  function origin { param([string] $headBranchName) return $headBranchName.Replace('refs/heads/', 'origin/') }

  $pr = Get-Pr -Id $Id
  if (-not $pr) {
    Write-Error -Message 'PR not found.'
    return
  }

  # origin/feature/RE-585
  $prBranch = & 'git' 'branch' '--remotes' '--list' "$(origin($pr.source))"
  if (-not $Fetch -and -not $prBranch) {
    Write-Error -Message 'PR not yet fetched. Use `-Fetch`.'
    return
  }

  $src = remote($pr.source)  # e.g. refs/remotes/origin/feature/RE-585
  $dest = remote($pr.target) # e.g. refs/remotes/origin/main
  & 'git' 'branch' '--force' '--no-track' 'pr' $src
  & 'git' 'branch' '--force' '--no-track' 'prnew' $src

  if ($Fetch) {
    & 'git' 'fetch' 'origin' $pr.source | Write-Information
    & 'git' 'fetch' 'origin' $pr.target | Write-Information
    & 'git' 'branch' '--force' '--no-track' 'prnew' $src # newly fetched PR branch
  }

  $commonBase = & 'git' 'merge-base' $src $dest
  & 'git' 'branch' '--force' '--no-track' 'com' $commonBase
}
