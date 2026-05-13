#!/usr/bin/env bash

set -euo pipefail

force=0
list_only=0
declare -a only_ids=()
declare -A release_cache=()
declare -A release_page_cache=()
declare -A release_tag_cache=()
github_token="${GH_TOKEN:-${GITHUB_TOKEN:-}}"

usage() {
	cat <<'EOF'
Usage: ./install.sh [--force] [--list-only] [--only id1,id2]

This script downloads Linux assets for the WezTerm + LazyVim workflow.
It intentionally does not download Bash.
EOF
}

while [[ $# -gt 0 ]]; do
	case "$1" in
		--force)
			force=1
			shift
			;;
		--list-only)
			list_only=1
			shift
			;;
		--only)
			shift
			if [[ $# -eq 0 ]]; then
				echo "--only requires at least one id" >&2
				exit 1
			fi
			IFS=',' read -r -a chunk <<< "$1"
			for item in "${chunk[@]}"; do
				item="$(printf '%s' "$item" | tr '[:upper:]' '[:lower:]' | xargs)"
				if [[ -n "$item" ]]; then
					only_ids+=("$item")
				fi
			done
			shift
			;;
		--help|-h)
			usage
			exit 0
			;;
		*)
			echo "Unknown argument: $1" >&2
			usage >&2
			exit 1
			;;
	esac
done

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
shared_manifest_dir="$(cd "$script_dir/../shared" && pwd)"

web_curl_args=(-fsSL -H 'User-Agent: wezterm-config-download-script')
api_curl_args=(-fsSL -H 'Accept: application/vnd.github+json' -H 'User-Agent: wezterm-config-download-script')

if [[ -n "$github_token" ]]; then
	web_curl_args+=(-H "Authorization: Bearer $github_token")
	api_curl_args+=(-H "Authorization: Bearer $github_token")
fi

if ! command -v curl >/dev/null 2>&1; then
	echo "curl is required" >&2
	exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
	echo "python3 is required" >&2
	exit 1
fi

case "$(uname -m)" in
	x86_64|amd64)
		architecture="x64"
		;;
	aarch64|arm64)
		architecture="arm64"
		;;
	*)
		echo "Unsupported architecture: $(uname -m)" >&2
		exit 1
		;;
esac

get_latest_release_json() {
	local repo="$1"

	if [[ -z "${release_cache[$repo]+x}" ]]; then
		release_cache[$repo]="$(curl "${api_curl_args[@]}" "https://api.github.com/repos/$repo/releases/latest")"
	fi

	printf '%s' "${release_cache[$repo]}"
}

get_latest_release_page() {
	local repo="$1"

	if [[ -z "${release_page_cache[$repo]+x}" ]]; then
		local tag
		tag="$(get_latest_release_tag "$repo")"
		release_page_cache[$repo]="$(curl "${web_curl_args[@]}" "https://github.com/$repo/releases/expanded_assets/$tag")"
	fi

	printf '%s' "${release_page_cache[$repo]}"
}

get_latest_release_tag() {
	local repo="$1"

	if [[ -z "${release_tag_cache[$repo]+x}" ]]; then
		local effective_url
		effective_url="$(curl "${web_curl_args[@]}" -o /dev/null -w '%{url_effective}' "https://github.com/$repo/releases/latest")"
		release_tag_cache[$repo]="${effective_url##*/}"
	fi

	printf '%s' "${release_tag_cache[$repo]}"
}

