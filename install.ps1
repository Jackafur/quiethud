param(
    [string]$Game = 'C:\Program Files (x86)\World of Warcraft\_classic_beta_'
)

# Copies the addon into the game's AddOns folder. Pass -Game if WoW is installed somewhere else.
$src = Join-Path $PSScriptRoot 'QuietHUD'
$dst = Join-Path $Game 'Interface\AddOns\QuietHUD'
New-Item -ItemType Directory -Path $dst -Force | Out-Null
Copy-Item (Join-Path $src '*') -Destination $dst -Force
"Installed to $dst. Fully restart WoW so it reads the addon manifest."
