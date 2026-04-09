Set-PSReadlineKeyHandler -Key Tab -Function MenuComplete

Import-Module posh-git
Import-Module git-aliases -DisableNameChecking
Import-Module z

Invoke-Expression (&starship init powershell)

Set-Alias -Name la -Value Get-ChildItem

function i {
    param (
        [string]$DirectoryName
    )

    Set-Location -Path "$HOME\i\$DirectoryName"
}
