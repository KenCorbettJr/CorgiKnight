# CorgiKnight Monorepo

This repository is a monorepo that holds **two separate, self-contained Godot
4.7 games** side by side under `games/`. There is **no shared-source library**:
each game carries its own full copy of the code, scenes, materials, and assets,
so the two can evolve independently while still being able to reference each
other by relative path.

## Layout

```
CorgiKnight/
├── MONOREPO.md                      <- this document
├── README.md                       <- repo-level readme
├── icon.svg / icon.svg.import      <- original root project assets (legacy)
├── project.godot                   <- original root project (the pre-split game)
├── scenes/ scripts/ materials/     <- original root project source (legacy)
└── games/
    ├── corgiknight-adventure/      <- Game 1: the island-to-island adventure
    │   ├── project.godot           config/name="CorgiKnight"
    │   ├── icon.svg + icon.svg.import
    │   ├── scenes/   (47 .tscn)
    │   ├── scripts/  (37 .gd + .uid)
    │   └── materials/(50 .tres)
    └── corgiknight-mansion/        <- Game 2: standalone Haunted Mansion roguelike (scaffold)
        ├── project.godot           config/name="CorgiKnight Haunted Mansion"
        ├── icon.svg + icon.svg.import
        ├── scenes/   (47 .tscn)
        ├── scripts/  (37 .gd + .uid)
        └── materials/(50 .tres)
```

> The original project files still live at the repo root. They are the historic
> `main` game and are kept intact for history and reference. The two runnable
> games live under `games/`. A later cleanup may retire the root copy once both
> game folders are the canonical entry points.

## The two games

### `games/corgiknight-adventure/`
A complete, runnable copy of the current `main` game — the island-to-island
corgi adventure (title screen, main island, forest island, cave, haunted island,
bosses, shops, equipment, the Ghost Sucker, etc.). Its `project.godot` keeps the
original configuration:

- `config/name = "CorgiKnight"`
- `run/main_scene = "res://scenes/title.tscn"`
- autoloads: `InputSetup = *res://scripts/input_setup.gd`, `Game = *res://scripts/game_state.gd`

This directory is a byte-for-byte duplicate of the root game's source as it
exists on `main` today.

### `games/corgiknight-mansion/`
A complete, runnable copy scaffolded from the **same** `main` code, intended to
become the standalone Haunted Mansion roguelike. Today it is identical to the
adventure copy except for its project identity — it is the starting point, not
the finished roguelike. A later task converts its content into the real
roguelike. Its `project.godot` is given a distinct identity:

- `config/name = "CorgiKnight Haunted Mansion"`
- `config/description = "Standalone Haunted Mansion roguelike, scaffolded from the CorgiKnight adventure base."`
- `run/main_scene = "res://scenes/title.tscn"` (same boot entry for now)
- autoloads: same as the adventure copy

## How each game boots

Every game is a self-contained Godot project rooted at its own folder, so all
`res://` paths resolve **inside that folder**. There are no absolute or
cross-folder paths in the source. Open either folder directly in the Godot
editor, or boot from the command line:

```sh
# Import/boot the adventure
godot --headless --path games/corgiknight-adventure --quit

# Import/boot the mansion
godot --headless --path games/corgiknight-mansion --quit
```

On macOS the Godot binary lives inside the app bundle, e.g.:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path games/corgiknight-adventure --quit
```

Both projects import their assets, generate script classes, and run their main
scene (`res://scenes/title.tscn`) with no script or resource load errors.

## Convention: one game referencing the other

Because each game is a plain folder under `games/`, a game can reach into its
sibling by a **relative filesystem path** from its own project root. Godot's
`res://` is scoped to the game that is running, so it cannot cross into the
sibling; use a path relative to the running project's directory instead. From
`games/corgiknight-adventure/` the sibling is:

```
../corgiknight-mansion/
```

and vice versa. Practical ways to use that:

- **Copy an asset over** (the preferred pattern here, since there is no shared
  library): duplicate the scene/script/material from the sibling into the
  consuming game's own `res://` tree, then reference it with a normal `res://`
  path. This keeps each game self-contained and avoids a load-time dependency on
  the sibling folder.
- **Read a sibling file at tooling time** (build scripts, asset-sync scripts,
  editor plugins): resolve the sibling via the relative path above rather than
  `res://`.

The guiding rule for this monorepo: **duplicate what a game needs into that
game**. Keep each `games/<name>/` folder able to open, import, and boot on its
own without depending on the other at runtime.
