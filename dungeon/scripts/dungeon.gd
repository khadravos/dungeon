extends Node3D

@onready var gridmap: GridMap = $GridMap
@export var size: Vector2i = Vector2i(25, 25) # dungeon width/height
@export var steps: int = 200                 # how many random steps to take
@export var floor_tile: int = 0              # ID from your MeshLibrary
@export var wall_tile: int = 1

var floor_positions: Array[Vector2i] = []

func _ready():
	randomize()
	generate_dungeon()
	fill_gridmap()

	# Find and move the player if it exists
	var player = get_parent().get_node_or_null("Player")
	if player:
		var start = get_random_floor_position()
		player.grid_pos = start
		player.position = Vector3(start) * gridmap.cell_size

func generate_dungeon():
	var pos = Vector2i(size.x / 2, size.y / 2)
	floor_positions.append(pos)

	for i in range(steps):
		var dir := Vector2i.ZERO

		match randi_range(0, 3):
			0:
				dir = Vector2i(1, 0)
			1:
				dir = Vector2i(-1, 0)
			2:
				dir = Vector2i(0, 1)
			3:
				dir = Vector2i(0, -1)

		pos += dir

		# Keep within bounds
		pos.x = clamp(pos.x, 1, size.x - 2)
		pos.y = clamp(pos.y, 1, size.y - 2)

		if not floor_positions.has(pos):
			floor_positions.append(pos)

func fill_gridmap():
	# Fill everything with walls first
	for x in range(size.x):
		for y in range(size.y):
			gridmap.set_cell_item(Vector3i(x, 0, y), wall_tile)

	# Then carve out the floors
	for pos in floor_positions:
		gridmap.set_cell_item(Vector3i(pos.x, 0, pos.y), floor_tile)

func is_walkable_cell(cell: Vector3i) -> bool:
	# bounds check
	if cell.x < 0 or cell.x >= size.x or cell.z < 0 or cell.z >= size.y:
		return false

	# get_cell_item expects GridMap cell coords (Vector3i)
	var cell_item = gridmap.get_cell_item(cell)
	if cell_item == -1:
		# no tile placed here -> NOT walkable in your setup
		return false

	# If you have explicit IDs for floor/wall, prefer that:
	if cell_item == floor_tile:
		return true
	elif cell_item == wall_tile:
		return false

	# Fallback to name check if you use named mesh library items
	var item_name := ""
	if gridmap.mesh_library and cell_item >= 0:
		item_name = gridmap.mesh_library.get_item_name(cell_item)
		# make the name-check robust and case-insensitive
		if item_name.to_lower().find("floor") != -1:
			return true

	return false
	
func get_random_floor_position() -> Vector3i:
	if floor_positions.is_empty():
		return Vector3i.ZERO
	var pos_2d = floor_positions.pick_random()
	return Vector3i(pos_2d.x, 0, pos_2d.y)
