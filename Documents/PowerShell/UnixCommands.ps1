# UNIX command wrappers. Dot-source from profile.
# Calls .exe in Git for Windows usr\bin without polluting PATH.

$script:UnixBin = 'C:\Program Files\Git\usr\bin'

if (-not (Test-Path $script:UnixBin)) {
    Write-Warning "UnixCommands: $script:UnixBin not found"
    return
}

# UNIX commands to wrap. Several shadow built-in PS aliases (ls, cat, rm, ...).
$cmds = @(
    'awk','basename','cat','chmod','clear','cp','cut','date','df','diff',
    'du','echo','env','false','find','fold','grep','head','hostname','kill',
    'less','ln','locate','ls','mkdir','mv','od','paste','printf','ps',
    'pwd','reset','rm','rmdir','scp','sed','sort','ssh','tac','tail',
    'tar','tee','touch','tr','true','uname','uniq','unzip','wc','which',
    'whoami','xargs'
)

foreach ($c in $cmds) {
    $exe = Join-Path $script:UnixBin "$c.exe"
    if (-not (Test-Path -LiteralPath $exe)) {
        Write-Warning "UnixCommands: $exe missing — skipped"
        continue
    }

    # Drop conflicting alias so the function wins name resolution.
    if (Test-Path "Alias:\$c") { Remove-Item "Alias:\$c" -Force -ErrorAction SilentlyContinue }

    Set-Item -Path "Function:\global:$c" -Value ([ScriptBlock]::Create("& `"$exe`" @args"))
}

# UNIX-style ls aliases.
function global:ll { & "$script:UnixBin\ls.exe" -lhF --color=auto @args }
function global:la { & "$script:UnixBin\ls.exe" -lahF --color=auto @args }

Remove-Variable cmds
