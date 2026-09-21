#!/usr/bin/env bash

set -eu

start_marker="-- hyprworld:start"
end_marker="-- hyprworld:end"
yes_flag=0
config_file="${HYPRWORLD_HYPRLAND_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/hypr/hyprland.lua}"

for argument in "$@"; do
  case "$argument" in
    --yes) yes_flag=1 ;;
    *)
      printf 'Usage: %s [--yes]\n' "$0" >&2
      exit 1
      ;;
  esac
done

if [ ! -f "$config_file" ]; then
  printf 'Error: Hyprland config not found at %s\n' "$config_file" >&2
  exit 1
fi

if ! grep -Fq -- "$start_marker" "$config_file"; then
  printf 'Hyprworld is not installed in %s\n' "$config_file"
  exit 0
fi

if [ "$yes_flag" -ne 1 ]; then
  if [ ! -t 0 ] || [ ! -t 1 ]; then
    printf 'Error: removal changes %s; rerun with --yes from an explicit approval.\n' "$config_file" >&2
    exit 1
  fi
  printf 'Hyprworld will remove its marked integration block from %s and reload Hyprland. Continue? [y/N] ' "$config_file"
  read -r answer
  case "$answer" in
    y|Y|yes|YES) ;;
    *) printf 'Removal cancelled; no changes were made.\n'; exit 0 ;;
  esac
fi

timestamp="$(date +%Y%m%d%H%M%S)"
backup_file="${config_file}.hyprworld.bak.${timestamp}"
temp_file="$(mktemp "${config_file}.tmp.XXXXXX")"
trap 'rm -f -- "$temp_file"' EXIT

cp -p -- "$config_file" "$backup_file"

if ! awk -v start="$start_marker" -v finish="$end_marker" '
  $0 == start { skipping = 1; found_start = 1; next }
  $0 == finish { skipping = 0; found_end = 1; next }
  !skipping { print }
  END { if (!found_start || !found_end || skipping) exit 2 }
' "$config_file" > "$temp_file"; then
  printf 'Error: install markers are incomplete; no changes were made.\n' >&2
  exit 1
fi

chmod --reference="$config_file" "$temp_file"
mv -- "$temp_file" "$config_file"
trap - EXIT

if [ "${HYPRWORLD_SKIP_RELOAD:-0}" != "1" ] && command -v hyprctl >/dev/null 2>&1 && [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
  hyprctl reload >/dev/null || printf 'Warning: reload Hyprland manually.\n' >&2
  errors="$(hyprctl configerrors 2>/dev/null || true)"
  if [ -n "$errors" ]; then
    printf '%s\n' "$errors" >&2
  fi
fi

printf 'Removed Hyprworld from %s\n' "$config_file"
printf 'Config backup: %s\n' "$backup_file"
printf 'You may now delete the cloned repository.\n'
