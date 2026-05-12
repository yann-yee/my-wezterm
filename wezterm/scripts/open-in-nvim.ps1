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

function Convert-ToGitBashPath {
  param([Parameter(Mandatory = $true)][string]$WindowsPath)

  $cygpath = 'C:\Program Files\Git\usr\bin\cygpath.exe'
  if (Test-Path $cygpath) {
    return (& $cygpath -u $WindowsPath).Trim()
  }

  $fullPath = [System.IO.Path]::GetFullPath($WindowsPath)
  if ($fullPath -match '^([A-Za-z]):\\(.*)$') {
    $drive = $Matches[1].ToLowerInvariant()
    $rest = $Matches[2] -replace '\\', '/'
    return "/$drive/$rest"
  }

  return ($fullPath -replace '\\', '/')
}

function Resolve-NvimExecutable {
  $command = Get-Command nvim -ErrorAction SilentlyContinue
  if ($command -and $command.Source) {
    return $command.Source
  }

  $candidates = @(
    'C:\Program Files\Neovim\bin\nvim.exe',
    (Join-Path $env:LOCALAPPDATA 'Programs\Neovim\bin\nvim.exe'),
    (Join-Path $env:USERPROFILE 'scoop\apps\neovim\current\bin\nvim.exe'),
    'C:\ProgramData\chocolatey\bin\nvim.exe'
  )

  foreach ($candidate in $candidates) {
    if ($candidate -and (Test-Path $candidate)) {
      return $candidate
    }
  }

  throw 'Neovim (nvim) was not found. Install Neovim and ensure nvim is available in PATH.'
}

$configRoot = $env:WEZTERM_CONFIG_ROOT
if (-not $configRoot) {
  $configRoot = Join-Path ([Environment]::GetFolderPath('UserProfile')) '.wezterm-config\wezterm'
}

$wezterm = 'C:\Program Files\WezTerm\wezterm.exe'
$bash = 'C:\Program Files\Git\bin\bash.exe'
$nvimExecutable = Resolve-NvimExecutable
$nvimConfigDir = Join-Path $configRoot 'nvim'
$nvimLauncher = Join-Path $configRoot 'scripts\open-nvim.sh'

if (-not (Test-Path $wezterm)) {
  throw "WezTerm executable was not found: $wezterm"
}
if (-not (Test-Path $bash)) {
  throw "Git Bash executable was not found: $bash"
}
if (-not (Test-Path $nvimConfigDir)) {
  throw "Neovim configuration directory was not found: $nvimConfigDir"
}
if (-not (Test-Path $nvimLauncher)) {
  throw "Neovim launcher was not found: $nvimLauncher"
}

$target = $Path.Trim('"')
if ($target -match '^/[A-Za-z]/') {
  $cygpath = 'C:\Program Files\Git\usr\bin\cygpath.exe'
  if (Test-Path $cygpath) {
    $target = (& $cygpath -w $target).Trim()
  }
}
$targetItem = Get-Item -LiteralPath $target -ErrorAction Stop
if ($targetItem.PSIsContainer) {
  exit 0
}

$cwd = Split-Path -Parent $targetItem.FullName
$nvimExecutableForBash = Convert-ToGitBashPath $nvimExecutable
$nvimLauncherForBash = Convert-ToGitBashPath $nvimLauncher
$nvimConfigDirForBash = Convert-ToGitBashPath $nvimConfigDir
$targetForBash = Convert-ToGitBashPath $targetItem.FullName
$nvimArgs = @($nvimLauncherForBash, $nvimExecutableForBash, $nvimConfigDirForBash, $targetForBash)
if ($Line -gt 0) {
  $nvimArgs += "+$Line"
}

if ($Mode -eq 'window') {
  & $wezterm cli spawn --new-window --cwd $cwd $bash @nvimArgs | Out-Null
} elseif ($Mode -eq 'tab') {
  & $wezterm cli spawn --cwd $cwd -- $bash @nvimArgs | Out-Null
} else {
  $splitArgs = @('cli', 'split-pane', '--right', '--percent', '70', '--cwd', $cwd)
  if ($FromTree) {
    $rightPane = [string](& $wezterm cli get-pane-direction Right 2>$null | Select-Object -First 1)
    $rightPane = $rightPane.Trim()
    if ($rightPane) {
      $splitArgs += @('--pane-id', $rightPane)
    } else {
      $splitArgs += '--top-level'
    }
  }

  $newPane = [string](& $wezterm @splitArgs -- $bash @nvimArgs | Select-Object -First 1)
  $newPane = $newPane.Trim()
  if ($newPane) {
    & $wezterm cli activate-pane --pane-id $newPane 2>$null | Out-Null
  }
}
