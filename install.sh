#!/usr/bin/env bash

set -eu

start_marker="-- hyprworld:start"
end_marker="-- hyprworld:end"
workspace="${1:-9}"
config_file="${HYPRWORLD_HYPRLAND_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/hypr/hyprland.lua}"
repo_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"

case "$workspace" in
  ''|*[!0-9]*)
    printf 'Error: workspace must be a positive number.\n' >&2
    exit 1
    ;;
esac

if [ "$workspace" -lt 1 ]; then
  printf 'Error: workspace must be a positive number.\n' >&2
  exit 1
fi

if [ ! -f "$config_file" ]; then
  printf 'Error: Omarchy Hyprland config not found at %s\n' "$config_file" >&2
  exit 1
fi

if ! grep -q 'default.hypr.omarchy' "$config_file"; then
  printf 'Error: this installer currently supports Omarchy only.\n' >&2
  printf 'Generic Hyprland users can load layout/init.lua and provide custom bindings.\n' >&2
  exit 1
fi

if grep -Fq -- "$start_marker" "$config_file"; then
  printf 'Hyprworld is already configured in %s\n' "$config_file"
  exit 0
fi

if grep -q 'hyprworld/layout/init.lua' "$config_file"; then
  printf 'Error: an unmarked Hyprworld setup already exists in %s\n' "$config_file" >&2
  printf 'Remove the old Hyprworld lines before running this installer.\n' >&2
  exit 1
fi

case "$repo_dir" in
  *$'\n'*|*$'\r'*)
    printf 'Error: the repository path cannot contain a newline.\n' >&2
    exit 1
    ;;
esac

escaped_repo=${repo_dir//\\/\\\\}
escaped_repo=${escaped_repo//\"/\\\"}
if [ "${HYPRWORLD_SKIP_NATIVE_BUILD:-0}" != "1" ]; then bash "$repo_dir/native/build.sh"; fi
timestamp="$(date +%Y%m%d%H%M%S)"
backup_file="${config_file}.hyprworld.bak.${timestamp}"
before_errors=""

if command -v hyprctl >/dev/null 2>&1 && [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
  before_errors="$(hyprctl configerrors 2>/dev/null || true)"
fi

cp -p -- "$config_file" "$backup_file"

{
  printf '\n%s\n' "$start_marker"
  printf 'do\n'
  printf '  local hyprworld = "%s"\n' "$escaped_repo"
  printf '  hl.plugin.load(hyprworld .. "/native/build/shared-workspaces.so")\n'
  printf '  dofile(hyprworld .. "/layout/init.lua")\n'
  printf '  dofile(hyprworld .. "/integration/omarchy.lua")\n'
  printf '  hl.workspace_rule({ workspace = "%s", layout = "lua:hyprworld" })\n' "$workspace"
  printf 'end\n'
  printf '%s\n' "$end_marker"
} >> "$config_file"

if command -v luac >/dev/null 2>&1 && ! luac -p "$config_file"; then
  cp -p -- "$backup_file" "$config_file"
  printf 'Error: generated Lua was invalid; restored %s\n' "$backup_file" >&2
  exit 1
fi

if [ "${HYPRWORLD_SKIP_RELOAD:-0}" != "1" ] && command -v hyprctl >/dev/null 2>&1 && [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
  if ! hyprctl reload >/dev/null; then
    printf 'Warning: Hyprland could not reload. The config was installed; reload it later.\n' >&2
  else
    after_errors="$(hyprctl configerrors 2>/dev/null || true)"
    if [ -z "$before_errors" ] && [ -n "$after_errors" ]; then
      cp -p -- "$backup_file" "$config_file"
      hyprctl reload >/dev/null 2>&1 || true
      printf 'Error: Hyprland reported new config errors; restored %s\n' "$backup_file" >&2
      printf '%s\n' "$after_errors" >&2
      exit 1
    fi
  fi
fi

printf 'Installed Hyprworld with shared workspaces and explicit workspace %s.\n' "$workspace"
printf 'Config backup: %s\n' "$backup_file"
printf 'Press Super+%s, open a few windows, and use Super+Arrow to explore.\n' "$workspace"
