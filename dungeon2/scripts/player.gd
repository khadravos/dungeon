extends Node3D
signal exit_reached

@export var grid_size: float = 2.0
@export var min_steps_for_encounter: int = 300
@export var max_steps_for_encounter: int = 3000

var grid_pos: Vector3i = Vector3i.ZERO
var facing_dir: Vector3i = Vector3i.FORWARD
var is_rotating: bool = false

# Encounter tracking
var steps_since_last_encounter: int = 0
var next_encounter_threshold: int

signal encounter_triggered

@onready var dungeon := get_parent().get_node("Dungeon")

func _ready():
	
	update_facing_dir()
	randomize()
	set_next_encounter_threshold()

func place_in_dungeon():
	position = Vector3(grid_pos) * grid_size

func set_dungeon(new_dungeon):
	dungeon = new_dungeon


func set_next_encounter_threshold():
	next_encounter_threshold = randi_range(min_steps_for_encounter, max_steps_for_encounter)

func _unhandled_input(event):
	if is_rotating:
		return

	if event.is_action_pressed("move_forward"):
		try_move(facing_dir)
	elif event.is_action_pressed("move_back"):
		try_move(-facing_dir)
	elif event.is_action_pressed("turn_left"):
		smooth_rotate(deg_to_rad(90))
	elif event.is_action_pressed("turn_right"):
		smooth_rotate(deg_to_rad(-90))

func try_move(dir: Vector3i):
	var target = grid_pos + dir
	if dungeon.is_walkable_cell(target):
		grid_pos = target
		var tween = create_tween()
		tween.tween_property(self, "position", Vector3(grid_pos) * grid_size, 0.2)
		tween.finished.connect(on_move_finished)

func on_move_finished():
	# FIRST: check exit
	if dungeon.is_exit(grid_pos):
		emit_signal("exit_reached")
		return

	# Continue counting steps AFTER exit check
	steps_since_last_encounter += 1

	# Random encounter system
	if steps_since_last_encounter >= next_encounter_threshold:
		steps_since_last_encounter = 0
		set_next_encounter_threshold()
		emit_signal("encounter_triggered")


func smooth_rotate(angle: float):
	if is_rotating:
		return
	is_rotating = true

	var tween = create_tween()
	var target_rot = rotation.y + angle
	tween.tween_property(self, "rotation:y", target_rot, 0.2)
	tween.finished.connect(func():
		update_facing_dir()
		is_rotating = false
	)

func update_facing_dir():
	var forward = -transform.basis.z
	facing_dir = Vector3i(roundi(forward.x), 0, roundi(forward.z))


func _on_encounter_triggered() -> void:
	pass # Replace with function body.
