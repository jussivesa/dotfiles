# Hammerspoon Config

Window management and tiling for macOS via [Hammerspoon](https://www.hammerspoon.org/).

---

## Tiling (`tiling.lua`)

On-demand window tiling. Each physical screen is assigned a layout by UUID. Tiling is triggered manually — windows are never moved automatically.

### Configuration

In `init.lua`, require the module and assign a layout to each screen UUID:

```lua
local tiling = require('tiling')

tiling.screenLayouts[mainScreenId]     = { layout = 'deck',          peekWidth    = 1    }
tiling.screenLayouts[verticalScreenId] = { layout = 'primary_wide',  primaryRatio = 0.55 }
tiling.screenLayouts[laptopScreenId]   = { layout = 'columns' }
tiling.screenLayouts[homeScreenId]     = { layout = 'primary_stack', primaryRatio = 0.60 }
```

### Hotkeys

| Key | Action |
|-----|--------|
| `hyper + t` | Toggle tiling on the focused screen (tile if untiled, untile if tiled) |
| `hyperCtrl + t` | Tile all screens |
| `hyper + m` | Promote focused window to primary slot |
| `hyper + h` | Focus window left / deck: previous card |
| `hyper + l` | Focus window right / deck: next card |
| `hyper + k` | Focus window above |
| `hyper + j` | Focus window below |
| `hyperCmd + h/l/k/j` | Resize window; redistributes other windows when screen is tiled |

---

## Layouts

The grid is **12 × 12** columns. All layout parameters are per-screen and optional — defaults are shown below.

---

### `columns`

Divides the screen into equal vertical strips, left to right.

```
+----+----+----+
| A  | B  | C  |
+----+----+----+
```

No parameters.

```lua
tiling.screenLayouts[laptopScreenId] = { layout = 'columns' }
```

---

### `rows`

Divides the screen into equal horizontal strips, top to bottom. Well suited for portrait monitors.

```
+----------+
|    A     |
+----------+
|    B     |
+----------+
|    C     |
+----------+
```

No parameters.

```lua
tiling.screenLayouts[verticalScreenId] = { layout = 'rows' }
```

---

### `primary_stack`

Primary window occupies a wide left column; remaining windows stack in the right column. Good for landscape monitors.

```
+----------+----+
|          | B  |
| primary  +----+
|          | C  |
+----------+----+
```

| Parameter | Default | Description |
|-----------|---------|-------------|
| `primaryRatio` | `0.6` | Fraction of screen width given to the primary window |

```lua
tiling.screenLayouts[mainScreenId] = { layout = 'primary_stack', primaryRatio = 0.6 }
```

---

### `primary_wide`

Primary window occupies a tall top row; remaining windows spread across the bottom. Good for portrait monitors.

```
+-----------+
|  primary  |
+-----+-----+
|  B  |  C  |
+-----+-----+
```

| Parameter | Default | Description |
|-----------|---------|-------------|
| `primaryRatio` | `0.55` | Fraction of screen height given to the primary window |

```lua
tiling.screenLayouts[verticalScreenId] = { layout = 'primary_wide', primaryRatio = 0.55 }
```

---

### `deck`

Card-stack layout. The primary window fills most of the screen; the next window in the deck peeks in as a narrow strip on the right edge; all remaining windows are stacked invisibly behind the peek strip. Navigate through the deck with `hyper + h/l`.

```
+----------+-+
|          | |  ← peek (next card)
| primary  | |
+----------+-+
```

| Parameter | Default | Description |
|-----------|---------|-------------|
| `peekWidth` | `2` | Width of the peek strip in grid columns (grid is 12 wide) |

```lua
tiling.screenLayouts[mainScreenId] = { layout = 'deck', peekWidth = 1 }
```

**Deck navigation** (`hyper + h/l` becomes mode-aware when the focused screen is a tiled deck):

| Key | Action |
|-----|--------|
| `hyper + l` | Bring next card to primary; current primary moves to the hidden stack |
| `hyper + h` | Bring previous card to primary |

Navigation wraps around when reaching either end of the deck.

**Primary promotion in deck mode** (`hyper + m`): swaps the focused window into the current primary slot without shifting the deck cursor — useful for reordering cards without navigating.

---

## Primary promotion

`hyper + m` promotes the focused window to the primary slot:

- **`primary_stack`** — primary gets the larger left column
- **`primary_wide`** — primary gets the larger top row
- **`deck`** — focused window becomes the card facing up at the current cursor position
- **`columns` / `rows`** — no primary concept; all windows share space equally, so promotion has no visible effect on the layout (but it reorders the internal sequence)

---

## Resize + retile

On tiled screens, `hyperCtrlCmd + h/j/k/l` resizes the focused window by one grid unit and immediately redistributes the other windows to fill the remaining space:

| Layout | Behaviour |
|--------|-----------|
| `primary_stack` | Resize primary → right column fills remaining width. Resize secondary → primary keeps its width, secondary windows re-split the right column. |
| `primary_wide` | Symmetric to `primary_stack`, vertical. |
| `columns` | Resized column stays; windows to its left and right each split their remaining space equally. |
| `rows` | Symmetric to `columns`, vertical. |
| `deck` | Resize primary → peek strip width adjusts to fill the remainder. |

---

## Floating apps

These apps are never included in tiling (edit `floatingApps` in `tiling.lua` to customise):

```lua
local floatingApps = {
    'Finder', 'System Preferences', 'System Settings',
    'Activity Monitor', 'Calculator',
}
```

---

## Other hotkeys

### Window management

| Key | Action |
|-----|--------|
| `hyper + f` | Toggle fullscreen (removes from/restores to tile if applicable) |
| `hyper + c` | Centre window at a reasonable size (saves previous size) |
| `hyper + r` | Restore previous window size |
| `hyper + g` | Open grid UI for manual placement |
| `hyper + tab` | Move focused window to the next screen (fullscreen); retiles source/target if tiled |
| `hyperCtrl + tab` | Move focused window to the next screen proportionally |

### Window move (grid push / swap)

| Key | Action |
|-----|--------|
| `hyperCtrl + h/l/k/j` | Swap with adjacent tiled neighbour; falls back to grid push when not tiled |
| `hyperCtrl + ←` | Snap to left half |
| `hyperCtrl + →` | Snap to right half |
| `hyperCtrl + ↑` | Snap to top half |
| `hyperCtrl + ↓` | Snap to bottom half |

### Window resize

| Key | Action |
|-----|--------|
| `hyperCmd + h/l/k/j` | Resize window; redistributes other windows when screen is tiled |

### Mouse

| Key | Action |
|-----|--------|
| `hyper + i` | Scroll up at focused window |
| `hyper + u` | Scroll down at focused window |
| `hyper + y` | Left click at current mouse position |
| `hyper + 6/9/8/7` | Move mouse left/right/up/down |
