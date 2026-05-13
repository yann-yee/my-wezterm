param(
  [string]$ToolsRoot = 'C:\Users\qwer\Desktop\WezTerm\Tools'
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$userHome = [Environment]::GetFolderPath('UserProfile')
$localAppData = [Environment]::GetFolderPath('LocalApplicationData')
$configRoot = Join-Path $userHome '.wezterm-config'
$loaderPath = Join-Path $userHome '.wezterm.lua'
$weztermRoot = Join-Path $configRoot 'wezterm'
$downloadsRoot = Join-Path $configRoot 'downloads'
$nvimConfigRoot = Join-Path $localAppData 'nvim'
$legacyNvimDataRoot = Join-Path $localAppData 'nvim-data'
$nvimManagedMarker = Join-Path $nvimConfigRoot '.wezterm-config-managed'
$repoWeztermRoot = Join-Path $repoRoot 'wezterm'
$repoDownloadsRoot = Join-Path $repoRoot 'downloads'
$repoLazyVimOverlayRoot = Join-Path $repoWeztermRoot 'lazyvim'
$weztermAppRoot = Split-Path -Parent $ToolsRoot
$weztermExe = Join-Path $weztermAppRoot 'wezterm.exe'
$weztermGuiExe = Join-Path $weztermAppRoot 'wezterm-gui.exe'
$lazyVimSource = Join-Path $ToolsRoot 'lazyvim'
$lazyNvimSource = Join-Path $ToolsRoot 'lazy.nvim'
$portableNvimDataRoot = Join-Path $ToolsRoot 'nvim-data'
$portableLazyRoot = Join-Path $portableNvimDataRoot 'lazy'
$portableMasonRoot = Join-Path $portableNvimDataRoot 'mason'
$portableSiteRoot = Join-Path $portableNvimDataRoot 'site'
$portableParserRoot = Join-Path $portableSiteRoot 'parser'
$windowsDownloadRoot = Join-Path $repoDownloadsRoot 'windows'
$windowsTerminalDownloadRoot = Join-Path $windowsDownloadRoot 'terminal'
$windowsShellDownloadRoot = Join-Path $windowsDownloadRoot 'shell'
$windowsEditorDownloadRoot = Join-Path $windowsDownloadRoot 'editor'
$windowsSearchDownloadRoot = Join-Path $windowsDownloadRoot 'search'
$windowsToolsDownloadRoot = Join-Path $windowsDownloadRoot 'tools'
$windowsFontsDownloadRoot = Join-Path $windowsDownloadRoot 'fonts'
$windowsPluginArchiveRoot = Join-Path $repoDownloadsRoot 'windows\editor-plugins'
$windowsMasonArchiveRoot = Join-Path $repoDownloadsRoot 'windows\editor-mason'
$windowsParserArchiveRoot = Join-Path $repoDownloadsRoot 'windows\editor-parsers'

function Copy-DirectoryContents {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Source,

    [Parameter(Mandatory = $true)]
    [string]$Destination,

    [string[]]$ExcludeNames = @()
  )

  New-Item -ItemType Directory -Path $Destination -Force | Out-Null

  Get-ChildItem -LiteralPath $Source -Force |
    Where-Object { $ExcludeNames -notcontains $_.Name } |
    ForEach-Object {
      Copy-Item -LiteralPath $_.FullName -Destination $Destination -Recurse -Force
    }
}

function Backup-DirectoryIfPresent {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path,

    [Parameter(Mandatory = $true)]
    [string]$BackupPrefix
  )

  if (Test-Path -LiteralPath $Path) {
    $backupPath = '{0}.{1}' -f $BackupPrefix, (Get-Date -Format 'yyyyMMddHHmmss')
    Move-Item -LiteralPath $Path -Destination $backupPath
    return $backupPath
  }

  return $null
}

function Copy-OverlayFiles {
  param(
    [Parameter(Mandatory = $true)]
    [string]$SourceRoot,

    [Parameter(Mandatory = $true)]
    [string]$DestinationRoot
  )

  if (-not (Test-Path -LiteralPath $SourceRoot)) {
    return
  }

  Get-ChildItem -LiteralPath $SourceRoot -Recurse -File -Force | ForEach-Object {
    $relativePath = $_.FullName.Substring($SourceRoot.Length).TrimStart('\\')
    $destinationPath = Join-Path $DestinationRoot $relativePath
    New-Item -ItemType Directory -Path (Split-Path -Parent $destinationPath) -Force | Out-Null
    Copy-Item -LiteralPath $_.FullName -Destination $destinationPath -Force
  }
}

