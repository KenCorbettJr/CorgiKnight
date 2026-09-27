# CorgiKnight

A cute 3D corgi adventure made with Godot 4.

## How to play it

1. Download **Godot 4** (the standard version, not .NET) from https://godotengine.org/download.
2. Open Godot, click **Import**, and pick the `project.godot` file in this folder.
3. Press **F5** (or the ▶ Play button at the top right).

The first time you open it, Godot will spend a few seconds importing files. That's normal.

## Controls

| Action | Keyboard & mouse | Controller |
|---|---|---|
| Move | WASD / arrow keys | Left stick |
| Look around | Mouse | Right stick |
| Jump | Space | A |
| Run | Shift | Left bumper |
| Swing sword | Left click / J | X |
| Free the mouse | Esc (click to grab it again) | — |

**Goal:** bonk all 5 slimes. The purple King Slime is waiting on top of the stone lookout. You'll have to jump up the steps to reach it.

## What's in here

```
scenes/
  main.tscn         The island: sky, sun, ground, water, the lookout, slimes
  player.tscn       The corgi knight (made from simple shapes for now) + camera
  equipment/        Things the corgi can hold or wear (starts with just a sword)
  slime.tscn        A slime enemy
  tree.tscn         A puffy cartoon tree
  rock.tscn         A rock
  stone_block.tscn  A stone block (change its Size in the Inspector)
  hud.tscn          Hearts, slime counter, victory message
scripts/            The code for each of the above (lots of comments!)
materials/          Toon-shaded colors + the cartoon outline
```

## Fun things to try together

- **Tweak the corgi:** open `scenes/player.tscn`, click the Player node, and change `Jump Velocity`, `Sprint Speed` or `Max Health` in the Inspector on the right.
- **Add more slimes:** open `scenes/main.tscn`, then drag `slime.tscn` from the FileSystem panel into the 3D view. Change its `Body Color`!
- **Build more of the world:** drag in more `stone_block.tscn` blocks and set their Size to make towers, walls and ruins.
- **New island layout:** click the Main node and change `World Seed` to move the trees and rocks around.
- **Recolor everything:** double-click a file in `materials/` to change its color.

## Equipment

The corgi has attachment points for gear: **head**, **chest**, **back**, **shield** (left paw),
**weapon** (right paw) and **feet** (both feet). It starts with only a sword and no armor.

To make a new item:

1. Duplicate `scenes/equipment/basic_sword.tscn` (or make a new scene with a Node3D root).
2. Make sure the root node has `scripts/equipment_item.gd`, pick its **Slot**, and set
   **Damage** (weapons) or **Defense** (armor).
3. Build its look from shapes or a 3D model, facing forward (-Z) with its center at the origin.
4. In code, call `player.equip(preload("res://scenes/equipment/your_item.tscn"))`, for example
   when the corgi opens a treasure chest.

## Next steps

- Swap the shape-corgi for a real animated model (e.g. the Shiba Inu from Quaternius' free animal pack, or a custom one made in Blender).
- Heart pickups that heal the corgi.
- A treasure chest with a better sword or armor inside.
- A real boss fight.
- A dodge roll and a lock-on camera.
