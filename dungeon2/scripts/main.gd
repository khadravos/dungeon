extends Node

@onready var player = $Player
@onready var persistent_bars: PersistentPlayerBars = $persistentplayerbars
@onready var combat_scene = preload("res://scenes/CombatManager.tscn")
@onready var combat = combat_scene.instantiate()
var floor = 1  # or however you track the current dungeon layer

func _ready():
	add_child(combat)
	

	if not player.is_connected("encounter_triggered", Callable(self, "_on_player_encounter_triggered")):
		player.connect("encounter_triggered", Callable(self, "_on_player_encounter_triggered"))


func _on_player_encounter_triggered():
	# If old combat exists but got freed, instantiate a new one
	if combat == null or not is_instance_valid(combat):
		combat = combat_scene.instantiate()
		add_child(combat)

	combat.persistent_bars = persistent_bars

	if not combat.is_connected("battle_ended", Callable(self, "_on_battle_ended")):
		combat.connect("battle_ended", Callable(self, "_on_battle_ended"))

	combat.start_battle()

	get_tree().paused = true


func _on_battle_ended(victory: bool):
	get_tree().paused = false

	if victory:
		print("Victory! Continue exploration.")
	else:
		print("Defeat or escaped. Return to map.")
