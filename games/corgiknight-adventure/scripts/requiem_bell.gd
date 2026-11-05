extends Node3D
## The Requiem Bell, waiting inside the spooky mansion.
##
## Press E next to it to try to ring it. If you've sucked up enough ghost
## energy (Game.bell_energy_cost) it rings loud and true, spends the energy
## and destroys the portal. Too little energy and it just goes "clunk" and
## tells you how many more ghosts you need.

## Shown as "[E] Ring the Requiem Bell".
@export var prompt_text := "Ring the Requiem Bell"

@onready var bell: Node3D = $Pivot/BellBody
@onready var pivot: Node3D = $Pivot

var _time := 0.0
var _rung := false


func _ready() -> void:
	add_to_group("interactable")


func _process(delta: float) -> void:
	_time += delta
	# A gentle sway so the bell feels alive and invites a ring.
	if not _rung:
		pivot.rotation.z = sin(_time * 1.5) * 0.04


## Called when the corgi presses E next to the bell.
func interact(_player: Node) -> void:
	# Once the portal's gone the bell has done its job.
	if Game.haunted_quest == Game.HauntedQuest.DONE:
		Game.say("", ["The Requiem Bell rests quietly. Its work here is done."])
		return
	# You can only ring it once you've been sent to find it (quest 2).
	if Game.haunted_quest != Game.HauntedQuest.FIND_BELL:
		Game.say("", ["A heavy old bell... maybe suck up some ghosts first?"])
		return
	if not Game.can_ring_bell():
		_weak_clunk()
		return
	_ring_for_real()


## Not enough energy: a sad little clunk and a hint.
func _weak_clunk() -> void:
	var missing := Game.bell_energy_missing()
	_swing(0.25, 0.5)
	Effects.poof(self, bell.global_position, Color(0.5, 0.5, 0.6), 0.6, 6)
	var ghosts := "ghost" if missing == 1 else "ghosts"
	Game.message.emit("*clunk* Not enough energy. Suck up %d more %s!" % [missing, ghosts])


## Enough energy: ring it hard, spend the energy, destroy the portal.
func _ring_for_real() -> void:
	if _rung:
		return
	_rung = true
	remove_from_group("interactable")
	# A big, happy swing.
	_swing(1.1, 0.12)
	Effects.shockwave(self, bell.global_position, Color(0.8, 1.0, 0.9, 0.8), 6.0)
	Effects.poof(self, bell.global_position, Color(1.0, 1.0, 0.8), 1.4, 20)
	# This spends the energy, flips the quest to DONE and fires portal_destroyed.
	Game.ring_bell()


## Swing the bell back and forth a few times.
func _swing(amount: float, speed: float) -> void:
	var tween := create_tween()
	tween.tween_property(pivot, "rotation:z", amount, speed).set_trans(Tween.TRANS_SINE)
	tween.tween_property(pivot, "rotation:z", -amount, speed * 1.4).set_trans(Tween.TRANS_SINE)
	tween.tween_property(pivot, "rotation:z", amount * 0.5, speed * 1.2).set_trans(Tween.TRANS_SINE)
	tween.tween_property(pivot, "rotation:z", 0.0, speed * 1.4).set_trans(Tween.TRANS_SINE)
