# ═══════════════════════════════════════════════════════════════════
# 按「由内向外」分层：shell → 提示符 → 语言运行时 → 别名 → 函数
# 与 macOS 的 ~/.zshrc 保持同一套分层，便于两边对照。
#
# PATH 不在本文件里设置 —— Windows 的 PATH 全部来自注册表两级：
#   HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment   机器级
#   HKCU\Environment                                                    用户级
# 登录时按「机器级在前、用户级在后」合并。修改务必用
#   Set-ItemProperty -Path "HKCU:\Environment" -Name Path -Value $v -Type ExpandString
# 而不是 [Environment]::SetEnvironmentVariable —— 后者写 REG_SZ，
# 会把 %USERPROFILE% / %SystemRoot% 之类的引用烤成字面量。
# ═══════════════════════════════════════════════════════════════════

# ── shell 自身 ─────────────────────────────────────────────────────
Set-PSReadlineKeyHandler -Key Tab -Function MenuComplete

# ── 启动缓存 ───────────────────────────────────────────────────────
# starship / fnm 的初始化脚本只随二进制变化，缓存后省掉每次启动的子进程。
# dot-source 必须在顶层：包进函数里只会作用于函数作用域，prompt 出不来。
$__cacheDir = "$HOME\.cache\pwsh"
if (-not (Test-Path $__cacheDir)) { New-Item -ItemType Directory $__cacheDir -Force | Out-Null }

# ── 提示符 ─────────────────────────────────────────────────────────
# 用 --print-full-init 直出完整脚本；`starship init powershell` 只给一行
# bootstrap，执行时会再拉起一次 starship
$__f = "$__cacheDir\starship.ps1"
$__src = (Get-Command starship -ErrorAction SilentlyContinue).Source
if ($__src -and ((-not (Test-Path $__f)) -or (Get-Item $__src).LastWriteTime -gt (Get-Item $__f).LastWriteTime)) {
    starship init powershell --print-full-init | Out-String | Set-Content $__f -Encoding utf8
}
if (Test-Path $__f) { . $__f }

# ── 语言运行时 ─────────────────────────────────────────────────────
# node —— 补全脚本约 42 KB，走缓存
$__f = "$__cacheDir\fnm-completions.ps1"
$__src = (Get-Command fnm -ErrorAction SilentlyContinue).Source
if ($__src -and ((-not (Test-Path $__f)) -or (Get-Item $__src).LastWriteTime -gt (Get-Item $__f).LastWriteTime)) {
    fnm completions --shell powershell | Out-String | Set-Content $__f -Encoding utf8
}
if (Test-Path $__f) { . $__f }

# fnm env 不能缓存：每次都要为当前会话创建 multishell 目录。
# 注意 %LOCALAPPDATA%\fnm_multishells 会一直堆积，Windows 上退出时不清理
fnm env --use-on-cd --version-file-strategy=recursive --corepack-enabled --resolve-engines --shell powershell | Out-String | Invoke-Expression

# ── 别名 ───────────────────────────────────────────────────────────
Set-Alias -Name la -Value Get-ChildItem

# git —— 取代 posh-git / git-aliases 模块。
# 必须用函数而非 Set-Alias：别名不能携带固定参数。
# gp / gl 是内置只读别名（Get-ItemProperty / Get-Location），命令解析顺序是
# 别名 > 函数，不先移除的话下面的函数永远调不到
foreach ($a in "gp", "gl") { Remove-Item "Alias:$a" -Force -ErrorAction Ignore }

function g { git @args }
function gaa { git add --all @args }
function gcmsg { git commit --message @args }
function gp { git push @args }
function gl { git pull @args }
function gcl { git clone --recurse-submodules @args }

# ni / nr —— ni 同样是内置别名（New-Item），先让位
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

# ── 函数 ───────────────────────────────────────────────────────────
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

