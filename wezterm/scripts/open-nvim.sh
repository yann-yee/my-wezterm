#!/usr/bin/env bash
set -euo pipefail

nvim_bin=${1:?missing nvim binary path}
nvim_config_dir=${2:?missing nvim config dir}
file=${3:?missing file path}
shift 3

export TERM=${TERM:-xterm-256color}
export COLORTERM=${COLORTERM:-truecolor}
export XDG_CONFIG_HOME=$(dirname "$nvim_config_dir")

printf '\033[2J\033[H'
exec "$nvim_bin" "$@" "$file"