resolve_release_asset() {
	local repo="$1"
	local pattern="$2"
	local json
	if [[ -n "$github_token" ]]; then
		if json="$(get_latest_release_json "$repo" 2>/dev/null)"; then
			if RELEASE_JSON="$json" python3 - "$pattern" <<'PY'
import json
import os
import re
import sys

pattern = re.compile(sys.argv[1])
release = json.loads(os.environ['RELEASE_JSON'])

for asset in release.get('assets', []):
		name = asset.get('name', '')
		if pattern.search(name):
				print(name)
				print(asset.get('browser_download_url', ''))
				print(release.get('html_url', ''))
				raise SystemExit(0)

raise SystemExit(1)
PY
			then
				return 0
			fi
		fi
	fi

	local page
	page="$(get_latest_release_page "$repo")"

	RELEASE_HTML="$page" python3 - "$repo" "$pattern" <<'PY'
import html
import os
import re
import sys

repo = sys.argv[1]
pattern = re.compile(sys.argv[2])
content = os.environ['RELEASE_HTML']
asset_regex = re.compile(r'href="(?P<href>/' + re.escape(repo) + r'/releases/download/[^"]+)"')

for match in asset_regex.finditer(content):
	href = html.unescape(match.group('href'))
	url = 'https://github.com' + href
	name = href.rsplit('/', 1)[-1]
	if pattern.search(name):
		print(name)
		print(url)
		print(f'https://github.com/{repo}/releases/latest')
		raise SystemExit(0)

raise SystemExit(1)
PY
}

make_item() {
	printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" "$5" "$6" "$7" "$8"
}

load_plugin_manifest_items() {
	local manifest_path="$1"

	if [[ ! -f "$manifest_path" ]]; then
		return 0
	fi

	if command -v cygpath >/dev/null 2>&1; then
		manifest_path="$(cygpath -w "$manifest_path")"
	fi

	MANIFEST_PATH="$manifest_path" python3 - <<'PY'
import json
import os
import re

manifest_path = os.environ['MANIFEST_PATH']
with open(manifest_path, 'r', encoding='utf-8') as handle:
	entries = json.load(handle)

for entry in entries:
	name = entry.get('name')
	repository = entry.get('repository')
	commit = entry.get('commit')
	if not name or not repository or not commit:
		continue
	safe = re.sub(r'[^a-z0-9]+', '-', name.lower()).strip('-')
	print('\t'.join([
		f'lazyvim-plugin-{safe}',
		f'LazyVim plugin {name}',
		'editor-plugins',
		'',
		'',
		f'https://codeload.github.com/{repository}/tar.gz/{commit}',
		f'{name}-{commit}.tar.gz',
		'Portable LazyVim plugin snapshot',
	]))
PY
}

load_archive_manifest_items() {
	local manifest_path="$1"
	local category="$2"

	if [[ ! -f "$manifest_path" ]]; then
		return 0
	fi

	if command -v cygpath >/dev/null 2>&1; then
		manifest_path="$(cygpath -w "$manifest_path")"
	fi

	MANIFEST_PATH="$manifest_path" CATEGORY="$category" python3 - <<'PY'
import json
import os

manifest_path = os.environ['MANIFEST_PATH']
category = os.environ['CATEGORY']
with open(manifest_path, 'r', encoding='utf-8') as handle:
	entries = json.load(handle)

for entry in entries:
	item_id = entry.get('id')
	name = entry.get('name')
	url = entry.get('url')
	file_name = entry.get('fileName')
	note = entry.get('note', '')
	if not item_id or not name or not url or not file_name:
		continue
	print('\t'.join([item_id, name, category, '', '', url, file_name, note]))
PY
}

