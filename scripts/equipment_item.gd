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
## Extra hearts while wearing this.
@export var bonus_hearts := 0
## Can this weapon chop down trees? (Axes can!)
@export var can_chop := false
## Makes the corgi run faster. 0.2 = 20% faster.
@export var speed_bonus := 0.0


## A short description of what this item does, e.g. "+1 heart, blocks 1 damage".
func describe() -> String:
	var parts: Array[String] = []
	if slot == "weapon" and damage > 0:
		parts.append("%d damage" % damage)
	if can_chop:
		parts.append("chops trees")
	if bonus_hearts > 0:
		parts.append("+%d heart" % bonus_hearts + ("s" if bonus_hearts > 1 else ""))
	if defense > 0:
		parts.append("blocks %d damage" % defense)
	if speed_bonus > 0.0:
		parts.append("run faster")
	return ", ".join(parts)
## The name shown to the player, e.g. "Rusty Sword".
@export var display_name := "Item"
