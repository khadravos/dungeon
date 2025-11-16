extends Node
class_name TurnManager

signal turn_ready(battler: Battler)

var battlers: Array[Battler] = []
var active: bool = false
var paused: bool = false



func setup(party: Array[Battler], enemies: Array[Battler]):
	battlers = party + enemies
	for b in battlers:
		b.charge = 0  # ATB starts somewhere random
	active = true

func process_turns(delta):
	if not active or paused:
		return
	for b in battlers:
		if b.hp <= 0:
			continue
		b.charge += b.agility * delta * 100
		if b.atb_bar:
			b.atb_bar.value = b.charge
		if b.charge >= 100:
			b.charge = 0
			paused = true
			emit_signal("turn_ready", b)
			break

func resume():
	paused = false
