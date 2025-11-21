extends Node3D

@onready var gridmap: GridMap = $GridMap
@export var size: Vector2i = Vector2i(50, 50)
@export var floor_tile: int = 0
@export var wall_tile: int = 1
@export var exit_tile: int = 2
const DUNGEON_OFFSET := Vector3i(0, 0, 0)

var floor_positions: Array[Vector2i] = []
var exit_position: Vector2i
var rooms: Array[Rect2i] = []

func _ready():
	self.position = Vector3(-1, 0, -1)
	randomize()
	floor_positions.clear()
	rooms.clear()

	_generate_rooms()
	_generate_maze()
	

	# Place player at random floor
	var player = get_parent().get_node_or_null("Player")
	if player:
		var start = get_random_floor_in_room()
		player.grid_pos = start
		player.position = (Vector3(start) + Vector3(DUNGEON_OFFSET)) * gridmap.cell_size
	place_exit()
	fill_gridmap()

# --- ROOM GENERATION ---
func _generate_rooms():
	var max_rooms := 20
	var min_size := 3
	var max_size := 7

	for i in range(max_rooms):
		var w = randi_range(min_size, max_size)
		var h = randi_range(min_size, max_size)
		var x = randi_range(1, size.x - w - 1)
		var y = randi_range(1, size.y - h - 1)

		var room := Rect2i(x, y, w, h)

		var overlaps := false
		for r in rooms:
			if r.grow(-1).intersects(room):
				overlaps = true
				break

		if not overlaps:
			rooms.append(room)
			# carve room floors
			for rx in range(room.position.x, room.position.x + room.size.x):
				for ry in range(room.position.y, room.position.y + room.size.y):
					floor_positions.append(Vector2i(rx, ry))


# --- MAZE GENERATION USING DFS ---
# --- CONNECT ROOMS WITH STRAIGHT CORRIDORS ---
func _generate_maze():
	if rooms.is_empty():
		return

	# Collect room centers
	var centers: Array[Vector2i] = []
	for room in rooms:
		var cx = room.position.x + room.size.x / 2
		var cy = room.position.y + room.size.y / 2
		centers.append(Vector2i(int(cx), int(cy)))

	# Sort centers roughly left → right for nicer layout
	centers.sort_custom(Callable(self, "_sort_vec2"))

	# Connect each room to next one in line
	for i in range(centers.size() - 1):
		_connect_points(centers[i], centers[i + 1])


# --- FILL GRIDMAP ---
func fill_gridmap():
	for x in range(size.x):
		for y in range(size.y):
			gridmap.set_cell_item(Vector3i(x, 0, y) + DUNGEON_OFFSET, wall_tile)

	for pos in floor_positions:
		gridmap.set_cell_item(Vector3i(pos.x, 0, pos.y) + DUNGEON_OFFSET, floor_tile)

	if exit_position:
		gridmap.set_cell_item(Vector3i(exit_position.x, 0, exit_position.y) + DUNGEON_OFFSET, exit_tile)


# --- RANDOM FLOOR ---
func get_random_floor_position() -> Vector3i:
	if floor_positions.is_empty():
		return Vector3i.ZERO
	var pos = floor_positions.pick_random()
	return Vector3i(pos.x, 0, pos.y)


# --- EXIT PLACEMENT (farthest from start) ---
# --- EXIT PLACEMENT: farthest ROOM from the player's start ROOM ---
func place_exit():
	if rooms.is_empty() or floor_positions.is_empty():
		return

	# Pick a random room as the starting room
	var start_room: Rect2i = rooms.pick_random()

	# Compute the center of that room
	var sx = start_room.position.x + start_room.size.x / 2
	var sy = start_room.position.y + start_room.size.y / 2
	var start_center = Vector2i(int(sx), int(sy))

	# Find the farthest room from the start room
	var farthest_room := start_room
	var max_dist := -1

	for room in rooms:
		var cx = room.position.x + room.size.x / 2
		var cy = room.position.y + room.size.y / 2
		var center = Vector2i(int(cx), int(cy))
		var dist = start_center.distance_squared_to(center)

		if dist > max_dist:
			max_dist = dist
			farthest_room = room

	# Pick a random floor tile inside the farthest room to use as exit
	var fx = randi_range(farthest_room.position.x, farthest_room.position.x + farthest_room.size.x - 1)
	var fy = randi_range(farthest_room.position.y, farthest_room.position.y + farthest_room.size.y - 1)
	exit_position = Vector2i(fx, fy)


# --- WALKABLE CHECK ---
func is_walkable_cell(cell: Vector3i) -> bool:
	var check = cell - DUNGEON_OFFSET
	if check.x < 0 or check.x >= size.x or check.z < 0 or check.z >= size.y:
		return false

	var item = gridmap.get_cell_item(cell)
	return item == floor_tile or item == exit_tile


func is_exit(cell: Vector3i) -> bool:
	return exit_position \
		and cell.x == exit_position.x + DUNGEON_OFFSET.x \
		and cell.z == exit_position.y + DUNGEON_OFFSET.z

# Sort helper for room centers
func _sort_vec2(a: Vector2i, b: Vector2i) -> bool:
	return a.x < b.x

# Create a straight corridor between two points
func _connect_points(a: Vector2i, b: Vector2i):
	# Randomly choose whether to go horizontal first or vertical first
	if randf() < 0.5:
		_carve_line(a.x, b.x, a.y, true)  # horizontal
		_carve_line(a.y, b.y, b.x, false) # vertical
	else:
		_carve_line(a.y, b.y, a.x, false) # vertical
		_carve_line(a.x, b.x, b.y, true)  # horizontal

# Carve corridor line (horizontal or vertical)
func _carve_line(from_val: int, to_val: int, fixed: int, horizontal: bool):
	var start = min(from_val, to_val)
	var end = max(from_val, to_val)
	for p in range(start, end + 1):
		var pos: Vector2i = Vector2i(p, fixed) if horizontal else Vector2i(fixed, p)
		floor_positions.append(pos)

func get_random_floor_in_room() -> Vector3i:
	if rooms.is_empty():
		return get_random_floor_position()
	var room: Rect2i = rooms.pick_random()
	var x = randi_range(room.position.x, room.position.x + room.size.x - 1)
	var y = randi_range(room.position.y, room.position.y + room.size.y - 1)
	return Vector3i(x, 0, y)