items=()
items+=("$(make_item 'wezterm' 'WezTerm' 'terminal' 'wezterm/wezterm' "$(if [[ "$architecture" == 'arm64' ]]; then printf '%s' '^wezterm-.*\.(Ubuntu22\.04|Debian12)\.arm64\.deb$'; else printf '%s' '(^WezTerm-.*-Ubuntu20\.04\.AppImage$)|(^wezterm-.*\.(Ubuntu22\.04|Debian12)\.deb$)'; fi)" '' '' 'WezTerm Linux asset')")
items+=("$(make_item 'neovim' 'Neovim' 'editor' 'neovim/neovim' "$(if [[ "$architecture" == 'arm64' ]]; then printf '%s' '^nvim-linux-arm64\.tar\.gz$'; else printf '%s' '^nvim-linux-x86_64\.tar\.gz$'; fi)" '' '' 'LazyVim depends on Neovim')")
items+=("$(make_item 'lazyvim-starter' 'LazyVim Starter' 'editor' '' '' 'https://codeload.github.com/LazyVim/starter/tar.gz/refs/heads/main' 'LazyVim-starter-main.tar.gz' 'Starter template for LazyVim')")
items+=("$(make_item 'lazy-nvim' 'lazy.nvim' 'editor' '' '' 'https://codeload.github.com/folke/lazy.nvim/tar.gz/refs/heads/main' 'lazy.nvim-main.tar.gz' 'Local plugin manager for offline LazyVim bootstrap')")
items+=("$(make_item 'ripgrep' 'ripgrep' 'search' 'BurntSushi/ripgrep' "$(if [[ "$architecture" == 'arm64' ]]; then printf '%s' '^ripgrep-.*-aarch64-unknown-linux-(gnu|musl)\.tar\.gz$'; else printf '%s' '^ripgrep-.*-x86_64-unknown-linux-(gnu|musl)\.tar\.gz$'; fi)" '' '' 'Used by LazyVim for live grep')")
items+=("$(make_item 'fd' 'fd' 'search' 'sharkdp/fd' "$(if [[ "$architecture" == 'arm64' ]]; then printf '%s' '^fd-v.*-aarch64-unknown-linux-(gnu|musl)\.tar\.gz$'; else printf '%s' '^fd-v.*-x86_64-unknown-linux-(gnu|musl)\.tar\.gz$'; fi)" '' '' 'Used by LazyVim for file search')")
items+=("$(make_item 'yazi' 'yazi' 'tools' 'sxyazi/yazi' "$(if [[ "$architecture" == 'arm64' ]]; then printf '%s' '^yazi-aarch64-unknown-linux-(gnu|musl)\.zip$'; else printf '%s' '^yazi-x86_64-unknown-linux-(gnu|musl)\.zip$'; fi)" '' '' 'Terminal file manager')")
items+=("$(make_item 'lazygit' 'lazygit' 'tools' 'jesseduffield/lazygit' "$(if [[ "$architecture" == 'arm64' ]]; then printf '%s' '^lazygit_.*_Linux_arm64\.tar\.gz$'; else printf '%s' '^lazygit_.*_Linux_x86_64\.tar\.gz$'; fi)" '' '' 'Terminal Git UI')")
items+=("$(make_item 'starship' 'Starship' 'shell' 'starship/starship' "$(if [[ "$architecture" == 'arm64' ]]; then printf '%s' '^starship-aarch64-unknown-linux-(gnu|musl)\.tar\.gz$'; else printf '%s' '^starship-x86_64-unknown-linux-(gnu|musl)\.tar\.gz$'; fi)" '' '' 'Shell prompt binary')")
items+=("$(make_item 'jetbrainsmono-nerd-font' 'JetBrains Mono Nerd Font' 'fonts' 'ryanoasis/nerd-fonts' '^JetBrainsMono\.zip$' '' '' 'Recommended icon font for WezTerm and LazyVim')")
items+=("$(make_item 'bat' 'bat' 'tools' 'sharkdp/bat' "$(if [[ "$architecture" == 'arm64' ]]; then printf '%s' '^bat-v.*-aarch64-unknown-linux-(gnu|musl)\.tar\.gz$'; else printf '%s' '^bat-v.*-x86_64-unknown-linux-(gnu|musl)\.tar\.gz$'; fi)" '' '' 'Syntax-highlighting pager')")
items+=("$(make_item 'eza' 'eza' 'tools' 'eza-community/eza' "$(if [[ "$architecture" == 'arm64' ]]; then printf '%s' '^eza_aarch64-unknown-linux-(gnu|musl)\.zip$'; else printf '%s' '^eza_x86_64-unknown-linux-(gnu|musl)\.zip$'; fi)" '' '' 'Modern ls replacement')")

