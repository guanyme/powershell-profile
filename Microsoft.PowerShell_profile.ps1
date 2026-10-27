Set-PSReadlineKeyHandler -Key Tab -Function MenuComplete

Invoke-Expression (&starship init powershell)

(&mise activate pwsh) | Out-String | Invoke-Expression

Remove-Item Alias:la -Force -ErrorAction Ignore
function la { Get-ChildItem -Force @args }

foreach ($a in "gp", "gl") { Remove-Item "Alias:$a" -Force -ErrorAction Ignore }

function g { git @args }
function gaa { git add --all @args }
function gcmsg { git commit --message @args }
function gp { git push @args }
function gl { git pull @args }
function gcl { git clone --recurse-submodules @args }
function grt {
    $root = git rev-parse --show-toplevel 2>$null
    if ($root) { Set-Location $root } else { Write-Warning "不在 git 仓库中" }
}

function i {
    param (
        [string]$DirectoryName
    )

    Set-Location -Path "$HOME\i\$DirectoryName"
}

function codex {
    $baseArgs = @("--dangerously-bypass-approvals-and-sandbox")
    $codexPath = (Get-Command codex -CommandType Application | Select-Object -First 1).Source

    & $codexPath @baseArgs @args
}

function claude {
    $baseArgs = @("--allow-dangerously-skip-permissions", "--permission-mode", "plan")
    $claudePath = (Get-Command claude -CommandType Application).Source

    & $claudePath @baseArgs @args
}

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

. "C:\Users\guany\lib\oracle-cli\Lib\site-packages\oci_cli\bin\OciTabExpansion.ps1"