function Initialize-PortableDirectory {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path
  )

  New-Item -ItemType Directory -Path $Path -Force | Out-Null
}

function Get-DirectoryEntryCount {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path
  )

  if (-not (Test-Path -LiteralPath $Path)) {
    return 0
  }

  return @(Get-ChildItem -LiteralPath $Path -Force).Count
}

function Seed-PortableDirectory {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Source,

    [Parameter(Mandatory = $true)]
    [string]$Destination
  )

  if ((-not (Test-Path -LiteralPath $Source)) -or (Get-DirectoryEntryCount -Path $Destination) -gt 0) {
    return $false
  }

  Initialize-PortableDirectory -Path $Destination
  Copy-DirectoryContents -Source $Source -Destination $Destination
  return $true
}

function Expand-ArchiveDirectoryContents {
  param(
    [Parameter(Mandatory = $true)]
    [string]$ArchiveDirectory,

    [Parameter(Mandatory = $true)]
    [string]$DestinationRoot,

    [Parameter(Mandatory = $true)]
    [string]$DestinationKind
  )

  if (-not (Test-Path -LiteralPath $ArchiveDirectory)) {
    return 0
  }

  Initialize-PortableDirectory -Path $DestinationRoot
  $installedCount = 0

  Get-ChildItem -LiteralPath $ArchiveDirectory -File -Filter '*.zip' | ForEach-Object {
    $pluginName = [System.IO.Path]::GetFileNameWithoutExtension($_.Name) -replace '-[0-9a-f]{40}$', ''
    if ([string]::IsNullOrWhiteSpace($pluginName)) {
      return
    }

    $destinationPath = Join-Path $DestinationRoot $pluginName
    if (Test-Path -LiteralPath $destinationPath) {
      return
    }

    $tempExtractRoot = Join-Path $env:TEMP ([System.Guid]::NewGuid().ToString())
    New-Item -ItemType Directory -Path $tempExtractRoot -Force | Out-Null

    try {
      Expand-Archive -LiteralPath $_.FullName -DestinationPath $tempExtractRoot -Force
      $topLevel = Get-ChildItem -LiteralPath $tempExtractRoot -Force | Select-Object -First 1
      if (-not $topLevel) {
        throw "Archive was empty: $($_.FullName)"
      }

      Move-Item -LiteralPath $topLevel.FullName -Destination $destinationPath
      $installedCount += 1
    }
    finally {
      if (Test-Path -LiteralPath $tempExtractRoot) {
        Remove-Item -LiteralPath $tempExtractRoot -Recurse -Force
      }
    }
  }

  return $installedCount
}

function Get-FirstMatchingFile {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Directory,

    [Parameter(Mandatory = $true)]
    [string[]]$Patterns
  )

  if (-not (Test-Path -LiteralPath $Directory)) {
    return $null
  }

  foreach ($pattern in $Patterns) {
    $match = Get-ChildItem -LiteralPath $Directory -File -Filter $pattern | Sort-Object Name -Descending | Select-Object -First 1
    if ($match) {
      return $match.FullName
    }
  }

  return $null
}

function Get-ArchiveContentRoot {
  param(
    [Parameter(Mandatory = $true)]
    [string]$ExtractRoot
  )

  $entries = @(Get-ChildItem -LiteralPath $ExtractRoot -Force)
  if ($entries.Count -eq 1 -and $entries[0].PSIsContainer) {
    return $entries[0].FullName
  }

  return $ExtractRoot
}

function Install-ZipArchiveIntoDirectory {
  param(
    [string]$ArchivePath,
    [string]$Destination,
    [switch]$ClearDestination
  )

  if ([string]::IsNullOrWhiteSpace($ArchivePath) -or (-not (Test-Path -LiteralPath $ArchivePath))) {
    return $false
  }

  $tempExtractRoot = Join-Path $env:TEMP ([System.Guid]::NewGuid().ToString())
  New-Item -ItemType Directory -Path $tempExtractRoot -Force | Out-Null

  try {
    Expand-Archive -LiteralPath $ArchivePath -DestinationPath $tempExtractRoot -Force
    $sourceRoot = Get-ArchiveContentRoot -ExtractRoot $tempExtractRoot

    if ($ClearDestination -and (Test-Path -LiteralPath $Destination)) {
      Remove-Item -LiteralPath $Destination -Recurse -Force
    }

    Initialize-PortableDirectory -Path $Destination
    Copy-DirectoryContents -Source $sourceRoot -Destination $Destination
    return $true
  }
  finally {
    if (Test-Path -LiteralPath $tempExtractRoot) {
      Remove-Item -LiteralPath $tempExtractRoot -Recurse -Force
    }
  }
}

