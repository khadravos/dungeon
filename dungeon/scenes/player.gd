extends Node3D

@export var grid_size: float = 2.0
var grid_pos: Vector3i = Vector3i.ZERO
var facing_dir: Vector3i = Vector3i.FORWARD
var is_rotating: bool = false

@onready var dungeon := get_parent().get_node("Dungeon")

func _ready():
	position = Vector3(grid_pos) * grid_size
	update_facing_dir()

func _unhandled_input(event):
	if is_rotating:
		return  # ignore input during rotation

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
