#!/usr/bin/env bash

set -euo pipefail

tools_root="${WEZTERM_TOOLS_ROOT:-~/WezTerm/Tools}"

usage() {
	cat <<'EOF'
Usage: ./setup.sh [--tools-root PATH]

Install the downloaded Linux resources into a portable WezTerm + LazyVim layout.
EOF
}

while [[ $# -gt 0 ]]; do
	case "$1" in
		--tools-root)
			shift
			if [[ $# -eq 0 ]]; then
				echo "--tools-root requires a value" >&2
				exit 1
			fi
			tools_root="$1"
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

if ! command -v python3 >/dev/null 2>&1; then
	echo "python3 is required" >&2
	exit 1
fi

resolve_path() {
	python3 - "$1" <<'PY'
import os
import sys

print(os.path.abspath(os.path.expanduser(sys.argv[1])))
PY
}

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$script_dir"
tools_root="$(resolve_path "$tools_root")"
home_dir="${HOME:?HOME is required}"
config_root="$home_dir/.wezterm-config"
loader_path="$home_dir/.wezterm.lua"
wezterm_root="$config_root/wezterm"
downloads_root="$config_root/downloads"
nvim_config_root="${XDG_CONFIG_HOME:-$home_dir/.config}/nvim"
legacy_nvim_data_root="${XDG_DATA_HOME:-$home_dir/.local/share}/nvim"
nvim_managed_marker="$nvim_config_root/.wezterm-config-managed"
repo_wezterm_root="$repo_root/wezterm"
repo_downloads_root="$repo_root/downloads"
repo_lazyvim_overlay_root="$repo_wezterm_root/lazyvim"
wezterm_app_root="$(dirname "$tools_root")"
lazyvim_source="$tools_root/lazyvim"
lazy_nvim_source="$tools_root/lazy.nvim"
portable_nvim_data_root="$tools_root/nvim-data"
portable_lazy_root="$portable_nvim_data_root/lazy"
portable_mason_root="$portable_nvim_data_root/mason"
portable_site_root="$portable_nvim_data_root/site"
portable_parser_root="$portable_site_root/parser"
linux_download_root="$repo_downloads_root/linux"
linux_terminal_download_root="$linux_download_root/terminal"
linux_shell_download_root="$linux_download_root/shell"
linux_editor_download_root="$linux_download_root/editor"
linux_search_download_root="$linux_download_root/search"
linux_tools_download_root="$linux_download_root/tools"
linux_fonts_download_root="$linux_download_root/fonts"
linux_plugin_archive_root="$linux_download_root/editor-plugins"
linux_mason_archive_root="$linux_download_root/editor-mason"
linux_parser_archive_root="$linux_download_root/editor-parsers"

copy_directory_contents() {
	local source="$1"
	local destination="$2"
	shift 2
	local exclude_names=("$@")

	mkdir -p "$destination"

	shopt -s dotglob nullglob
	local entry base should_skip exclude
	for entry in "$source"/*; do
		base="${entry##*/}"
		should_skip=0
		for exclude in "${exclude_names[@]}"; do
			if [[ -n "$exclude" && "$base" == "$exclude" ]]; then
				should_skip=1
				break
			fi
		done
		if [[ $should_skip -eq 1 ]]; then
			continue
		fi
		if [[ -d "$entry" ]]; then
			mkdir -p "$destination/$base"
			cp -a "$entry"/. "$destination/$base/"
		else
			cp -a "$entry" "$destination/$base"
		fi
		done
	shopt -u dotglob nullglob
}

backup_directory_if_present() {
	local path="$1"
	local backup_prefix="$2"

	if [[ -e "$path" ]]; then
		local backup_path
		backup_path="${backup_prefix}.$(date +%Y%m%d%H%M%S)"
		mv "$path" "$backup_path"
		printf '%s\n' "$backup_path"
		return 0
	fi

	return 1
}

copy_overlay_files() {
	local source_root="$1"
	local destination_root="$2"

	if [[ ! -d "$source_root" ]]; then
		return
	fi

	while IFS= read -r -d '' file; do
		local relative_path destination_path
		relative_path="${file#"$source_root"/}"
		destination_path="$destination_root/$relative_path"
		mkdir -p "$(dirname "$destination_path")"
		cp -a "$file" "$destination_path"
		done < <(find "$source_root" -type f -print0)
}

initialize_portable_directory() {
	mkdir -p "$1"
}

directory_has_entries() {
	local path="$1"
	[[ -d "$path" ]] || return 1
	find "$path" -mindepth 1 -maxdepth 1 | read -r _
}

seed_portable_directory() {
	local source="$1"
	local destination="$2"

	if [[ ! -d "$source" ]] || directory_has_entries "$destination"; then
		return 1
	fi

	initialize_portable_directory "$destination"
	copy_directory_contents "$source" "$destination"
	return 0
}

get_first_matching_file() {
	local directory="$1"
	shift

	[[ -d "$directory" ]] || return 1

	local pattern matches best_match
	for pattern in "$@"; do
		shopt -s nullglob
		matches=("$directory"/$pattern)
		shopt -u nullglob
		if (( ${#matches[@]} > 0 )); then
			best_match="$(printf '%s\n' "${matches[@]}" | sort -r | head -n 1)"
			printf '%s\n' "$best_match"
			return 0
		fi
	done

	return 1
}

get_archive_content_root() {
	local extract_root="$1"
	shopt -s dotglob nullglob
	local entries=("$extract_root"/*)
	shopt -u dotglob nullglob

	if (( ${#entries[@]} == 1 )) && [[ -d "${entries[0]}" ]]; then
		printf '%s\n' "${entries[0]}"
		return
	fi

	printf '%s\n' "$extract_root"
}

extract_zip_archive() {
	local archive_path="$1"
	local destination_path="$2"
	python3 - "$archive_path" "$destination_path" <<'PY'
import sys
import zipfile

with zipfile.ZipFile(sys.argv[1], 'r') as archive:
    archive.extractall(sys.argv[2])
PY
}

extract_archive() {
	local archive_path="$1"
	local destination_path="$2"

	case "$archive_path" in
		*.zip)
			extract_zip_archive "$archive_path" "$destination_path"
			;;
		*.tar.gz|*.tgz|*.tar.xz|*.tar.bz2|*.tar)
			tar -xf "$archive_path" -C "$destination_path"
			;;
		*)
			echo "Unsupported archive format: $archive_path" >&2
			return 1
			;;
	esac
}

install_archive_into_directory() {
	local archive_path="$1"
	local destination="$2"
	local clear_destination="$3"

	if [[ -z "$archive_path" || ! -f "$archive_path" ]]; then
		return 1
	fi

	local temp_extract_root
	temp_extract_root="$(mktemp -d)"

	trap 'rm -rf "$temp_extract_root"' RETURN
	extract_archive "$archive_path" "$temp_extract_root"
	local source_root
	source_root="$(get_archive_content_root "$temp_extract_root")"

	if [[ "$clear_destination" == "1" && -e "$destination" ]]; then
		rm -rf "$destination"
	fi

	initialize_portable_directory "$destination"
	copy_directory_contents "$source_root" "$destination"
	rm -rf "$temp_extract_root"
	trap - RETURN
	return 0
}

install_wezterm_asset() {
	local archive_path="$1"
	local destination_root="$2"

	if [[ -z "$archive_path" || ! -f "$archive_path" ]]; then
		return 1
	fi

	mkdir -p "$destination_root"

	case "$archive_path" in
		*.AppImage)
			install -m 0755 "$archive_path" "$destination_root/wezterm"
			return 0
			;;
		*.deb)
			local data_member
			data_member="$(ar t "$archive_path" | awk '/^data\.tar\./ { print; exit }')"
			if [[ -z "$data_member" ]]; then
				echo "Unsupported .deb payload in $archive_path" >&2
				return 1
			fi
			rm -rf "$destination_root/wezterm-deb"
			mkdir -p "$destination_root/wezterm-deb"
			case "$data_member" in
				*.xz)
					ar p "$archive_path" "$data_member" | tar -xJ -C "$destination_root/wezterm-deb"
					;;
				*.gz)
					ar p "$archive_path" "$data_member" | tar -xz -C "$destination_root/wezterm-deb"
					;;
				*.bz2)
					ar p "$archive_path" "$data_member" | tar -xj -C "$destination_root/wezterm-deb"
					;;
				*.zst)
					ar p "$archive_path" "$data_member" | tar --zstd -x -C "$destination_root/wezterm-deb"
					;;
				*.tar)
					ar p "$archive_path" "$data_member" | tar -x -C "$destination_root/wezterm-deb"
					;;
				*)
					echo "Unsupported .deb data member: $data_member" >&2
					return 1
					;;
			esac
			return 0
			;;
		*)
			echo "Unsupported WezTerm asset: $archive_path" >&2
			return 1
			;;
	esac
}

strip_archive_extension() {
	local name="$1"
	for extension in .tar.gz .tar.xz .tar.bz2 .tgz .zip .tar; do
		if [[ "$name" == *"$extension" ]]; then
			printf '%s\n' "${name%$extension}"
			return
		fi
	done
	printf '%s\n' "${name%.*}"
}

expand_archive_directory_contents() {
	local archive_directory="$1"
	local destination_root="$2"
	local installed_count=0

	[[ -d "$archive_directory" ]] || {
		printf '%s\n' 0
		return
	}

	initialize_portable_directory "$destination_root"
	shopt -s nullglob
	local archive archive_name item_name destination_path temp_extract_root source_root
	for archive in "$archive_directory"/*.{zip,tar.gz,tgz,tar.xz,tar.bz2,tar}; do
		[[ -f "$archive" ]] || continue
		archive_name="$(basename "$archive")"
		item_name="$(strip_archive_extension "$archive_name")"
		item_name="$(printf '%s' "$item_name" | sed -E 's/-[0-9a-f]{40}$//')"
		[[ -n "$item_name" ]] || continue
		destination_path="$destination_root/$item_name"
		[[ -e "$destination_path" ]] && continue
		temp_extract_root="$(mktemp -d)"
		extract_archive "$archive" "$temp_extract_root"
		source_root="$(get_archive_content_root "$temp_extract_root")"
		copy_directory_contents "$source_root" "$destination_path"
		rm -rf "$temp_extract_root"
		installed_count=$((installed_count + 1))
	done
	shopt -u nullglob

	printf '%s\n' "$installed_count"
}

initialize_portable_directory "$wezterm_app_root"
initialize_portable_directory "$tools_root"

wezterm_archive="$(get_first_matching_file "$linux_terminal_download_root" 'WezTerm-*.AppImage' 'wezterm-*.deb' || true)"
neovim_archive="$(get_first_matching_file "$linux_editor_download_root" 'nvim-linux-*.tar.gz' || true)"
lazyvim_archive="$(get_first_matching_file "$linux_editor_download_root" 'LazyVim-starter-main.tar.gz' || true)"
lazy_nvim_archive="$(get_first_matching_file "$linux_editor_download_root" 'lazy.nvim-main.tar.gz' || true)"
ripgrep_archive="$(get_first_matching_file "$linux_search_download_root" 'ripgrep-*.tar.gz' || true)"
fd_archive="$(get_first_matching_file "$linux_search_download_root" 'fd-v*.tar.gz' || true)"
yazi_archive="$(get_first_matching_file "$linux_tools_download_root" 'yazi-*.zip' || true)"
lazygit_archive="$(get_first_matching_file "$linux_tools_download_root" 'lazygit_*_Linux_*.tar.gz' || true)"
starship_archive="$(get_first_matching_file "$linux_shell_download_root" 'starship-*.tar.gz' || true)"
font_archive="$(get_first_matching_file "$linux_fonts_download_root" 'JetBrainsMono*.zip' || true)"
bat_archive="$(get_first_matching_file "$linux_tools_download_root" 'bat-v*.tar.gz' || true)"
eza_archive="$(get_first_matching_file "$linux_tools_download_root" 'eza_*.zip' || true)"

installed_wezterm=0
installed_neovim=0
installed_lazyvim_starter=0
installed_lazy_nvim=0
installed_ripgrep=0
installed_fd=0
installed_yazi=0
installed_lazygit=0
installed_starship=0
installed_fonts=0
installed_bat=0
installed_eza=0

if install_wezterm_asset "$wezterm_archive" "$wezterm_app_root"; then installed_wezterm=1; fi
if install_archive_into_directory "$neovim_archive" "$tools_root/nvim" 1; then installed_neovim=1; fi
if install_archive_into_directory "$lazyvim_archive" "$lazyvim_source" 1; then installed_lazyvim_starter=1; fi
if install_archive_into_directory "$lazy_nvim_archive" "$lazy_nvim_source" 1; then installed_lazy_nvim=1; fi
if install_archive_into_directory "$ripgrep_archive" "$tools_root/ripgrep" 1; then installed_ripgrep=1; fi
if install_archive_into_directory "$fd_archive" "$tools_root/fd" 1; then installed_fd=1; fi
if install_archive_into_directory "$yazi_archive" "$tools_root/yazi" 1; then installed_yazi=1; fi
if install_archive_into_directory "$lazygit_archive" "$tools_root/lazygit" 1; then installed_lazygit=1; fi
if install_archive_into_directory "$starship_archive" "$tools_root/starship" 1; then installed_starship=1; fi
if install_archive_into_directory "$font_archive" "$tools_root/JetBrainsMono" 1; then installed_fonts=1; fi
if install_archive_into_directory "$bat_archive" "$tools_root/bat" 1; then installed_bat=1; fi
if install_archive_into_directory "$eza_archive" "$tools_root/eza" 1; then installed_eza=1; fi

if [[ ! -d "$lazyvim_source" ]]; then
	echo "LazyVim starter was not found. Run downloads/linux/install.sh first or place it at $lazyvim_source" >&2
	exit 1
fi

if [[ ! -d "$lazy_nvim_source" ]]; then
	echo "lazy.nvim was not found. Run downloads/linux/install.sh first or place it at $lazy_nvim_source" >&2
	exit 1
fi

mkdir -p "$config_root"
rm -rf "$wezterm_root"

cp "$repo_root/.wezterm.lua" "$loader_path"
copy_directory_contents "$repo_wezterm_root" "$wezterm_root"

if [[ -d "$repo_downloads_root" ]]; then
	rm -rf "$downloads_root"
	copy_directory_contents "$repo_downloads_root" "$downloads_root"
fi

lazyvim_backup=""
if [[ -d "$nvim_config_root" ]]; then
	if [[ -f "$nvim_managed_marker" ]]; then
		rm -rf "$nvim_config_root"
	else
		lazyvim_backup="$(backup_directory_if_present "$nvim_config_root" "$nvim_config_root.bak" || true)"
	fi
fi

copy_directory_contents "$lazyvim_source" "$nvim_config_root" '.git'
copy_overlay_files "$repo_lazyvim_overlay_root" "$nvim_config_root"

initialize_portable_directory "$portable_nvim_data_root"
initialize_portable_directory "$portable_lazy_root"
initialize_portable_directory "$portable_mason_root"
initialize_portable_directory "$portable_parser_root"

installed_plugin_archives="$(expand_archive_directory_contents "$linux_plugin_archive_root" "$portable_lazy_root")"
installed_mason_archives="$(expand_archive_directory_contents "$linux_mason_archive_root" "$portable_mason_root/packages")"
installed_parser_archives="$(expand_archive_directory_contents "$linux_parser_archive_root" "$portable_parser_root")"

seeded_lazy=0
seeded_mason=0
seeded_parsers=0
if seed_portable_directory "$legacy_nvim_data_root/lazy" "$portable_lazy_root"; then seeded_lazy=1; fi
if seed_portable_directory "$legacy_nvim_data_root/mason" "$portable_mason_root"; then seeded_mason=1; fi
if seed_portable_directory "$legacy_nvim_data_root/site/parser" "$portable_parser_root"; then seeded_parsers=1; fi

printf 'Managed by wezterm-config setup.sh\nToolsRoot=%s\n' "$tools_root" > "$nvim_managed_marker"

if [[ -n "$lazyvim_backup" ]]; then
	echo "Backed up existing Neovim config to $lazyvim_backup"
fi

echo 'Installed Linux runtime config.'
echo "Synced runtime config to $wezterm_root"
echo "Synced LazyVim starter to $nvim_config_root"
echo "Using tools from $tools_root"
echo "Portable Neovim data root: $portable_nvim_data_root"
if [[ $installed_wezterm -eq 1 ]]; then
	echo "Installed WezTerm from $wezterm_archive"
fi
if [[ $installed_neovim -eq 1 ]]; then
	echo "Installed Neovim from $neovim_archive"
fi
if [[ $installed_lazyvim_starter -eq 1 ]]; then
	echo "Installed LazyVim starter from $lazyvim_archive"
fi
if [[ $installed_lazy_nvim -eq 1 ]]; then
	echo "Installed lazy.nvim from $lazy_nvim_archive"
fi
if [[ $installed_ripgrep -eq 1 ]]; then
	echo "Installed ripgrep from $ripgrep_archive"
fi
if [[ $installed_fd -eq 1 ]]; then
	echo "Installed fd from $fd_archive"
fi
if [[ $installed_yazi -eq 1 ]]; then
	echo "Installed yazi from $yazi_archive"
fi
if [[ $installed_lazygit -eq 1 ]]; then
	echo "Installed lazygit from $lazygit_archive"
fi
if [[ $installed_starship -eq 1 ]]; then
	echo "Installed starship from $starship_archive"
fi
if [[ $installed_fonts -eq 1 ]]; then
	echo "Installed JetBrains Mono Nerd Font from $font_archive"
fi
if [[ $installed_bat -eq 1 ]]; then
	echo "Installed bat from $bat_archive"
fi
if [[ $installed_eza -eq 1 ]]; then
	echo "Installed eza from $eza_archive"
fi
if [[ $seeded_lazy -eq 1 ]]; then
	echo "Seeded portable LazyVim plugins from $legacy_nvim_data_root"
fi
if [[ $seeded_mason -eq 1 ]]; then
	echo "Seeded portable Mason data from $legacy_nvim_data_root"
fi
if [[ $seeded_parsers -eq 1 ]]; then
	echo "Seeded portable Treesitter parsers from $legacy_nvim_data_root"
fi
if [[ "$installed_plugin_archives" -gt 0 ]]; then
	echo "Installed $installed_plugin_archives plugin archive(s) into $portable_lazy_root"
fi
if [[ "$installed_mason_archives" -gt 0 ]]; then
	echo "Installed $installed_mason_archives Mason archive(s) into $portable_mason_root/packages"
fi
if [[ "$installed_parser_archives" -gt 0 ]]; then
	echo "Installed $installed_parser_archives Treesitter parser archive(s) into $portable_parser_root"
fi

echo "Loader entry written to $loader_path"
echo "Launch WezTerm from $wezterm_app_root"