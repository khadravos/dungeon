extends Node3D

@export var gridmap: GridMap
@export var color: Color = Color(0, 1, 0, 0.5) # semi-transparent green
@export var show: bool = true

var lines: Array[MeshInstance3D] = []

func _ready():
	if gridmap:
		_draw_grid()

func _draw_grid():
	if not show:
		return
	
	var mesh = ImmediateMesh.new()
	var size = gridmap.cell_size
	var half_size = size / 2.0

	for cell in gridmap.get_used_cells():
		var world_pos = gridmap.map_to_local(cell)

		# draw a wireframe box for each cell
		var line = MeshInstance3D.new()
		line.mesh = _make_wire_box(size, color)
		line.transform.origin = world_pos
		add_child(line)
		lines.append(line)

func _make_wire_box(size: Vector3, color: Color) -> ImmediateMesh:
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	
	var corners = [
		Vector3(-0.5, 0, -0.5),
		Vector3(0.5, 0, -0.5),
		Vector3(0.5, 0, 0.5),
		Vector3(-0.5, 0, 0.5)
	]
	
	for i in range(4):
		mesh.surface_add_vertex(corners[i] * Vector3(size.x, 1, size.z))
		mesh.surface_add_vertex(corners[(i + 1) % 4] * Vector3(size.x, 1, size.z))
	
	mesh.surface_end()
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mesh.surface_set_material(0, mat)
	
	return mesh
