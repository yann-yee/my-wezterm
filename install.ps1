param(
  [switch]$Force
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$userHome = [Environment]::GetFolderPath('UserProfile')
$configRoot = Join-Path $userHome '.wezterm-config'
$loaderPath = Join-Path $userHome '.wezterm.lua'
$downloadsRoot = Join-Path $configRoot 'downloads'
$weztermRoot = Join-Path $configRoot 'wezterm'
$repoWeztermRoot = Join-Path $repoRoot 'wezterm'
$repoDownloadsRoot = Join-Path $repoRoot 'downloads'
$sshRoot = Join-Path $userHome '.ssh'
$sshConfigPath = Join-Path $sshRoot 'config'
$sshControlMasterPath = Join-Path $sshRoot 'cm'

function Get-OfflineAsset {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Pattern,

    [string[]]$FallbackFiles = @()
  )

  $match = Get-ChildItem -LiteralPath $repoDownloadsRoot -File -Filter $Pattern -ErrorAction SilentlyContinue |
    Select-Object -First 1
  if ($match) {
    return $match.FullName
  }

  foreach ($fallbackFile in $FallbackFiles) {
    if ($fallbackFile -and (Test-Path $fallbackFile)) {
      return $fallbackFile
    }
  }

  return $null
}

$cleanInstall = $true

if (Test-Path $weztermRoot) {
  try {
    Remove-Item $weztermRoot -Recurse -Force
  } catch {
    $cleanInstall = $false
    Write-Warning "Could not fully remove $weztermRoot. Active tools may be running; updating configs in place."
  }
}

if (Test-Path $downloadsRoot) {
  Remove-Item $downloadsRoot -Recurse -Force
}

New-Item -ItemType Directory -Path $configRoot -Force | Out-Null
New-Item -ItemType Directory -Path $downloadsRoot -Force | Out-Null

if (Test-Path $loaderPath) {
  $backupPath = "$loaderPath.bak.$(Get-Date -Format 'yyyyMMddHHmmss')"
  Copy-Item $loaderPath $backupPath -Force
}

Copy-Item (Join-Path $repoRoot '.wezterm.lua') $loaderPath -Force

if ($cleanInstall) {
  Copy-Item $repoWeztermRoot $weztermRoot -Recurse -Force
} else {
  New-Item -ItemType Directory -Path $weztermRoot -Force | Out-Null
  Get-ChildItem $repoWeztermRoot | ForEach-Object {
    $destination = Join-Path $weztermRoot $_.Name
    if ($_.Name -eq 'tools' -and (Test-Path $destination)) {
      Write-Warning "Skipping tools copy because an executable may be locked. Close WezTerm/Yazi and rerun install.ps1 for a full refresh."
    } else {
      Copy-Item $_.FullName $destination -Recurse -Force
    }
  }
}

if (Test-Path $repoDownloadsRoot) {
  Copy-Item (Join-Path $repoDownloadsRoot '*') $downloadsRoot -Recurse -Force
}

$starshipInstaller = Get-OfflineAsset -Pattern 'starship-x86_64-pc-windows-msvc.msi' -FallbackFiles @(
  (Join-Path $repoRoot 'starship-x86_64-pc-windows-msvc.msi')
)
if ($starshipInstaller) {
  Copy-Item $starshipInstaller (Join-Path $downloadsRoot (Split-Path $starshipInstaller -Leaf)) -Force
}

if (-not (Get-Command starship -ErrorAction SilentlyContinue)) {
  if ($starshipInstaller) {
    Start-Process msiexec.exe -ArgumentList @('/i', $starshipInstaller, '/qn', '/norestart') -Wait
  }
}

$offlineAssetChecks = @(
  [pscustomobject]@{ Label = 'WezTerm'; Pattern = 'WezTerm-*-setup.exe' },
  [pscustomobject]@{ Label = 'Git for Windows'; Pattern = 'Git-*-64-bit.exe' },
  [pscustomobject]@{ Label = 'Neovim'; Pattern = 'nvim-win64.msi' },
  [pscustomobject]@{ Label = 'Starship'; Pattern = 'starship-x86_64-pc-windows-msvc.msi' }
)

foreach ($assetCheck in $offlineAssetChecks) {
  if (-not (Get-OfflineAsset -Pattern $assetCheck.Pattern)) {
    Write-Warning "$($assetCheck.Label) offline installer is missing from $repoDownloadsRoot"
  }
}

if (-not (Get-Command nvim -ErrorAction SilentlyContinue)) {
  $nvimInstaller = Get-OfflineAsset -Pattern 'nvim-win64.msi'
  if ($nvimInstaller) {
    Write-Warning "Neovim (nvim) was not found in PATH. Offline installer available at $nvimInstaller"
  } else {
    Write-Warning 'Neovim (nvim) was not found in PATH. Install Neovim before using the editor workflow.'
  }
}

New-Item -ItemType Directory -Path $sshRoot -Force | Out-Null
New-Item -ItemType Directory -Path $sshControlMasterPath -Force | Out-Null

$managedSshConfig = Join-Path $weztermRoot 'ssh\config'
if (Test-Path $managedSshConfig) {
  $includeLine = 'Include ~/.wezterm-config/wezterm/ssh/config'
  if (Test-Path $sshConfigPath) {
    $currentSshConfig = Get-Content -LiteralPath $sshConfigPath -Raw
    if ($currentSshConfig -notmatch [regex]::Escape($includeLine)) {
      Add-Content -LiteralPath $sshConfigPath -Value "`n$includeLine"
    }
  } else {
    Set-Content -LiteralPath $sshConfigPath -Value $includeLine -Encoding ascii
  }
}

Write-Host "Installed WezTerm config to $configRoot"
Write-Host "Loader written to $loaderPath"