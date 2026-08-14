Set-PSReadlineKeyHandler -Key Tab -Function MenuComplete


# git —— 取代 posh-git / git-aliases 模块
# gp / gl 是内置只读别名（Get-ItemProperty / Get-Location），必须先移除才能被函数接管
foreach ($a in "gp", "gl") { Remove-Item "Alias:$a" -Force -ErrorAction Ignore }

function g { git @args }
function gaa { git add --all @args }
function gcmsg { git commit --message @args }
function gp { git push @args }
function gl { git pull @args }
function gcl { git clone --recurse-submodules @args }

# ---- 启动缓存 ----
# starship / fnm 的初始化脚本内容只随二进制变化，缓存后可省掉每次启动的子进程。
# 注意必须在此处直接 dot-source：包进函数里 dot-source 只会落到函数作用域。
$__cacheDir = "$HOME\.cache\pwsh"
if (-not (Test-Path $__cacheDir)) { New-Item -ItemType Directory $__cacheDir -Force | Out-Null }

# starship：用 --print-full-init 直出完整脚本，
# 否则 `starship init powershell` 只给一行 bootstrap，执行时会再拉起一次 starship
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

# fnm 补全（约 42 KB，同样走缓存）
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

