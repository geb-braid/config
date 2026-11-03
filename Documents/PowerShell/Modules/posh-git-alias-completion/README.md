# posh-git-alias-completion

Makes [posh-git](https://github.com/dahlbyk/posh-git) tab completion work for the short
aliases from [powershell-git-aliases](https://github.com/gluons/powershell-git-aliases).

```text
gco ma<TAB>      # completes branch names   (like: git checkout ma<TAB>)
gsw fe<TAB>      # completes branch names   (like: git switch fe<TAB>)
gbr --<TAB>      # completes branch options (like: git branch --remote --<TAB>)
gl or<TAB>       # completes remotes        (like: git pull or<TAB>)
gst <TAB>        # same completion as git status
```

Completion for an alias is **identical** to the equivalent `git` command — because it
*is* the equivalent `git` command under the hood.

## How it works

1. **Discover aliases.** On import it enumerates the functions exported by
   `git-aliases` (`Get-Command -Module git-aliases -CommandType Function`), skipping the
   `Get-Git-*` helper functions. New aliases in a future version are picked up
   automatically — nothing is hard-coded.

2. **Find the git command each alias runs — from the AST, not text.** Each alias is a
   thin wrapper, e.g. `function gbr { git branch --remote $args }`. The module parses the
   function's abstract syntax tree, finds the `git` invocation that forwards `$args`, and
   collects the leading literal tokens after `git` (the subcommand and hard-coded
   switches) using each token's verbatim source text. It stops at the first non-literal
   element — `$args`, or an interpolated value like `$MainBranch` — which is exactly where
   the user's completable arguments begin. So `gbr` maps to the prefix `branch --remote`,
   `gco` to `checkout`, and bare `g` to the empty prefix.

3. **Register one native argument completer** for every discovered alias
   (`Register-ArgumentCompleter -Native`), sharing a single script block.

4. **Rewrite and delegate.** When the completer fires it rebuilds the typed line up to the
   cursor, replaces *only* the alias token — located by its exact AST offsets, so quotes,
   escapes and partial words after it are preserved byte-for-byte — with `git <prefix>`,
   and passes the synthetic line to posh-git's own exported `Expand-GitCommand`. Its
   results are returned unchanged. No git-completion logic is reimplemented.

Because it reuses posh-git's engine and reads `$global:GitStatus` the same way posh-git
does, branch / remote / tag / file / option completion all behave exactly as for `git`.

## Installation

The module lives in a `PSModulePath` folder:

```
C:\Users\maozn\Documents\PowerShell\Modules\posh-git-alias-completion\
    posh-git-alias-completion.psd1
    posh-git-alias-completion.psm1
    README.md
```

Add to your PowerShell profile (`$PROFILE`), **after** the two modules it builds on:

```powershell
Import-Module posh-git
Import-Module git-aliases
Import-Module posh-git-alias-completion   # auto-registers on import
```

(The manifest lists `posh-git` and `git-aliases` as `RequiredModules`, so importing this
module alone will pull both in if needed — but keeping the explicit imports makes intent
clear.)

## Usage

Just import it — completion is registered automatically. That's it.

If you upgrade `git-aliases` and want brand-new aliases wired up in the current session
without restarting, re-run:

```powershell
Register-GitAliasCompletion            # idempotent; re-scans and re-registers
Register-GitAliasCompletion -Verbose   # also reports counts and anything skipped
Register-GitAliasCompletion -PassThru  # emit the alias names that were registered
```

### Exported commands

| Command | Purpose |
| --- | --- |
| `Register-GitAliasCompletion` | (Re)discover aliases and register completers. `-AliasModule` overrides auto-detection; `-PassThru` returns the names; `-Verbose` reports details. |
| `Get-GitAliasInvocation` | Inspect one alias function's AST and return the `git` prefix it expands to plus whether it forwards `$args`. Useful for debugging. |

## Limitations & edge cases

- **Import order / prerequisites.** posh-git and git-aliases must be loaded first. If they
  aren't, import prints a warning instead of failing, and you can call
  `Register-GitAliasCompletion` once they're available.

- **`ggpnp` is skipped.** It contains no direct `git` call (it chains `ggl; ggp $args`),
  so there is no git command to complete. It's the only exported alias not registered.

- **Interpolated arguments are dropped for completion.** `gcm` runs
  `git checkout $MainBranch $args`; completion treats it as `git checkout <args>` (the
  `$MainBranch` positional is omitted). This matches what you'd want when tab-completing
  and can't be reproduced statically anyway. Affects `gcm`, `gcd`, `grbm`, `gmom`, `gmum`,
  `glum`, `gprom`, etc.

- **"Action" aliases that ignore their input.** A few aliases don't forward `$args`
  (e.g. `gwip`, `gpoat`, `ggf`, `gpristine`). They still get a best-effort completer based
  on their leading git command, but since they ignore arguments, completing them isn't
  especially meaningful. No errors result.

- **Completion depends on `$global:GitStatus`**, which posh-git refreshes on each prompt —
  identical to posh-git's own behavior. In a non-interactive session you may need to set
  it (`$global:GitStatus = Get-GitStatus`) before completions reflect the repo.

- **Helper detection heuristic.** Functions whose names contain `-` are treated as
  helpers (the `Get-Git-*` functions) and skipped. All real aliases are short and
  dash-free, so this is safe for the current and foreseeable naming scheme.

- **PowerShell 7+.** Targets the PS 6+ `Register-ArgumentCompleter -Native` path that
  posh-git uses; not the legacy `TabExpansion` fallback.
```
