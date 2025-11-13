extends Node

@onready var combat_manager = $CombatManager
@onready var player = $Player

func _ready():
	if not player.is_connected("encounter_triggered", Callable(self, "_on_player_encounter_triggered")):
		player.connect("encounter_triggered", Callable(self, "_on_player_encounter_triggered"))


func _on_player_encounter_triggered():
	var combat = preload("res://scenes/CombatManager.tscn").instantiate()
	add_child(combat)
	combat.start_battle()
