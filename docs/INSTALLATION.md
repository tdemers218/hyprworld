# Advanced installation

The [shell plugin installation](../README.md#install) is the supported route for
the complete interface. The alternatives below provide the Lua layout only;
they do not start the QML service, minimap, overview UI, or settings controller.
Do not combine a manual/config installation with the shell plugin bootstrap.

## Config installer on Omarchy

Clone this repository to a stable location and run its installer:

```sh
git clone https://github.com/tdemers218/hyprworld.git ~/.local/share/hyprworld
~/.local/share/hyprworld/install.sh
```

The script requires the Omarchy Lua configuration. It backs up `hyprland.lua`,
adds a marked block, validates syntax when `luac` is available, and reloads a
running Hyprland instance. If there were no errors before and the reload adds
errors, it restores the backup. Check `hyprctl configerrors` afterward.

The integration assigns five workspaces per monitor. The installer's optional
number adds an explicit workspace rule (default 9); it does **not** restrict the
plugin to that workspace:

```sh
~/.local/share/hyprworld/install.sh 8
```

Workspace rules from this option should not conflict with your monitor banks.
The layout-only route still installs bindings that reference the shell UI;
settings/overview UI requires the full shell plugin. Prefer the shell route for
normal use.

Update with:

```sh
git -C ~/.local/share/hyprworld pull --ff-only
hyprctl reload
hyprctl configerrors
```

Uninstall using the script before deleting or moving the checkout:

```sh
~/.local/share/hyprworld/uninstall.sh
```

It backs up the configuration and removes the marked block. The checkout and
preferences remain available for recovery. For an alternate config file use
`HYPRWORLD_HYPRLAND_CONFIG`; `HYPRWORLD_SKIP_RELOAD=1` suppresses reloads in both
scripts. The installer's support for `XDG_CONFIG_HOME` selects the Hyprland
config only; runtime preferences currently use `~/.config/omarchy`.

## Generic Lua-configured Hyprland

The layout entry point is `layout/init.lua` and registers `lua:hyprworld`:

```lua
local hyprworld = os.getenv("HOME") .. "/.local/share/hyprworld"
dofile(hyprworld .. "/layout/init.lua")
hl.workspace_rule({ workspace = "9", layout = "lua:hyprworld" })
```

Provide your own bindings using the custom-layout API. Do not load
`integration/omarchy.lua` without Omarchy's `o` helper. This is an integration
starting point, not a verified generic installation. No standalone QML shell
is provided. The Lua preference reader defaults gracefully when settings are
absent, but the bundled user interface requires Omarchy Shell.