function Install-TarArchiveIntoDirectory {
  param(
    [string]$ArchivePath,
    [string]$Destination,
    [switch]$ClearDestination
  )

  if ([string]::IsNullOrWhiteSpace($ArchivePath) -or (-not (Test-Path -LiteralPath $ArchivePath))) {
    return $false
  }

  $tarCommand = Get-Command tar.exe -ErrorAction SilentlyContinue
  if (-not $tarCommand) {
    throw 'tar.exe is required to install .tar.xz archives.'
  }

  $tempExtractRoot = Join-Path $env:TEMP ([System.Guid]::NewGuid().ToString())
  New-Item -ItemType Directory -Path $tempExtractRoot -Force | Out-Null

  try {
    & $tarCommand.Source -xf $ArchivePath -C $tempExtractRoot
    if ($LASTEXITCODE -ne 0) {
      throw "Failed to extract tar archive: $ArchivePath"
    }

    $sourceRoot = Get-ArchiveContentRoot -ExtractRoot $tempExtractRoot

    if ($ClearDestination -and (Test-Path -LiteralPath $Destination)) {
      Remove-Item -LiteralPath $Destination -Recurse -Force
    }

    Initialize-PortableDirectory -Path $Destination
    Copy-DirectoryContents -Source $sourceRoot -Destination $Destination
    return $true
  }
  finally {
    if (Test-Path -LiteralPath $tempExtractRoot) {
      Remove-Item -LiteralPath $tempExtractRoot -Recurse -Force
    }
  }
}

function Install-ZipArchiveContentsIntoDirectory {
  param(
    [string]$ArchivePath,
    [string]$Destination
  )

  if ([string]::IsNullOrWhiteSpace($ArchivePath) -or (-not (Test-Path -LiteralPath $ArchivePath))) {
    return $false
  }

  $tempExtractRoot = Join-Path $env:TEMP ([System.Guid]::NewGuid().ToString())
  New-Item -ItemType Directory -Path $tempExtractRoot -Force | Out-Null

  try {
    Expand-Archive -LiteralPath $ArchivePath -DestinationPath $tempExtractRoot -Force
    $sourceRoot = Get-ArchiveContentRoot -ExtractRoot $tempExtractRoot
    Initialize-PortableDirectory -Path $Destination
    Copy-DirectoryContents -Source $sourceRoot -Destination $Destination
    return $true
  }
  finally {
    if (Test-Path -LiteralPath $tempExtractRoot) {
      Remove-Item -LiteralPath $tempExtractRoot -Recurse -Force
    }
  }
}

function Install-GitForWindows {
  param(
    [string]$InstallerPath,
    [string]$BashPath
  )

  if (Test-Path -LiteralPath $BashPath) {
    return $false
  }

  if ([string]::IsNullOrWhiteSpace($InstallerPath) -or (-not (Test-Path -LiteralPath $InstallerPath))) {
    return $false
  }

  $process = Start-Process -FilePath $InstallerPath -ArgumentList '/VERYSILENT', '/NORESTART', '/SP-' -Wait -PassThru
  if ($process.ExitCode -ne 0) {
    throw "Git for Windows installer failed with exit code $($process.ExitCode): $InstallerPath"
  }

  if (-not (Test-Path -LiteralPath $BashPath)) {
    throw "Git Bash was still not found after installation: $BashPath"
  }

  return $true
}

function Add-UserPathEntry {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Entry
  )

  $currentPath = [Environment]::GetEnvironmentVariable('Path', 'User')
  $pathEntries = @()

  if (-not [string]::IsNullOrWhiteSpace($currentPath)) {
    $pathEntries = $currentPath -split ';' |
      Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
  }

  $normalizedEntry = $Entry.TrimEnd('\\')
  $alreadyPresent = $pathEntries |
    Where-Object { $_.TrimEnd('\\') -ieq $normalizedEntry } |
    Select-Object -First 1

  if (-not $alreadyPresent) {
    $newPath = @($normalizedEntry) + $pathEntries
    [Environment]::SetEnvironmentVariable('Path', ($newPath -join ';'), 'User')
    return $true
  }

  return $false
}

