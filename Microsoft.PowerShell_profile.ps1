# ═══════════════════════════════════════════════════════════════════
# Layer from the inside out: shell → prompt → language runtime → aliases → functions
# Keep the same layers as macOS ~/.zshrc so they're easy to compare.
#
# PATH is not set in this file — Windows PATH comes entirely from two registry levels:
#   HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment   machine-level
#   HKCU\Environment                                                    user-level
# At login, they are merged with "machine-level first, user-level second." Always use
#   Set-ItemProperty -Path "HKCU:\Environment" -Name Path -Value $v -Type ExpandString
# rather than [Environment]::SetEnvironmentVariable — the latter writes REG_SZ,
# baking references like %USERPROFILE% / %SystemRoot% into literal strings.
# ═══════════════════════════════════════════════════════════════════

# ── The shell itself ─────────────────────────────────────────────────────
Set-PSReadlineKeyHandler -Key Tab -Function MenuComplete

# ── PATH self-repair ──────────────────────────────────────────────────────
# Third-party installers commonly use [Environment]::SetEnvironmentVariable to write to the user PATH,
# and that API writes REG_SZ — once the type is downgraded, %USERPROFILE% is baked into a literal string,
# and entries containing %VAR% added afterward won't expand either. Detect this and fix it.
# Only the representation changes; the expanded value stays the same. Normally, this adds just one registry read.
$__uk = "HKCU:\Environment"
$__raw = (Get-Item $__uk -ErrorAction SilentlyContinue).GetValue("Path", "", "DoNotExpandEnvironmentNames")
if ($__raw) {
    $__kind = (Get-Item $__uk).GetValueKind("Path")
    if ($__kind -ne "ExpandString" -or $__raw -like "*$env:USERPROFILE\*") {
        $__fixed = (($__raw -split ";") | Where-Object { $_ } | ForEach-Object {
                if ($_.StartsWith("$env:USERPROFILE\", [StringComparison]::OrdinalIgnoreCase)) {
                    "%USERPROFILE%\" + $_.Substring($env:USERPROFILE.Length + 1)
                } else { $_ }
            }) -join ";"
        # Only proceed if the expanded values match
        if ([Environment]::ExpandEnvironmentVariables($__fixed) -eq
            [Environment]::ExpandEnvironmentVariables($__raw).TrimEnd(";")) {
            Set-ItemProperty -Path $__uk -Name Path -Value $__fixed -Type ExpandString
        }
    }
}

# ── Startup cache ───────────────────────────────────────────────────────
# The starship / fnm initialization scripts change only when the binaries do; caching them avoids a subprocess on every startup.
# dot-source must be at the top level: inside a function, it only affects the function scope, so the prompt won't appear.
$__cacheDir = "$HOME\.cache\pwsh"
if (-not (Test-Path $__cacheDir)) { New-Item -ItemType Directory $__cacheDir -Force | Out-Null }

# ── Prompt ─────────────────────────────────────────────────────────
# Use --print-full-init to output the complete script directly; `starship init powershell` only returns a one-line
# bootstrap, which launches starship again when executed
$__f = "$__cacheDir\starship.ps1"
$__src = (Get-Command starship -ErrorAction SilentlyContinue).Source
if ($__src -and ((-not (Test-Path $__f)) -or (Get-Item $__src).LastWriteTime -gt (Get-Item $__f).LastWriteTime)) {
    starship init powershell --print-full-init | Out-String | Set-Content $__f -Encoding utf8
}
if (Test-Path $__f) { . $__f }

# ── Language runtime ─────────────────────────────────────────────────────
# node — completion script is about 42 KB, so use the cache
$__f = "$__cacheDir\fnm-completions.ps1"
$__src = (Get-Command fnm -ErrorAction SilentlyContinue).Source
if ($__src -and ((-not (Test-Path $__f)) -or (Get-Item $__src).LastWriteTime -gt (Get-Item $__f).LastWriteTime)) {
    fnm completions --shell powershell | Out-String | Set-Content $__f -Encoding utf8
}
if (Test-Path $__f) { . $__f }

# fnm env cannot be cached: it must create a multishell directory for the current session every time.
# Note that %LOCALAPPDATA%\fnm_multishells keeps accumulating; on Windows, it isn't cleaned up on exit
fnm env --use-on-cd --version-file-strategy=recursive --corepack-enabled --resolve-engines --shell powershell | Out-String | Invoke-Expression

# ── Aliases ───────────────────────────────────────────────────────────
Set-Alias -Name la -Value Get-ChildItem

# git — replaces the posh-git / git-aliases modules.
# Must use a function instead of Set-Alias: aliases can't carry fixed parameters.
# gp / gl are built-in read-only aliases (Get-ItemProperty / Get-Location), and command resolution order is
# alias > function, so without removing them first, the functions below can never be called
foreach ($a in "gp", "gl") { Remove-Item "Alias:$a" -Force -ErrorAction Ignore }

function g { git @args }
function gaa { git add --all @args }
function gcmsg { git commit --message @args }
function gp { git push @args }
function gl { git pull @args }
function gcl { git clone --recurse-submodules @args }

# ni / nr — ni is also a built-in alias (New-Item), so remove it first
Remove-Item Alias:ni -Force -ErrorAction Ignore

function nio { ni --prefer-offline }
function s { nr start }
function d { nr dev }
function b { nr build }
function bw { nr build --watch }
function t { nr test }
function tu { nr test -u }
function tw { nr test --watch }
function w { nr watch }
function p { nr play }
function c { nr typecheck }
function lint { nr lint }
function lintf { nr lint --fix }
function release { nr release }
function re { nr release }

# ── Functions ───────────────────────────────────────────────────────────
function i {
    param (
        [string]$DirectoryName
    )

    Set-Location -Path "$HOME\i\$DirectoryName"
}

function codex {
    $baseArgs = @("--dangerously-bypass-approvals-and-sandbox")
    $codexPath = (Get-Command codex -CommandType Application | Select-Object -First 1).Source

    & $codexPath @baseArgs resume --last @args 2>$null

    if ($LASTEXITCODE -ne 0) {
        & $codexPath @baseArgs @args
    }
}

function claude {
    $baseArgs = @("--allow-dangerously-skip-permissions", "--permission-mode", "plan")
    $claudePath = (Get-Command claude -CommandType Application).Source

    & $claudePath @baseArgs -c @args 2>$null

    if ($LASTEXITCODE -ne 0) {
        & $claudePath @baseArgs @args
    }
}


