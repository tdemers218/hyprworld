#!/usr/bin/env bash
set -eu
cd -- "$(dirname -- "$0")"
mkdir -p build
c++ -std=c++23 -shared -fPIC -O2 -Wall -Wextra $(pkg-config --cflags hyprland) shared-workspaces.cpp -o build/shared-workspaces.next.so
mv -f build/shared-workspaces.next.so build/shared-workspaces.so