function Register-ContextMenuCommand {
  param(
    [Parameter(Mandatory = $true)]
    [string]$BaseKey,

    [Parameter(Mandatory = $true)]
    [string]$WezTermGuiPath,

    [Parameter(Mandatory = $true)]
    [string]$TargetArgument
  )

  $commandKey = Join-Path $BaseKey 'command'
  New-Item -Path $BaseKey -Force | Out-Null
  Set-ItemProperty -Path $BaseKey -Name '(default)' -Value 'Open WezTerm here'
  Set-ItemProperty -Path $BaseKey -Name 'Icon' -Value $WezTermGuiPath
  New-Item -Path $commandKey -Force | Out-Null
  Set-ItemProperty -Path $commandKey -Name '(default)' -Value ('"{0}" start --cwd "{1}"' -f $WezTermGuiPath, $TargetArgument)
}

function Register-WezTermContextMenu {
  param(
    [Parameter(Mandatory = $true)]
    [string]$WezTermGuiPath
  )

  Register-ContextMenuCommand -BaseKey 'HKCU:\Software\Classes\Directory\Background\shell\WezTerm' -WezTermGuiPath $WezTermGuiPath -TargetArgument '%V'
  Register-ContextMenuCommand -BaseKey 'HKCU:\Software\Classes\Directory\shell\WezTerm' -WezTermGuiPath $WezTermGuiPath -TargetArgument '%1'
  Register-ContextMenuCommand -BaseKey 'HKCU:\Software\Classes\Drive\shell\WezTerm' -WezTermGuiPath $WezTermGuiPath -TargetArgument '%1'
}

Initialize-PortableDirectory -Path $weztermAppRoot
Initialize-PortableDirectory -Path $ToolsRoot

$weztermArchive = Get-FirstMatchingFile -Directory $windowsTerminalDownloadRoot -Patterns @('WezTerm-windows-*.zip')
$gitInstaller = Get-FirstMatchingFile -Directory $windowsShellDownloadRoot -Patterns @('Git-*.exe')
$neovimArchive = Get-FirstMatchingFile -Directory $windowsEditorDownloadRoot -Patterns @('nvim-win*.zip')
$lazyVimArchive = Get-FirstMatchingFile -Directory $windowsEditorDownloadRoot -Patterns @('LazyVim-starter-main.zip')
$lazyNvimArchive = Get-FirstMatchingFile -Directory $windowsEditorDownloadRoot -Patterns @('lazy.nvim-*.zip')
$ripgrepArchive = Get-FirstMatchingFile -Directory $windowsSearchDownloadRoot -Patterns @('ripgrep-*.zip')
$fdArchive = Get-FirstMatchingFile -Directory $windowsSearchDownloadRoot -Patterns @('fd-*.zip')
$yaziArchive = Get-FirstMatchingFile -Directory $windowsToolsDownloadRoot -Patterns @('yazi-*.zip')
$lazygitArchive = Get-FirstMatchingFile -Directory $windowsToolsDownloadRoot -Patterns @('lazygit_*.zip')
$starshipArchive = Get-FirstMatchingFile -Directory $windowsShellDownloadRoot -Patterns @('starship-*.zip')
$bleShArchive = Get-FirstMatchingFile -Directory $windowsShellDownloadRoot -Patterns @('ble-*.tar.xz')
$fontArchive = Get-FirstMatchingFile -Directory $windowsFontsDownloadRoot -Patterns @('JetBrainsMono*.zip')
$batArchive = Get-FirstMatchingFile -Directory $windowsToolsDownloadRoot -Patterns @('bat-*.zip')
$ezaArchive = Get-FirstMatchingFile -Directory $windowsToolsDownloadRoot -Patterns @('eza*.zip')

