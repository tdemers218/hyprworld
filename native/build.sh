#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "$0")"
output_dir="${1:-$PWD/build}"
mkdir -p -- "$output_dir"
output_dir=$(cd -- "$output_dir" && pwd)
command -v c++ >/dev/null || { echo 'Hyprworld: install a C++23 compiler' >&2; exit 1; }
command -v pkg-config >/dev/null || { echo 'Hyprworld: install pkg-config' >&2; exit 1; }
pkg-config --exists hyprland || { echo 'Hyprworld: matching Hyprland development headers are required' >&2; exit 1; }
read -r -a flags <<< "$(pkg-config --cflags hyprland)"
fingerprint=$({
  sha256sum shared-workspaces.cpp build.sh
  pkg-config --modversion hyprland
  printf '%s\n' "${flags[@]}"
  c++ --version
  c++ "${flags[@]}" -dM -E -x c++ -include hyprland/src/version.h /dev/null
} | sha256sum | cut -d ' ' -f 1)
exec 9>"$output_dir/.build.lock"
flock -w 30 9 || { echo "Hyprworld: native build is busy; retry later" >&2; exit 1; }
if [[ -s "$output_dir/shared-workspaces.so" && -f "$output_dir/build.sha256" ]] &&
   [[ $(<"$output_dir/build.sha256") == "$fingerprint" ]]; then
  exit 0
fi
build_tmp=$(mktemp "$output_dir/.shared-workspaces.XXXXXX.so")
trap 'rm -f -- "$build_tmp"' EXIT
c++ -std=c++23 -shared -fPIC -O2 -Wall -Wextra "${flags[@]}" shared-workspaces.cpp -o "$build_tmp"
mv -f -- "$build_tmp" "$output_dir/shared-workspaces.so"
printf '%s\n' "$fingerprint" > "$output_dir/build.sha256"
