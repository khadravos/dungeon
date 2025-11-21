extends Node

@onready var player = $Player
@onready var persistent_bars: PersistentPlayerBars = $persistentplayerbars
const DUNGEON_OFFSET := Vector3i(0, 0, 0)

# IMPORTANT: CombatManager already exists in the scene — DO NOT instance dynamically
@onready var combat: CombatManager = $CombatManager

@onready var equipment_panel: EquipmentPanel = $EquipmentPanel
@onready var inventory_manager: inventoryManager = $inventoryManager
@onready var encounter_manager: EncounterManager = $CombatManager/EncounterManager

var floor = 1


func _ready():
	# Load databases only ONCE
	encounter_manager.load_databases()

	# Build or load party ONCE (persistent battlers)
	if combat.party.is_empty():
		combat.party = encounter_manager.setup_party_from_db()

	# Setup equipment and inventory with persistent party
	equipment_panel.setup(combat.party, inventory_manager)

	# Make sure CharacterLoader has inventory access
	$CombatManager/EncounterManager/CharacterLoader.inventory_manager = inventory_manager

	# Persistent UI bars follow the same battler objects
	persistent_bars.setup(combat.party)

	# Connect player encounter signal
	if not player.is_connected("encounter_triggered", Callable(self, "_on_player_encounter_triggered")):
		player.connect("encounter_triggered", Callable(self, "_on_player_encounter_triggered"))
	if not player.is_connected("exit_reached", Callable(self, "_on_player_exit_reached")):
		player.connect("exit_reached", Callable(self, "_on_player_exit_reached"))


func _on_player_encounter_triggered():
	# NEVER re-instantiate CombatManager, reuse the existing one
	combat.persistent_bars = persistent_bars

	# Avoid connecting multiple times
	if not combat.is_connected("battle_ended", Callable(self, "_on_battle_ended")):
		combat.connect("battle_ended", Callable(self, "_on_battle_ended"))

	# Just start the battle using the persistent party
	combat.start_battle()

	get_tree().paused = true

func _on_player_exit_reached():
	floor += 1
	print("Next Floor:", floor)

	load_new_dungeon()

func load_new_dungeon() -> void:
	var old_dungeon = get_node_or_null("Dungeon")
	if old_dungeon:
		old_dungeon.queue_free()
	
	# Wait a frame so the free actually happens
	await get_tree().process_frame
	
	_spawn_new_dungeon()

func _spawn_new_dungeon():
	var dungeon_scene = preload("res://scenes/dungeon.tscn")
	var new_dungeon = dungeon_scene.instantiate()
	new_dungeon.name = "Dungeon"
	add_child(new_dungeon)

	# Remove and respawn player
	var old_player = get_node_or_null("Player")
	if old_player:
		old_player.queue_free()
	await get_tree().process_frame

	var player_scene = preload("res://scenes/player.tscn")
	var new_player = player_scene.instantiate()
	new_player.name = "Player"
	add_child(new_player)

	# set starting position
	var start = new_dungeon.get_random_floor_position()
	new_player.grid_pos = start
	new_player.grid_size = new_dungeon.gridmap.cell_size.z
	new_player.position = (Vector3i(start) + DUNGEON_OFFSET) * new_player.grid_size

	new_player.set_dungeon(new_dungeon)

	new_player.connect("encounter_triggered", Callable(self, "_on_player_encounter_triggered"))
	new_player.connect("exit_reached", Callable(self, "_on_player_exit_reached"))

	# Update ref
	player = new_player


func _on_battle_ended(victory: bool):
	get_tree().paused = false

	if victory:
		print("Victory! Continue exploration.")
	else:
		print("Defeat or escaped. Return to map.")
