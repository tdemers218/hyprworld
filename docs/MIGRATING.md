# Migrating from Hyprscroll2D / Hyprscroll 2D Max

Hyprworld is a separate plugin. It uses a new layout name, shell IPC target,
settings files, and plugin ID. The rename does not alter an already installed
copy of the old plugin. Do not enable both Omarchy integrations together: their
workspace assignments and keybindings overlap.

## 1. Preserve preferences

Before removing the old plugin, copy preferences and monitor ordering, without
overwriting any existing Hyprworld settings:

```sh
python3 - <<'PY'
from pathlib import Path
import shutil
base = Path.home() / '.config/omarchy'
old_plugin = base / 'plugins/io.github.kirollosatef.hyprscroll2d'
for destination, candidates in (
    (base / 'hyprworld.json', [base / 'hyprscroll2d.json', old_plugin / 'customizer.json']),
    (base / 'hyprworld-monitors', [base / 'hyprscroll2d-monitors']),
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

Copying monitor order preserves the relationship between connector names and
workspace ID banks. Settings migration is explicit; Hyprworld does not consume
or modify the old plugin's preference files automatically.

## 2. Remove the old integration

If installed as a shell plugin:

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

## 3. Install Hyprworld

Follow the [README](../README.md#install) using the new repository URL. Verify
settings, local workspace numbers, and shortcuts before continuing normal work.
Existing groups and camera state cannot be migrated; they reset on reload.

| Interface | Previous fork | Hyprworld |
| --- | --- | --- |
| Plugin / widget ID | `io.github.kirollosatef.hyprscroll2d` | `io.github.tdemers218.hyprworld` |
| Layout | `lua:hyprscroll2d-v16` (older versions: `lua:hyprscroll2d`) | `lua:hyprworld` |
| Shell IPC target | `hyprscroll2d` | `hyprworld` |
| Preferences | `hyprscroll2d.json` | `hyprworld.json` |
| Monitor order | `hyprscroll2d-monitors` | `hyprworld-monitors` |
| Installer config override | `HYPRSCROLL2D_HYPRLAND_CONFIG` | `HYPRWORLD_HYPRLAND_CONFIG` |
| Installer skip reload | `HYPRSCROLL2D_SKIP_RELOAD` | `HYPRWORLD_SKIP_RELOAD` |

The Lua globals, custom events, and layer namespaces also use `hyprworld` now.
Update any external scripts or layer rules referring to old identifiers. Saved
shortcut field names such as `panLeft` and `panRight` remain compatible; those
fields select previous/next workspace.

For rollback, remove Hyprworld, reload Hyprland, then restore the previous
installation and widget. The original preference files remain intact.
