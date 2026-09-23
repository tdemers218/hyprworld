# Migrating from Hyprscroll2D / Hyprscroll 2D Max

Hyprworld is a separate plugin. It uses a new layout name, shell IPC target,
settings files, and plugin ID. The rename does not alter an already installed
copy of the old plugin. Do not enable both Omarchy integrations together: their
workspace assignments and keybindings overlap.

## 1. Preserve preferences

Before removing the old plugin, copy preferences, without
overwriting any existing Hyprworld settings:

```sh
python3 - <<'PY'
from pathlib import Path
import shutil
base = Path.home() / '.config/omarchy'
old_plugin = base / 'plugins/io.github.kirollosatef.hyprscroll2d'
for destination, candidates in (
    (base / 'hyprworld.json', [base / 'hyprscroll2d.json', old_plugin / 'customizer.json']),
):
    if destination.exists():
        print(f'Keeping existing {destination}')
        continue
    source = next((p for p in candidates if p.is_file()), None)
    if source:
        shutil.copy2(source, destination)
        print(f'Copied {source} to {destination}')
PY
```

Monitor-order files are no longer used: workspace IDs are shared on every screen.
Settings migration is explicit; Hyprworld does not consume
or modify the old plugin's preference files automatically.

## 2. Remove the old integration

Save your work and disable the previous plugin in its own settings first. If
installed as a shell plugin:

```sh
omarchy plugin remove io.github.kirollosatef.hyprscroll2d --yes
hyprctl reload
hyprctl configerrors
```

If installed with the old `install.sh`, run **that old checkout's** `uninstall.sh`
first. The new uninstaller recognizes only `-- hyprworld:start/end` markers,
not the old `-- hyprscroll2d:start/end` markers. Remove manual old `dofile` calls
and workspace rules yourself if they were not installed in a marked block.

If the previous workspace widget was manually configured, remove its old module
ID from your bar configuration. Keep the old checkout if you want a rollback.

Start a new compositor session after removing the old integration, before
enabling Hyprworld. This avoids stacking helpers with incompatible Lua APIs;
a shell/config reload alone is not a native-code replacement.

## 3. Install Hyprworld

Follow the [README](../README.md#install) using the new repository URL. Verify
settings, shared workspace numbers, and shortcuts before continuing normal work.
There is no automatic cross-plugin migration of groups or camera state. New
Hyprworld checkpoints preserve subsequent settled arrangements across resets
within the same compositor session. They do not survive the session restart
needed for native-helper migration. See [layout recovery](LAYOUT-RECOVERY.md).

| Interface | Previous fork | Hyprworld |
| --- | --- | --- |
| Plugin / widget ID | `io.github.kirollosatef.hyprscroll2d` | `io.github.tdemers218.hyprworld` |
| Layout | `lua:hyprscroll2d-v16` (older versions: `lua:hyprscroll2d`) | `lua:hyprworld` |
| Shell IPC target | `hyprscroll2d` | `hyprworld` |
| Preferences | `hyprscroll2d.json` | `hyprworld.json` |
| Checkpoints | Legacy builds may use `$XDG_STATE_HOME/hyprscroll2d/` | `$XDG_STATE_HOME/hyprworld/`; no automatic import |
| Monitor order | Legacy monitor-order files | Not used; workspace IDs are shared |
| Installer config override | `HYPRSCROLL2D_HYPRLAND_CONFIG` | `HYPRWORLD_HYPRLAND_CONFIG` |
| Installer skip reload | `HYPRSCROLL2D_SKIP_RELOAD` | `HYPRWORLD_SKIP_RELOAD` |

The Lua globals, custom events, and layer namespaces also use `hyprworld` now.
Update any external scripts or layer rules referring to old identifiers. Saved
shortcut field names such as `panLeft` and `panRight` remain compatible; those
fields select previous/next workspace.

For rollback, remove Hyprworld, reload Hyprland, then restore the previous
installation and widget. The original preference files remain intact.