$installedWezTerm = Install-ZipArchiveContentsIntoDirectory -ArchivePath $weztermArchive -Destination $weztermAppRoot
$installedGitBash = Install-GitForWindows -InstallerPath $gitInstaller -BashPath 'C:\Program Files\Git\bin\bash.exe'
$installedNeovim = Install-ZipArchiveIntoDirectory -ArchivePath $neovimArchive -Destination (Join-Path $ToolsRoot 'nvim') -ClearDestination
$installedLazyVimStarter = Install-ZipArchiveIntoDirectory -ArchivePath $lazyVimArchive -Destination $lazyVimSource -ClearDestination
$installedLazyNvim = Install-ZipArchiveIntoDirectory -ArchivePath $lazyNvimArchive -Destination $lazyNvimSource -ClearDestination
$installedRipgrep = Install-ZipArchiveIntoDirectory -ArchivePath $ripgrepArchive -Destination (Join-Path $ToolsRoot 'ripgrep') -ClearDestination
$installedFd = Install-ZipArchiveIntoDirectory -ArchivePath $fdArchive -Destination (Join-Path $ToolsRoot 'fd') -ClearDestination
$installedYazi = Install-ZipArchiveIntoDirectory -ArchivePath $yaziArchive -Destination (Join-Path $ToolsRoot 'yazi') -ClearDestination
$installedLazygit = Install-ZipArchiveIntoDirectory -ArchivePath $lazygitArchive -Destination (Join-Path $ToolsRoot 'lazygit') -ClearDestination
$installedStarship = Install-ZipArchiveIntoDirectory -ArchivePath $starshipArchive -Destination (Join-Path $ToolsRoot 'starship') -ClearDestination
$installedBleSh = Install-TarArchiveIntoDirectory -ArchivePath $bleShArchive -Destination (Join-Path $ToolsRoot 'ble.sh') -ClearDestination
$installedFonts = Install-ZipArchiveIntoDirectory -ArchivePath $fontArchive -Destination (Join-Path $ToolsRoot 'JetBrainsMono') -ClearDestination
$installedBat = Install-ZipArchiveIntoDirectory -ArchivePath $batArchive -Destination (Join-Path $ToolsRoot 'bat') -ClearDestination
$installedEza = Install-ZipArchiveIntoDirectory -ArchivePath $ezaArchive -Destination (Join-Path $ToolsRoot 'eza') -ClearDestination

if (-not (Test-Path -LiteralPath $lazyVimSource)) {
  throw "LazyVim starter was not found. Run downloads/windows/install.ps1 first or place it at $lazyVimSource"
}

if (-not (Test-Path -LiteralPath $lazyNvimSource)) {
  throw "lazy.nvim was not found. Run downloads/windows/install.ps1 first or place it at $lazyNvimSource"
}

if (-not (Test-Path -LiteralPath $weztermExe)) {
  throw "wezterm.exe was not found. Run downloads/windows/install.ps1 first or place WezTerm under $weztermAppRoot"
}

if (-not (Test-Path -LiteralPath $weztermGuiExe)) {
  throw "wezterm-gui.exe was not found. Run downloads/windows/install.ps1 first or place WezTerm under $weztermAppRoot"
}

New-Item -ItemType Directory -Path $configRoot -Force | Out-Null

if (Test-Path $weztermRoot) {
  Remove-Item $weztermRoot -Recurse -Force
}

Copy-Item (Join-Path $repoRoot '.wezterm.lua') $loaderPath -Force
Copy-Item $repoWeztermRoot $weztermRoot -Recurse -Force

if (Test-Path $repoDownloadsRoot) {
  if (Test-Path $downloadsRoot) {
    Remove-Item $downloadsRoot -Recurse -Force
  }

  New-Item -ItemType Directory -Path $downloadsRoot -Force | Out-Null
  Copy-Item (Join-Path $repoDownloadsRoot '*') $downloadsRoot -Recurse -Force
}

$lazyVimBackup = $null
if (Test-Path -LiteralPath $nvimConfigRoot) {
  if (Test-Path -LiteralPath $nvimManagedMarker) {
    Remove-Item -LiteralPath $nvimConfigRoot -Recurse -Force
  }
  else {
    $lazyVimBackup = Backup-DirectoryIfPresent -Path $nvimConfigRoot -BackupPrefix ($nvimConfigRoot + '.bak')
  }
}

Copy-DirectoryContents -Source $lazyVimSource -Destination $nvimConfigRoot -ExcludeNames @('.git')

Copy-OverlayFiles -SourceRoot $repoLazyVimOverlayRoot -DestinationRoot $nvimConfigRoot

