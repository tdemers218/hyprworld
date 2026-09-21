#!/usr/bin/env bash

set -eu

repo_dir="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
temp_dir="$(mktemp -d)"
trap 'rm -rf -- "$temp_dir"' EXIT
config_file="$temp_dir/hyprland.lua"

printf '%s\n' 'require("default.hypr.omarchy")' > "$config_file"

HYPRWORLD_HYPRLAND_CONFIG="$config_file" \
HYPRWORLD_SKIP_RELOAD=1 HYPRWORLD_SKIP_NATIVE_BUILD=1 \
  "$repo_dir/install.sh" --yes 7 >/dev/null

grep -Fq -- '-- hyprworld:start' "$config_file"
grep -Fq -- 'workspace = "7", layout = "lua:hyprworld"' "$config_file"
grep -Fq -- "local hyprworld = \"$repo_dir\"" "$config_file"
grep -Fq -- 'dofile(hyprworld .. "/layout/init.lua")' "$config_file"
grep -Fq -- 'hl.plugin.load(hyprworld .. "/native/build/shared-workspaces.so")' "$config_file"

HYPRWORLD_HYPRLAND_CONFIG="$config_file" \
HYPRWORLD_SKIP_RELOAD=1 HYPRWORLD_SKIP_NATIVE_BUILD=1 \
  "$repo_dir/uninstall.sh" --yes >/dev/null

if grep -Fq -- '-- hyprworld:start' "$config_file"; then
  printf 'installer test failed: marker survived uninstall\n' >&2
  exit 1
fi

grep -Fq -- 'require("default.hypr.omarchy")' "$config_file"
printf 'ok - installer and uninstaller\n'
