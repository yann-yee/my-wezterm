param(
  [Parameter(Mandatory = $true)]
  [string]$Root,

  [Parameter(Mandatory = $true)]
  [string]$Symbol,

  [ValidateSet('Definition', 'Declaration', 'Any')]
  [string]$Target = 'Definition',

  [string]$File = '',

  [int]$Line = 0,

  [int]$Column = 0,

  [switch]$NoOpen
)

$ErrorActionPreference = 'Stop'

$scriptRoot = Split-Path -Parent $PSScriptRoot
$configRoot = if ($env:WEZTERM_CONFIG_ROOT) { $env:WEZTERM_CONFIG_ROOT } else { $scriptRoot }
$configPath = Join-Path $configRoot 'symbol-jump.json'
$cacheRoot = Join-Path $configRoot 'symbol-jump-cache'
$openInEditorScript = Join-Path $configRoot 'scripts\open-in-nvim.ps1'
$semanticResolver = Join-Path $configRoot 'scripts\resolve-symbol.py'

$defaultConfig = [pscustomobject]@{
  providers = @(
    [pscustomobject]@{
      type = 'ctags'
      name = 'ctags'
      languages = @('C', 'C++', 'Java', 'Python', 'Lua', 'JavaScript', 'TypeScript', 'Go', 'Rust', 'C#', 'CMake')
      rootMarkers = @('.git', 'compile_commands.json', 'CMakeLists.txt', 'pom.xml', 'build.gradle', 'settings.gradle', 'pyproject.toml', 'setup.py', 'package.json', 'go.mod', 'Cargo.toml')
    }
  )
}

function ConvertTo-WindowsPath {
  param([string]$Path)

  if ([string]::IsNullOrWhiteSpace($Path)) {
    return $Path
  }

  if ($Path -match '^/[A-Za-z]/') {
    $cygpath = 'C:\Program Files\Git\usr\bin\cygpath.exe'
    if (Test-Path $cygpath) {
      return (& $cygpath -w $Path).Trim()
    }
  }

  return $Path
}

function Get-PythonCommand {
  $python = Get-Command python -ErrorAction SilentlyContinue
  if ($python) {
    return @($python.Source)
  }

  $py = Get-Command py -ErrorAction SilentlyContinue
  if ($py) {
    return @($py.Source, '-3')
  }

  return $null
}

function Open-OrWriteTarget {
  param(
    [Parameter(Mandatory = $true)]
    [pscustomobject]$Match,
    [string]$Provider = ''
  )

  $parts = @($Match.Path, $Match.Line)
  if ($Match.PSObject.Properties.Name -contains 'Column' -and $Match.Column -gt 0) {
    $parts += $Match.Column
  }
  $target = $parts -join ':'

  if ($NoOpen) {
    Write-Output $target
    return
  }

  if (-not (Test-Path $openInEditorScript)) {
    throw "Neovim opener was not found: $openInEditorScript"
  }

  & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $openInEditorScript -Mode tab -Path $Match.Path -Line $Match.Line | Out-Null
  Write-Output $target
}

function Resolve-SemanticSymbol {
  param(
    [string]$ProjectRoot,
    [string]$SourceFile,
    [int]$SourceLine,
    [int]$SourceColumn,
    [string]$SymbolName,
    [string]$JumpTarget
  )

  if (-not (Test-Path $semanticResolver)) {
    return $null
  }
  if (-not $SourceFile -or $SourceLine -le 0 -or $SourceColumn -le 0) {
    return $null
  }

  $pythonCommand = @(Get-PythonCommand)
  if (-not $pythonCommand) {
    return $null
  }

  $arguments = @($semanticResolver, '--project-root', $ProjectRoot, '--file', $SourceFile, '--line', $SourceLine, '--column', $SourceColumn, '--symbol', $SymbolName, '--target', $JumpTarget)
  $pythonArguments = @()
  if ($pythonCommand.Count -gt 1) {
    $pythonArguments = $pythonCommand[1..($pythonCommand.Count - 1)]
  }

  $raw = & $pythonCommand[0] @pythonArguments @arguments 2>$null
  if ($LASTEXITCODE -ne 0 -or -not $raw) {
    return $null
  }

  try {
    $resolved = ($raw | Select-Object -Last 1) | ConvertFrom-Json
    if ($resolved -and $resolved.path -and $resolved.line) {
      $column = 0
      if ($resolved.PSObject.Properties.Name -contains 'column' -and $resolved.column) {
        $column = [int]$resolved.column
      }

      return [pscustomobject]@{
        Path = [string]$resolved.path
        Line = [int]$resolved.line
        Column = $column
        Provider = [string]$resolved.provider
      }
    }
  } catch {
    return $null
  }

  return $null
}

function Get-ProjectRoot {
  param(
    [string]$StartPath,
    [string[]]$Markers,
    [string]$HomePath
  )

  $start = (Resolve-Path -LiteralPath $StartPath).Path
  $current = $start

  while ($true) {
    foreach ($marker in $Markers) {
      if (Test-Path (Join-Path $current $marker)) {
        if ($current -eq $HomePath -and $start -ne $HomePath) {
          return $start
        }

        return $current
      }
    }

    $parent = Split-Path -Parent $current
    if ([string]::IsNullOrEmpty($parent) -or $parent -eq $current) {
      return $null
    }

    $current = $parent
  }
}