Initialize-PortableDirectory -Path $portableNvimDataRoot
Initialize-PortableDirectory -Path $portableLazyRoot
Initialize-PortableDirectory -Path $portableMasonRoot
Initialize-PortableDirectory -Path $portableParserRoot

$installedPluginArchives = Expand-ArchiveDirectoryContents -ArchiveDirectory $windowsPluginArchiveRoot -DestinationRoot $portableLazyRoot -DestinationKind 'plugins'
$installedMasonArchives = Expand-ArchiveDirectoryContents -ArchiveDirectory $windowsMasonArchiveRoot -DestinationRoot (Join-Path $portableMasonRoot 'packages') -DestinationKind 'mason packages'
$installedParserArchives = Expand-ArchiveDirectoryContents -ArchiveDirectory $windowsParserArchiveRoot -DestinationRoot $portableParserRoot -DestinationKind 'treesitter parsers'

$seededLazy = Seed-PortableDirectory -Source (Join-Path $legacyNvimDataRoot 'lazy') -Destination $portableLazyRoot
$seededMason = Seed-PortableDirectory -Source (Join-Path $legacyNvimDataRoot 'mason') -Destination $portableMasonRoot
$seededParsers = Seed-PortableDirectory -Source (Join-Path $legacyNvimDataRoot 'site\parser') -Destination $portableParserRoot

Set-Content -LiteralPath $nvimManagedMarker -Value "Managed by wezterm-config setup.ps1`nToolsRoot=$ToolsRoot"

$pathUpdated = Add-UserPathEntry -Entry $weztermAppRoot
Register-WezTermContextMenu -WezTermGuiPath $weztermGuiExe

if ($lazyVimBackup) {
  Write-Host "Backed up existing Neovim config to $lazyVimBackup"
}

Write-Host 'Installed WezTerm runtime config.'
Write-Host "Synced runtime config to $weztermRoot"
Write-Host "Synced LazyVim starter to $nvimConfigRoot"
Write-Host "Using tools from $ToolsRoot"
Write-Host "Portable Neovim data root: $portableNvimDataRoot"
if ($installedWezTerm) {
  Write-Host "Installed WezTerm from $weztermArchive"
}
if ($installedGitBash) {
  Write-Host "Installed Git Bash from $gitInstaller"
}
if ($installedNeovim) {
  Write-Host "Installed Neovim from $neovimArchive"
}
if ($installedLazyVimStarter) {
  Write-Host "Installed LazyVim starter from $lazyVimArchive"
}
if ($installedLazyNvim) {
  Write-Host "Installed lazy.nvim from $lazyNvimArchive"
}
if ($installedRipgrep) {
  Write-Host "Installed ripgrep from $ripgrepArchive"
}
if ($installedFd) {
  Write-Host "Installed fd from $fdArchive"
}
if ($installedYazi) {
  Write-Host "Installed yazi from $yaziArchive"
}
if ($installedLazygit) {
  Write-Host "Installed lazygit from $lazygitArchive"
}
if ($installedStarship) {
  Write-Host "Installed starship from $starshipArchive"
}
if ($installedFonts) {
  Write-Host "Installed JetBrains Mono Nerd Font from $fontArchive"
}
if ($installedBat) {
  Write-Host "Installed bat from $batArchive"
}
if ($installedEza) {
  Write-Host "Installed eza from $ezaArchive"
}
if ($seededLazy) {
  Write-Host "Seeded portable LazyVim plugins from $legacyNvimDataRoot"
}
if ($seededMason) {
  Write-Host "Seeded portable Mason data from $legacyNvimDataRoot"
}
if ($seededParsers) {
  Write-Host "Seeded portable Treesitter parsers from $legacyNvimDataRoot"
}
if ($installedPluginArchives -gt 0) {
  Write-Host "Installed $installedPluginArchives plugin archive(s) into $portableLazyRoot"
}
if ($installedMasonArchives -gt 0) {
  Write-Host "Installed $installedMasonArchives Mason archive(s) into $(Join-Path $portableMasonRoot 'packages')"
}
if ($installedParserArchives -gt 0) {
  Write-Host "Installed $installedParserArchives Treesitter parser archive(s) into $portableParserRoot"
}
if ($pathUpdated) {
  Write-Host "Added $weztermAppRoot to the user PATH"
}
else {
  Write-Host "$weztermAppRoot is already present in the user PATH"
}
Write-Host 'Registered Windows Explorer context menu entries for WezTerm.'