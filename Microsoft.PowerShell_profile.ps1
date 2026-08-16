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

# ── PATH 自愈 ──────────────────────────────────────────────────────
# 第三方安装器普遍用 [Environment]::SetEnvironmentVariable 往用户 PATH 写东西，
# 那个 API 写的是 REG_SZ —— 类型一退回，%USERPROFILE% 就被烤成字面量，
# 之后再加带 %VAR% 的条目也不会展开了。检测到就修回去。
# 只改表示形式，展开后的值不变；平时只多一次注册表读取。
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
        # 展开后必须一致，否则不动
        if ([Environment]::ExpandEnvironmentVariables($__fixed) -eq
            [Environment]::ExpandEnvironmentVariables($__raw).TrimEnd(";")) {
            Set-ItemProperty -Path $__uk -Name Path -Value $__fixed -Type ExpandString
        }
    }
}

# ── 启动缓存 ───────────────────────────────────────────────────────
# starship / mise 的初始化脚本只随二进制变化，缓存后省掉每次启动的子进程。
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
# node / pnpm —— 交给 mise（取代 fnm + corepack 两层）。
# activate 不能缓存：每次启动都要为当前会话解析版本、挂上目录切换钩子。
# 版本来源：全局 ~\.config\mise\config.toml，项目里的 mise.toml / .node-version /
# package.json 的 packageManager 字段会就近覆盖
(&mise activate pwsh) | Out-String | Invoke-Expression

# 补全走缓存。必须排在 activate 之后 —— 补全脚本运行时要调 usage，
# 而 usage 本身是 mise 管的工具，activate 之前它不在 PATH 里，
# 于是每开一个 shell 都会打一行 "usage CLI not found"
$__f = "$__cacheDir\mise-completions.ps1"
$__src = (Get-Command mise -ErrorAction SilentlyContinue).Source
if ($__src -and ((-not (Test-Path $__f)) -or (Get-Item $__src).LastWriteTime -gt (Get-Item $__f).LastWriteTime)) {
    mise completion powershell | Out-String | Set-Content $__f -Encoding utf8
}
if (Test-Path $__f) { . $__f }

# ── 别名 ───────────────────────────────────────────────────────────
# la —— 对齐 Unix 侧的约定：长格式 + 隐藏项。
# PowerShell 的别名不能携带固定参数（-Force），所以只能写成函数；
# 而别名的解析优先级高于函数，原有的 Set-Alias la 必须先移除
Remove-Item Alias:la -Force -ErrorAction Ignore
function la { Get-ChildItem -Force @args }

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
function grt {
    # 跳到仓库根。git 不在仓库里会返回空，此时 Set-Location $null 会抛异常，所以要挡一下
    $root = git rev-parse --show-toplevel 2>$null
    if ($root) { Set-Location $root } else { Write-Warning "不在 git 仓库中" }
}

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

