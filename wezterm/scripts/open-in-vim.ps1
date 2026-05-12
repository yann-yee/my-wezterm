[CmdletBinding()]
param(
  [Parameter(Mandatory = $true, Position = 0)]
  [string]$Path,

  [ValidateSet('tab', 'split', 'window')]
  [string]$Mode = 'tab',

  [int]$Line = 0,

  [switch]$FromTree
)

$ErrorActionPreference = 'Stop'

$configRoot = $env:WEZTERM_CONFIG_ROOT
if (-not $configRoot) {
  $configRoot = Join-Path ([Environment]::GetFolderPath('UserProfile')) '.wezterm-config\wezterm'
}

$nvimOpener = Join-Path $configRoot 'scripts\open-in-nvim.ps1'
if (-not (Test-Path $nvimOpener)) {
  throw "Neovim opener was not found: $nvimOpener"
}

& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $nvimOpener -Path $Path -Mode $Mode -Line $Line -FromTree:$FromTree
exit $LASTEXITCODE
