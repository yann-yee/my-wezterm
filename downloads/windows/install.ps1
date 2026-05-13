[CmdletBinding()]
param(
	[switch]$Force,
	[string[]]$Only,
	[switch]$ListOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$script:GitHubToken = [Environment]::GetEnvironmentVariable('GH_TOKEN', 'Process')
if ([string]::IsNullOrWhiteSpace($script:GitHubToken)) {
	$script:GitHubToken = [Environment]::GetEnvironmentVariable('GITHUB_TOKEN', 'Process')
}

$script:GitHubWebHeaders = @{
	'User-Agent' = 'wezterm-config-download-script'
}

$script:GitHubApiHeaders = @{
	Accept = 'application/vnd.github+json'
	'User-Agent' = 'wezterm-config-download-script'
}

if (-not [string]::IsNullOrWhiteSpace($script:GitHubToken)) {
	$authorizationValue = "Bearer $($script:GitHubToken)"
	$script:GitHubWebHeaders.Authorization = $authorizationValue
	$script:GitHubApiHeaders.Authorization = $authorizationValue
}

$script:ReleaseCache = @{}
$script:SharedManifestRoot = Join-Path (Split-Path -Parent $PSScriptRoot) 'shared'

function Split-OnlyIds {
	param(
		[string[]]$Values
	)

	$ids = @()
	foreach ($value in $Values) {
		if ([string]::IsNullOrWhiteSpace($value)) {
			continue
		}

		$ids += $value.Split(',') | ForEach-Object { $_.Trim().ToLowerInvariant() } | Where-Object { $_ -ne '' }
	}

	return $ids
}

function Get-TargetArchitecture {
	$processArchitecture = [Environment]::GetEnvironmentVariable('PROCESSOR_ARCHITECTURE', 'Process')
	$machineArchitecture = [Environment]::GetEnvironmentVariable('PROCESSOR_ARCHITEW6432', 'Process')
	$architecture = @($machineArchitecture, $processArchitecture) |
		Where-Object { $_ } |
		Select-Object -First 1

	if ($architecture -and $architecture.ToLowerInvariant() -eq 'arm64') {
		return 'arm64'
	}

	return 'x64'
}

function Get-LatestRelease {
	param(
		[Parameter(Mandatory = $true)]
		[string]$Repository
	)

	if (-not $script:ReleaseCache.ContainsKey($Repository)) {
		if (-not [string]::IsNullOrWhiteSpace($script:GitHubToken)) {
			try {
				$releaseUri = "https://api.github.com/repos/$Repository/releases/latest"
				$script:ReleaseCache[$Repository] = Invoke-RestMethod -Uri $releaseUri -Headers $script:GitHubApiHeaders
			}
			catch {
				$script:ReleaseCache[$Repository] = Get-LatestReleaseFromPage -Repository $Repository
			}
		}
		else {
			$script:ReleaseCache[$Repository] = Get-LatestReleaseFromPage -Repository $Repository
		}
	}

	return $script:ReleaseCache[$Repository]
}

function Get-LatestReleaseFromPage {
	param(
		[Parameter(Mandatory = $true)]
		[string]$Repository
	)

	$releasePageUri = "https://github.com/$Repository/releases/latest"
	$response = Invoke-WebRequest -Uri $releasePageUri -Headers $script:GitHubWebHeaders -UseBasicParsing
	$releaseTag = Split-Path -Leaf $response.BaseResponse.ResponseUri.AbsolutePath
	$expandedAssetsUri = "https://github.com/$Repository/releases/expanded_assets/$releaseTag"
	$assetsResponse = Invoke-WebRequest -Uri $expandedAssetsUri -Headers $script:GitHubWebHeaders -UseBasicParsing
	$escapedRepository = [regex]::Escape($Repository)
	$assetPattern = 'href="(?<href>/{0}/releases/download/[^"]+)"' -f $escapedRepository
	$matches = [regex]::Matches($assetsResponse.Content, $assetPattern)

	if ($matches.Count -eq 0) {
		throw "Could not parse release assets from $expandedAssetsUri"
	}

	$assetsByName = @{}
	foreach ($match in $matches) {
		$relativeUrl = [System.Net.WebUtility]::HtmlDecode($match.Groups['href'].Value)
		$assetUrl = "https://github.com$relativeUrl"
		$assetUri = [System.Uri]$assetUrl
		$fileName = [System.Uri]::UnescapeDataString($assetUri.Segments[$assetUri.Segments.Count - 1].Trim('/'))

		if (-not $assetsByName.ContainsKey($fileName)) {
			$assetsByName[$fileName] = [pscustomobject]@{
				name = $fileName
				browser_download_url = $assetUrl
			}
		}
	}

	return [pscustomobject]@{
		html_url = $response.BaseResponse.ResponseUri.AbsoluteUri
		assets = @($assetsByName.Values)
	}
}

function Resolve-Asset {
	param(
		[Parameter(Mandatory = $true)]
		[pscustomobject]$Item
	)

	if (($Item.PSObject.Properties.Name -contains 'Url') -and -not [string]::IsNullOrWhiteSpace($Item.Url)) {
		return [pscustomobject]@{
			Id = $Item.Id
			Name = $Item.Name
			Category = $Item.Category
			Required = $Item.Required
			Note = $Item.Note
			FileName = $Item.FileName
			Url = $Item.Url
			Source = $Item.Url
		}
	}

	$release = Get-LatestRelease -Repository $Item.Repository
	$asset = $release.assets | Where-Object { $_.name -match $Item.AssetPattern } | Select-Object -First 1

	if (-not $asset) {
		throw "Could not find an asset for '$($Item.Name)' in $($Item.Repository) matching pattern '$($Item.AssetPattern)'."
	}

	return [pscustomobject]@{
		Id = $Item.Id
		Name = $Item.Name
		Category = $Item.Category
		Required = $Item.Required
		Note = $Item.Note
		FileName = $asset.name
		Url = $asset.browser_download_url
		Source = $release.html_url
	}
}

function Save-Asset {
	param(
		[Parameter(Mandatory = $true)]
		[pscustomobject]$Asset,

		[Parameter(Mandatory = $true)]
		[string]$DestinationRoot,

		[Parameter(Mandatory = $true)]
		[bool]$Overwrite
	)

	$categoryDirectory = Join-Path $DestinationRoot $Asset.Category
	if (-not (Test-Path -LiteralPath $categoryDirectory)) {
		New-Item -ItemType Directory -Path $categoryDirectory | Out-Null
	}

	$destinationPath = Join-Path $categoryDirectory $Asset.FileName
	if ((-not $Overwrite) -and (Test-Path -LiteralPath $destinationPath)) {
		Write-Host "[skip] $($Asset.Name) -> $destinationPath"
		return
	}

	Write-Host "[downloading] $($Asset.Name)"
	Write-Host "  -> $destinationPath"
	Invoke-WebRequest -Uri $Asset.Url -Headers $script:GitHubWebHeaders -OutFile $destinationPath -UseBasicParsing
}

function New-ItemDefinition {
	param(
		[Parameter(Mandatory = $true)]
		[string]$Id,

		[Parameter(Mandatory = $true)]
		[string]$Name,

		[Parameter(Mandatory = $true)]
		[string]$Category,

		[Parameter(Mandatory = $true)]
		[bool]$Required,

		[string]$Repository,
		[string]$AssetPattern,
		[string]$Url,
		[string]$FileName,
		[string]$Note
	)

	return [pscustomobject]@{
		Id = $Id
		Name = $Name
		Category = $Category
		Required = $Required
		Repository = $Repository
		AssetPattern = $AssetPattern
		Url = $Url
		FileName = $FileName
		Note = $Note
	}
}

function Get-ManifestItemDefinitions {
	param(
		[Parameter(Mandatory = $true)]
		[string]$ManifestPath,

		[Parameter(Mandatory = $true)]
		[ValidateSet('plugins', 'archives')]
		[string]$Kind,

		[string]$Category
	)

	if (-not (Test-Path -LiteralPath $ManifestPath)) {
		return @()
	}

	$items = Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json
	if (-not $items) {
		return @()
	}

	$definitions = @()
	foreach ($item in $items) {
		if ($Kind -eq 'plugins') {
			if ([string]::IsNullOrWhiteSpace($item.name) -or [string]::IsNullOrWhiteSpace($item.repository) -or [string]::IsNullOrWhiteSpace($item.commit)) {
				continue
			}

			$safeId = ('lazyvim-plugin-' + ($item.name.ToLowerInvariant() -replace '[^a-z0-9]+', '-')).Trim('-')
			$definitions += New-ItemDefinition -Id $safeId -Name ("LazyVim plugin {0}" -f $item.name) -Category 'editor-plugins' -Required $false -Url ("https://codeload.github.com/{0}/zip/{1}" -f $item.repository, $item.commit) -FileName ("{0}-{1}.zip" -f $item.name, $item.commit) -Note 'Portable LazyVim plugin snapshot'
			continue
		}

		if ([string]::IsNullOrWhiteSpace($item.id) -or [string]::IsNullOrWhiteSpace($item.name) -or [string]::IsNullOrWhiteSpace($item.url) -or [string]::IsNullOrWhiteSpace($item.fileName)) {
			continue
		}

		$definitions += New-ItemDefinition -Id $item.id -Name $item.name -Category $Category -Required $false -Url $item.url -FileName $item.fileName -Note $item.note
	}

	return $definitions
}

$architecture = Get-TargetArchitecture
$isArm64 = $architecture -eq 'arm64'

$items = @(
	(New-ItemDefinition -Id 'wezterm' -Name 'WezTerm' -Category 'terminal' -Required $true -Repository 'wezterm/wezterm' -AssetPattern '^WezTerm-windows-.*\.zip$' -Note 'WezTerm portable archive'),
	(New-ItemDefinition -Id 'git-bash' -Name 'Git Bash' -Category 'shell' -Required $true -Repository 'git-for-windows/git' -AssetPattern ($(if ($isArm64) { '^Git-.*-arm64\.exe$' } else { '^Git-.*-64-bit\.exe$' })) -Note 'Git for Windows with Git Bash'),
	(New-ItemDefinition -Id 'neovim' -Name 'Neovim' -Category 'editor' -Required $true -Repository 'neovim/neovim' -AssetPattern ($(if ($isArm64) { '^nvim-win-arm64\.zip$' } else { '^nvim-win64\.zip$' })) -Note 'LazyVim depends on Neovim'),
	(New-ItemDefinition -Id 'lazyvim-starter' -Name 'LazyVim Starter' -Category 'editor' -Required $true -Url 'https://codeload.github.com/LazyVim/starter/zip/refs/heads/main' -FileName 'LazyVim-starter-main.zip' -Note 'Starter template for LazyVim'),
	(New-ItemDefinition -Id 'lazy-nvim' -Name 'lazy.nvim' -Category 'editor' -Required $true -Url 'https://codeload.github.com/folke/lazy.nvim/zip/refs/heads/main' -FileName 'lazy.nvim-main.zip' -Note 'Local plugin manager for offline LazyVim bootstrap'),
	(New-ItemDefinition -Id 'ripgrep' -Name 'ripgrep' -Category 'search' -Required $true -Repository 'BurntSushi/ripgrep' -AssetPattern ($(if ($isArm64) { '^ripgrep-.*-aarch64-pc-windows-msvc\.zip$' } else { '^ripgrep-.*-x86_64-pc-windows-msvc\.zip$' })) -Note 'Used by LazyVim for live grep'),
	(New-ItemDefinition -Id 'fd' -Name 'fd' -Category 'search' -Required $true -Repository 'sharkdp/fd' -AssetPattern ($(if ($isArm64) { '^fd-v.*-aarch64-pc-windows-msvc\.zip$' } else { '^fd-v.*-x86_64-pc-windows-msvc\.zip$' })) -Note 'Used by LazyVim for file search'),
	(New-ItemDefinition -Id 'yazi' -Name 'yazi' -Category 'tools' -Required $true -Repository 'sxyazi/yazi' -AssetPattern ($(if ($isArm64) { '^yazi-aarch64-pc-windows-msvc\.zip$' } else { '^yazi-x86_64-pc-windows-msvc\.zip$' })) -Note 'Terminal file manager'),
	(New-ItemDefinition -Id 'lazygit' -Name 'lazygit' -Category 'tools' -Required $true -Repository 'jesseduffield/lazygit' -AssetPattern ($(if ($isArm64) { '^lazygit_.*_Windows_arm64\.zip$' } else { '^lazygit_.*_Windows_x86_64\.zip$' })) -Note 'Terminal Git UI'),
	(New-ItemDefinition -Id 'starship' -Name 'Starship' -Category 'shell' -Required $true -Repository 'starship/starship' -AssetPattern ($(if ($isArm64) { '^starship-aarch64-pc-windows-msvc\.zip$' } else { '^starship-x86_64-pc-windows-msvc\.zip$' })) -Note 'Shell prompt binary'),
	(New-ItemDefinition -Id 'ble-sh' -Name 'ble.sh' -Category 'shell' -Required $false -Repository 'akinomyoga/ble.sh' -AssetPattern '^ble-.*\.tar\.xz$' -Note 'Bash autosuggestions and syntax highlighting'),
	(New-ItemDefinition -Id 'jetbrainsmono-nerd-font' -Name 'JetBrains Mono Nerd Font' -Category 'fonts' -Required $true -Repository 'ryanoasis/nerd-fonts' -AssetPattern '^JetBrainsMono\.zip$' -Note 'Recommended icon font for WezTerm and LazyVim'),
	(New-ItemDefinition -Id 'bat' -Name 'bat' -Category 'tools' -Required $true -Repository 'sharkdp/bat' -AssetPattern ($(if ($isArm64) { '^bat-v.*-aarch64-pc-windows-msvc\.zip$' } else { '^bat-v.*-x86_64-pc-windows-msvc\.zip$' })) -Note 'Syntax-highlighting pager')
)

if (-not $isArm64) {
	$items += New-ItemDefinition -Id 'eza' -Name 'eza' -Category 'tools' -Required $true -Repository 'eza-community/eza' -AssetPattern '^eza\.exe_x86_64-pc-windows-gnu\.zip$' -Note 'Modern ls replacement'
}

$items += Get-ManifestItemDefinitions -ManifestPath (Join-Path $script:SharedManifestRoot 'lazyvim-plugins.json') -Kind plugins
$items += Get-ManifestItemDefinitions -ManifestPath (Join-Path $script:SharedManifestRoot 'mason-packages.json') -Kind archives -Category 'editor-mason'
$items += Get-ManifestItemDefinitions -ManifestPath (Join-Path $script:SharedManifestRoot 'treesitter-parsers.json') -Kind archives -Category 'editor-parsers'

$selectedItems = $items
if ($Only -and $Only.Count -gt 0) {
	$selectedIds = Split-OnlyIds -Values $Only
	$selectedItems = $selectedItems | Where-Object { $selectedIds -contains $_.Id.ToLowerInvariant() }

	if (-not $selectedItems) {
		$availableIds = $items.Id | Sort-Object
		throw "No download targets matched -Only. Available ids: $($availableIds -join ', ')"
	}
}

Write-Host 'Preparing Windows resource downloads for a WezTerm + LazyVim setup.'
Write-Host 'This script downloads the terminal workflow assets, including Git Bash on Windows.'
Write-Host 'LazyVim is a preconfigured Neovim distribution, so the Neovim archive remains part of the default set, and portable plugin archives are resolved from downloads/shared manifests.'
Write-Host "Detected architecture: $architecture"

$resolvedAssets = foreach ($item in $selectedItems) {
	Resolve-Asset -Item $item
}

if ($ListOnly) {
	$resolvedAssets |
		Select-Object Id, Name, Category, FileName, Url, Note |
		Format-Table -AutoSize |
		Out-String |
		Write-Host
	return
}

foreach ($asset in $resolvedAssets) {
	Save-Asset -Asset $asset -DestinationRoot $PSScriptRoot -Overwrite $Force.IsPresent
}

Write-Host ''
Write-Host 'Download complete.'
Write-Host 'Default set:'
Write-Host '  WezTerm, Git Bash, Neovim, LazyVim Starter, lazy.nvim, ripgrep, fd, yazi, lazygit, Starship, optional ble.sh, JetBrains Mono Nerd Font, bat, and eza on x64.'
Write-Host 'Optional set from manifests:'
Write-Host '  Portable LazyVim plugin archives, plus Mason and Treesitter archives when entries exist in downloads/shared.'