function Get-HashKey {
  param([string]$Text)

  $sha = [System.Security.Cryptography.SHA256]::Create()
  try {
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
    $hash = $sha.ComputeHash($bytes)
    return ([System.BitConverter]::ToString($hash) -replace '-', '').ToLowerInvariant()
  }
  finally {
    $sha.Dispose()
  }
}

function Load-Config {
  if (Test-Path $configPath) {
    $loaded = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
    if ($loaded -and $loaded.providers) {
      return $loaded
    }
  }

  return $defaultConfig
}

function Get-TagFile {
  param(
    [string]$ProjectRoot,
    [string[]]$Languages,
    [string]$ProviderName
  )

  New-Item -ItemType Directory -Path $cacheRoot -Force | Out-Null
  $cacheKey = Get-HashKey ($ProjectRoot + '|' + ($Languages -join ',') + '|' + $ProviderName)
  $tagFile = Join-Path $cacheRoot ($cacheKey + '.tags')

  if (-not (Test-Path $tagFile)) {
    $languageArg = ($Languages -join ',')
    & ctags -R --fields=+n --extras=+q --sort=no -f $tagFile "--languages=$languageArg" $ProjectRoot
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path $tagFile)) {
      throw "Failed to build symbol index for $ProjectRoot"
    }
  }

  return $tagFile
}

function Find-SymbolInTags {
  param(
    [string]$TagFile,
    [string]$ProjectRoot,
    [string]$SymbolName
  )

  $matches = @()

  foreach ($line in Get-Content -LiteralPath $TagFile) {
    if ($line.StartsWith('!_TAG_')) {
      continue
    }

    $columns = $line -split "`t"
    if ($columns.Count -lt 4 -or $columns[0] -ne $SymbolName) {
      continue
    }

    $lineField = $columns | Where-Object { $_ -like 'line:*' } | Select-Object -First 1
    if (-not $lineField) {
      continue
    }

    $path = $columns[1]
    if (-not [System.IO.Path]::IsPathRooted($path)) {
      $path = Join-Path $ProjectRoot $path
    }

    $resolvedPath = Resolve-Path -LiteralPath $path -ErrorAction SilentlyContinue
    if ($resolvedPath) {
      $path = $resolvedPath.Path
    }

    $kind = ''
    foreach ($column in $columns) {
      if ($column -like 'kind:*') {
        $kind = $column.Substring(5)
        break
      }
    }
    if (-not $kind -and $columns.Count -ge 4) {
      $kind = $columns[3] -replace ';"$', ''
    }

    $matches += [pscustomobject]@{
      Path = $path
      Line = [int]($lineField.Substring(5))
      Kind = $kind
    }
  }

  if ($matches.Count -eq 0) {
    return $null
  }

  $declarationKinds = @('p', 'prototype', 'declaration')
  if ($Target -eq 'Declaration') {
    $declaration = $matches | Where-Object { $declarationKinds -contains $_.Kind } | Select-Object -First 1
    if ($declaration) {
      return $declaration
    }
  }

  if ($Target -eq 'Definition') {
    $definition = $matches | Where-Object { $declarationKinds -notcontains $_.Kind } | Select-Object -First 1
    if ($definition) {
      return $definition
    }
  }

  return $matches | Select-Object -First 1
}

$config = Load-Config
$rootMarkers = @()
foreach ($provider in $config.providers) {
  foreach ($marker in $provider.rootMarkers) {
    if ($rootMarkers -notcontains $marker) {
      $rootMarkers += $marker
    }
  }
}

$Root = ConvertTo-WindowsPath $Root
$File = ConvertTo-WindowsPath $File

$projectRoot = Get-ProjectRoot -StartPath $Root -Markers $rootMarkers -HomePath ([Environment]::GetFolderPath('UserProfile'))
if (-not $projectRoot) {
  Write-Error "No project root found under $Root"
  exit 1
}

$semanticMatch = Resolve-SemanticSymbol -ProjectRoot $projectRoot -SourceFile $File -SourceLine $Line -SourceColumn $Column -SymbolName $Symbol -JumpTarget $Target
if ($semanticMatch) {
  Open-OrWriteTarget -Match $semanticMatch -Provider $semanticMatch.Provider
  exit 0
}

foreach ($provider in $config.providers) {
  if ($provider.type -ne 'ctags') {
    continue
  }

  $providerName = 'ctags'
  if ($provider.name) {
    $providerName = [string]$provider.name
  }

  $tagFile = Get-TagFile -ProjectRoot $projectRoot -Languages $provider.languages -ProviderName $providerName
  $match = Find-SymbolInTags -TagFile $tagFile -ProjectRoot $projectRoot -SymbolName $Symbol
  if ($match) {
    Open-OrWriteTarget -Match $match -Provider 'ctags'
    exit 0
  }
}

Write-Error "No $($Target.ToLowerInvariant()) found for $Symbol"
exit 1