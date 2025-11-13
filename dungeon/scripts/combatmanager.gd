extends Node

# === Combat Stats ===
var player_hp: int = 30
var enemy_hp: int = 20
var player_attack: int = 5
var enemy_attack: int = 4
var player_defending: bool = false

var player_turn: bool = true
var battle_active: bool = false

# === References to UI Elements ===
@onready var player_label: Label = $CanvasLayer/Control/VBoxContainer/PlayerLabel
@onready var enemy_label: Label = $CanvasLayer/Control/VBoxContainer/EnemyLabel
@onready var action_label: Label = $CanvasLayer/Control/VBoxContainer/ActionLabel
@onready var menu_container: VBoxContainer = $CanvasLayer/Control/Menu
@onready var attack_button: Button = menu_container.get_node("attackbutton")
@onready var defend_button: Button = menu_container.get_node("defendbutton")
@onready var run_button: Button = menu_container.get_node("runbutton")

signal battle_ended(victory: bool)

# === Initialization ===
func _ready():
	menu_container.visible = false
	update_ui()
	attack_button.pressed.connect(_on_attack_pressed)
	defend_button.pressed.connect(_on_defend_pressed)
	run_button.pressed.connect(_on_run_pressed)

# === Start the Battle ===
func start_battle():
	battle_active = true
	player_hp = 30
	enemy_hp = 20
	player_turn = true
	player_defending = false

	action_label.text = "A wild enemy appears!"
	update_ui()
	menu_container.visible = false

	get_tree().paused = true  # ⏸ Pause dungeon gameplay

	var timer := get_tree().create_timer(1.5)
	await timer.timeout

	action_label.text = "Your turn!"
	menu_container.visible = true

# === UI Updates ===
func update_ui():
	player_label.text = "Player HP: %d" % player_hp
	enemy_label.text = "Enemy HP: %d" % enemy_hp

# === Button Handlers ===
func _on_attack_pressed():
	print("Attack button pressed")
	if not player_turn or not battle_active:
		return
	player_attack_enemy()

func _on_defend_pressed():
	print("Defend button pressed")
	if not player_turn or not battle_active:
		return
	player_defending = true
	action_label.text = "You defend yourself!"
	menu_container.visible = false
	player_turn = false

	var timer := get_tree().create_timer(1.5)
	await timer.timeout
	enemy_attack_player()

func _on_run_pressed():
	print("Run button pressed")
	if not player_turn or not battle_active:
		return
	menu_container.visible = false
	action_label.text = "You try to run away..."
	player_turn = false


	# 50% chance to escape
	if randf() < 0.5:
		action_label.text = "You escaped successfully!"
		await get_tree().create_timer(1.5).timeout
		end_battle(false)  # Not a victory, but ends battle
	else:
		action_label.text = "You failed to escape!"
		await get_tree().create_timer(1.5).timeout
		enemy_attack_player()

# === Player Actions ===
func player_attack_enemy():
	action_label.text = "You attack the enemy!"
	menu_container.visible = false
	enemy_hp -= player_attack
	update_ui()

	if enemy_hp <= 0:
		end_battle(true)
		return

	player_turn = false
	var timer := get_tree().create_timer(1.5)
	await timer.timeout
	enemy_attack_player()

# === Enemy Turn ===
func enemy_attack_player():
	var damage = enemy_attack
	if player_defending:
		damage = int(damage / 2)
		player_defending = false

	action_label.text = "Enemy attacks you for %d damage!" % damage
	player_hp -= damage
	update_ui()

	if player_hp <= 0:
		end_battle(false)
		return

	var timer := get_tree().create_timer(1.5)
	await timer.timeout

	player_turn = true
	action_label.text = "Your turn!"
	menu_container.visible = true

# === End Battle ===
func end_battle(victory: bool):
	battle_active = false
	menu_container.visible = false

	if victory:
		action_label.text = "You won the battle!"
	else:
		action_label.text = "You were defeated or fled..."

	var timer := get_tree().create_timer(2.0)
	await timer.timeout

	get_tree().paused = false  # ▶️ Resume dungeon gameplay
	emit_signal("battle_ended", victory)
	queue_free()