mapfile -t plugin_manifest_items < <(load_plugin_manifest_items "$shared_manifest_dir/lazyvim-plugins.json")
for plugin_item in "${plugin_manifest_items[@]}"; do
	[[ -n "$plugin_item" ]] && items+=("$plugin_item")
done

mapfile -t mason_manifest_items < <(load_archive_manifest_items "$shared_manifest_dir/mason-packages.json" 'editor-mason')
for archive_item in "${mason_manifest_items[@]}"; do
	[[ -n "$archive_item" ]] && items+=("$archive_item")
done

mapfile -t parser_manifest_items < <(load_archive_manifest_items "$shared_manifest_dir/treesitter-parsers.json" 'editor-parsers')
for archive_item in "${parser_manifest_items[@]}"; do
	[[ -n "$archive_item" ]] && items+=("$archive_item")
done

contains_only_id() {
	local candidate="$1"

	if [[ ${#only_ids[@]} -eq 0 ]]; then
		return 0
	fi

	local item
	for item in "${only_ids[@]}"; do
		if [[ "$item" == "$candidate" ]]; then
			return 0
		fi
	done

	return 1
}

save_asset() {
	local name="$1"
	local category="$2"
	local file_name="$3"
	local url="$4"

	local category_dir="$script_dir/$category"
	mkdir -p "$category_dir"

	local destination="$category_dir/$file_name"
	if [[ $force -ne 1 && -f "$destination" ]]; then
		printf '[skip] %s -> %s\n' "$name" "$destination"
		return
	fi

	printf '[downloading] %s\n' "$name"
	printf '  -> %s\n' "$destination"
	curl -fL --retry 3 --retry-delay 2 -o "$destination" "$url"
}

printf '%s\n' 'Preparing Linux resource downloads for a WezTerm + LazyVim setup.'
printf '%s\n' 'This script intentionally does not download Bash.'
printf '%s\n' 'Portable LazyVim plugin archives are resolved from downloads/shared manifests.'
printf 'Detected architecture: %s\n' "$architecture"

matched_count=0

for item in "${items[@]}"; do
	IFS=$'\t' read -r id name category repo pattern url file_name note <<< "$item"

	if ! contains_only_id "$id"; then
		continue
	fi

	matched_count=$((matched_count + 1))

	if [[ -n "$url" ]]; then
		resolved_name="$file_name"
		resolved_url="$url"
	else
		mapfile -t resolved_lines < <(resolve_release_asset "$repo" "$pattern")
		resolved_name="${resolved_lines[0]}"
		resolved_url="${resolved_lines[1]}"
	fi

	if [[ $list_only -eq 1 ]]; then
		printf '%-22s %-20s %-10s %s\n' "$id" "$name" "$category" "$resolved_name"
		continue
	fi

	save_asset "$name" "$category" "$resolved_name" "$resolved_url"
done

if [[ $matched_count -eq 0 ]]; then
	available_ids=()
	for item in "${items[@]}"; do
		IFS=$'\t' read -r id _ <<< "$item"
		available_ids+=("$id")
	done
	printf 'No download targets matched --only. Available ids: %s\n' "$(IFS=', '; echo "${available_ids[*]}")" >&2
	exit 1
fi

if [[ $list_only -eq 1 ]]; then
	exit 0
fi

printf '\nDownload complete.\n'
printf '%s\n' 'Default set: WezTerm, Neovim, LazyVim Starter, lazy.nvim, ripgrep, fd, yazi, lazygit, Starship, JetBrains Mono Nerd Font, bat, and eza.'
printf '%s\n' 'Optional set from manifests: portable LazyVim plugin archives, plus Mason and Treesitter archives when entries exist in downloads/shared.'
