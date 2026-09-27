class_name EquipmentItem
extends Node3D
## Anything the corgi can wear or hold: swords, shields, helmets, armor, boots.
##
## To make a new item: make a scene with this script on its root node,
## pick its Slot, set its stats, and build its look out of meshes (or drop in
## a 3D model). Then call player.equip(your_scene) — for example from a
## treasure chest. The item snaps onto the matching attachment point.
##
## Build items facing forward (-Z) with the grip / center at the origin.

## Where this item goes on the corgi.
@export_enum("head", "chest", "back", "shield", "weapon", "feet") var slot: String = "weapon"
## Extra sword damage (weapons).
@export var damage := 0
## How far the weapon reaches, in meters (weapons).
@export var reach := 1.8
## Blocks this much damage from each hit (armor). A hit always does at least 1.
@export var defense := 0
## The name shown to the player, e.g. "Rusty Sword".
@export var display_name := "Item"
