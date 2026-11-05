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

# --- Vacuum weapons (the Ghost Sucker!) ---------------------------------
## Is this a "hold to vacuum" weapon instead of a "swing" weapon? Swords and
## axes leave this false and swing exactly as before; the Ghost Sucker turns
## it on so player.gd runs the beam while you HOLD the attack button.
@export var is_vacuum := false
## How far the vacuum beam reaches out in front of the nozzle, in meters.
@export var beam_range := 5.0
## The half-angle of the cone-shaped beam, in degrees. Ghosts inside this
## cone (and within beam_range) get pulled in.
@export var beam_angle := 32.0


## A short description of what this item does, e.g. "+1 heart, blocks 1 damage".
func describe() -> String:
	var parts: Array[String] = []
	if is_vacuum:
		parts.append("slurps up ghosts")
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


# --- Vacuum helpers -----------------------------------------------------
# These only do anything for a vacuum item that has a "Nozzle" node (with an
# optional "Beam" mesh and "Swirl" particles under it). Swords, armor and the
# like have none of these nodes, so these calls are harmless no-ops for them.

## Turn the beam mesh + swirl particles on or off. player.gd calls this while
## you hold / release the attack button with the Ghost Sucker equipped.
func set_vacuuming(active: bool) -> void:
	var nozzle := get_node_or_null("Nozzle")
	if nozzle == null:
		return
	var beam := nozzle.get_node_or_null("Beam") as Node3D
	if beam:
		beam.visible = active
	var swirl := nozzle.get_node_or_null("Swirl") as GPUParticles3D
	if swirl:
		swirl.emitting = active


## The world-space point at the mouth of the nozzle, where the beam starts and
## where caught ghosts get slurped in. Falls back to the item's own origin if
## there's no nozzle (so a vacuum still works even without the extra node).
func nozzle_point() -> Vector3:
	var nozzle := get_node_or_null("Nozzle") as Node3D
	return nozzle.global_position if nozzle else global_position
## The name shown to the player, e.g. "Rusty Sword".
@export var display_name := "Item"
