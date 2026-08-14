Set-PSReadlineKeyHandler -Key Tab -Function MenuComplete


# git — replaces the posh-git / git-aliases modules
# gp / gl are built-in read-only aliases (Get-ItemProperty / Get-Location); remove them first so functions can take over
foreach ($a in "gp", "gl") { Remove-Item "Alias:$a" -Force -ErrorAction Ignore }

function g { git @args }
function gaa { git add --all @args }
function gcmsg { git commit --message @args }
function gp { git push @args }
function gl { git pull @args }
function gcl { git clone --recurse-submodules @args }

# ---- Startup cache ----
# The contents of the starship / fnm initialization scripts change only when the binaries do, so caching them avoids a subprocess on every startup.
# Note that dot-source must be called directly here: inside a function, dot-source only affects the function scope.
$__cacheDir = "$HOME\.cache\pwsh"
if (-not (Test-Path $__cacheDir)) { New-Item -ItemType Directory $__cacheDir -Force | Out-Null }

# starship: use --print-full-init to output the complete script directly,
# otherwise `starship init powershell` only returns a one-line bootstrap, which launches starship again when executed
$__f = "$__cacheDir\starship.ps1"
$__src = (Get-Command starship -ErrorAction SilentlyContinue).Source
if ($__src -and ((-not (Test-Path $__f)) -or (Get-Item $__src).LastWriteTime -gt (Get-Item $__f).LastWriteTime)) {
    starship init powershell --print-full-init | Out-String | Set-Content $__f -Encoding utf8
}
if (Test-Path $__f) { . $__f }

Set-Alias -Name la -Value Get-ChildItem

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

# fnm completions (about 42 KB, cached as well)
$__f = "$__cacheDir\fnm-completions.ps1"
$__src = (Get-Command fnm -ErrorAction SilentlyContinue).Source
if ($__src -and ((-not (Test-Path $__f)) -or (Get-Item $__src).LastWriteTime -gt (Get-Item $__f).LastWriteTime)) {
    fnm completions --shell powershell | Out-String | Set-Content $__f -Encoding utf8
}
if (Test-Path $__f) { . $__f }

fnm env --use-on-cd --version-file-strategy=recursive --corepack-enabled --resolve-engines --shell powershell | Out-String | Invoke-Expression

Remove-Item Alias:ni -Force -ErrorAction Ignore

function nio {
    ni --prefer-offline
}

function s {
    nr start
}

function d {
    nr dev
}

function b {
    nr build
}

function bw {
    nr build --watch
}

function t {
    nr test
}

function tu {
    nr test -u
}

function tw {
    nr test --watch
}

function w {
    nr watch
}

function p {
    nr play
}

function c {
    nr typecheck
}

function lint {
    nr lint
}

function lintf {
    nr lint --fix
}

function release {
    nr release
}

function re {
    nr release
}

