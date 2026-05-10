extends Node3D

# ─────────────────────────────────────────────
#  Globe3D — globo 3D interativo
#  Attach na cena Globe3D.tscn
# ─────────────────────────────────────────────

signal country_selected(country_id: int)

const ERA_COLORS = {
	0: Color(0.55, 0.37, 0.24),  # Tribal — marrom
	1: Color(0.83, 0.66, 0.26),  # Antiga — dourado
	2: Color(0.29, 0.60, 0.42),  # Medieval — verde
	3: Color(0.23, 0.50, 0.83),  # Moderna — azul
	4: Color(0.72, 0.27, 0.87),  # Futura — roxo
}

# Posições lat/lon de cada país (graus)
const COUNTRY_POSITIONS = {
	1:  {"lat": 48.0,  "lon": -5.0},   # Valdoria
	2:  {"lat": 25.0,  "lon": 45.0},   # Kharuum
	3:  {"lat": 60.0,  "lon": 25.0},   # Sylveth
	4:  {"lat": 35.0,  "lon": 105.0},  # Dorrakan
	5:  {"lat": -10.0, "lon": -60.0},  # Aeloria
	6:  {"lat": 15.0,  "lon": 30.0},   # Vrexmoor
	7:  {"lat": -35.0, "lon": -65.0},  # Thessomar
	8:  {"lat": -20.0, "lon": 135.0},  # Korrath
	9:  {"lat": 55.0,  "lon": -30.0},  # Lunaris
	10: {"lat": 10.0,  "lon": 80.0},   # Zethara
}

const CONTINENT_ANCHORS = [
	{"lat": 48.0, "lon": 10.0, "radius": 0.74, "uplift": 0.078},
	{"lat": 18.0, "lon": 58.0, "radius": 0.82, "uplift": 0.086},
	{"lat": -18.0, "lon": -62.0, "radius": 0.86, "uplift": 0.088},
	{"lat": -24.0, "lon": 126.0, "radius": 0.64, "uplift": 0.074},
	{"lat": 54.0, "lon": -28.0, "radius": 0.58, "uplift": 0.070},
]

const MAP_SEED = 42077
const PLANET_SUBDIVISIONS = 3
const FAULT_ITERATIONS = 110
const FAULT_SHARPNESS = 42.0
const FAULT_STRENGTH = 0.010
const SEA_LEVEL = 1.0
const CONTINENT_LAND_RADIUS = 0.78
const CONTINENT_LAND_UPLIFT = 0.085
const COUNTRY_LAND_RADIUS = 0.38
const COUNTRY_LAND_UPLIFT = 0.078
const FOREST_MAX_INSTANCES = 220
const MOUNTAIN_MAX_INSTANCES = 90
const CLOUD_LAYER_RADIUS = 1.075
const ATMOSPHERE_RADIUS = 1.105

var globe_mesh: MeshInstance3D
var ocean_mesh: MeshInstance3D
var atmosphere_mesh: MeshInstance3D
var cloud_mesh: MeshInstance3D
var forest_multimesh: MultiMeshInstance3D
var mountain_multimesh: MultiMeshInstance3D
var city_lights: Dictionary = {}
var markers: Dictionary = {}       # country_id -> MeshInstance3D
var war_lines: Array = []          # linhas de guerra ativas
var selected_country_id: int = -1
var _dragging: bool = false
var _last_mouse: Vector2 = Vector2.ZERO
var _rotation_velocity: Vector2 = Vector2.ZERO
var _drag_distance: float = 0.0
var _zoom: float = 4.0
var _time: float = 0.0

@onready var camera: Camera3D = $Camera3D

func _ready() -> void:
	_setup_environment()
	_build_globe()
	_build_globe_guides()
	_build_atmosphere()
	_build_clouds()
	_build_stars()
	_build_markers()
	_setup_lights()

func _setup_environment() -> void:
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.02, 0.05)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.1, 0.12, 0.2)
	env.ambient_light_energy = 0.4
	env.glow_enabled = true
	env.glow_intensity = 0.42
	env.glow_strength = 0.72
	env.glow_bloom = 0.18
	var world_env = WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

# ─────────────────────────────────────────────
#  Constrói o globo principal
# ─────────────────────────────────────────────
func _build_globe() -> void:
	globe_mesh = MeshInstance3D.new()
	var planet_data = _generate_stylized_planet(MAP_SEED)
	globe_mesh.mesh = planet_data["mesh"]

	var mat = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.metallic = 0.0
	mat.roughness = 0.82
	globe_mesh.material_override = mat
	add_child(globe_mesh)

	_build_ocean()
	_build_forests(planet_data["trees"])
	_build_mountains(planet_data["mountains"])

func _generate_stylized_planet(seed_value: int) -> Dictionary:
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_value

	var ico = _create_icosphere(PLANET_SUBDIVISIONS)
	var vertices: Array = ico["vertices"]
	var faces: Array = ico["faces"]

	for _iteration in range(FAULT_ITERATIONS):
		var dir = Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)).normalized()
		for i in range(vertices.size()):
			var normal = (vertices[i] as Vector3).normalized()
			var dot = normal.dot(dir)
			var sigmoid = 1.0 / (1.0 + exp(-dot * FAULT_SHARPNESS)) - 0.5
			vertices[i] = vertices[i] + normal * sigmoid * FAULT_STRENGTH

	_raise_continent_regions(vertices)
	_raise_country_regions(vertices)

	var packed_vertices = PackedVector3Array()
	var packed_normals = PackedVector3Array()
	var packed_colors = PackedColorArray()
	var trees: Array = []
	var mountains: Array = []

	for face in faces:
		var a: Vector3 = vertices[face[0]]
		var b: Vector3 = vertices[face[1]]
		var c: Vector3 = vertices[face[2]]
		var normal = -((b - a).normalized().cross((c - a).normalized())).normalized()
		var avg_height = (a.length() + b.length() + c.length()) / 3.0
		var max_height = max(a.length(), max(b.length(), c.length()))
		var color = _biome_color(max(avg_height, max_height - 0.018))

		packed_vertices.push_back(a)
		packed_vertices.push_back(b)
		packed_vertices.push_back(c)
		packed_normals.push_back(normal)
		packed_normals.push_back(normal)
		packed_normals.push_back(normal)
		packed_colors.push_back(color)
		packed_colors.push_back(color)
		packed_colors.push_back(color)

		var center = (a + b + c) / 3.0
		if avg_height > 1.015 and avg_height < 1.055 and trees.size() < FOREST_MAX_INSTANCES:
			var chance = 1.0 / (1.0 + pow(abs(avg_height - 1.035) * 95.0, 2.0))
			if rng.randf() < chance * 0.25:
				trees.append({"pos": center.normalized() * (avg_height + 0.015), "normal": normal})

		if avg_height >= 1.075 and mountains.size() < MOUNTAIN_MAX_INSTANCES:
			if rng.randf() < 0.18:
				mountains.append({"pos": center.normalized() * (avg_height + 0.018), "normal": normal})

	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = packed_vertices
	arrays[Mesh.ARRAY_NORMAL] = packed_normals
	arrays[Mesh.ARRAY_COLOR] = packed_colors

	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return {"mesh": mesh, "trees": trees, "mountains": mountains}

func _biome_color(height: float) -> Color:
	if height < 0.965:
		return Color(0.03, 0.13, 0.28)
	if height < SEA_LEVEL:
		return Color(0.05, 0.20, 0.38)
	if height < 1.012:
		return Color(0.78, 0.68, 0.42)
	if height < 1.045:
		return Color(0.18, 0.48, 0.27)
	if height < 1.073:
		return Color(0.25, 0.42, 0.22)
	if height < 1.095:
		return Color(0.42, 0.38, 0.32)
	return Color(0.88, 0.90, 0.84)

func _raise_country_regions(vertices: Array) -> void:
	var country_dirs: Array = []
	for id in COUNTRY_POSITIONS:
		var pos_data = COUNTRY_POSITIONS[id]
		country_dirs.append(_lat_lon_to_vec3(pos_data["lat"], pos_data["lon"], 1.0).normalized())

	for i in range(vertices.size()):
		var normal = (vertices[i] as Vector3).normalized()
		var uplift = 0.0
		for country_dir in country_dirs:
			var distance = normal.distance_to(country_dir)
			if distance < COUNTRY_LAND_RADIUS:
				var influence = 1.0 - distance / COUNTRY_LAND_RADIUS
				uplift = max(uplift, influence * influence * COUNTRY_LAND_UPLIFT)
		if uplift > 0.0:
			var current_height = (vertices[i] as Vector3).length()
			vertices[i] = normal * max(current_height + uplift, SEA_LEVEL + uplift * 0.85)

func _raise_continent_regions(vertices: Array) -> void:
	var anchors: Array = []
	for anchor in CONTINENT_ANCHORS:
		anchors.append({
			"dir": _lat_lon_to_vec3(anchor["lat"], anchor["lon"], 1.0).normalized(),
			"radius": anchor.get("radius", CONTINENT_LAND_RADIUS),
			"uplift": anchor.get("uplift", CONTINENT_LAND_UPLIFT),
		})

	for i in range(vertices.size()):
		var normal = (vertices[i] as Vector3).normalized()
		var uplift = 0.0
		for anchor in anchors:
			var distance = normal.distance_to(anchor["dir"])
			var radius = float(anchor["radius"])
			if distance < radius:
				var influence = 1.0 - distance / radius
				uplift = max(uplift, influence * influence * float(anchor["uplift"]))
		if uplift > 0.0:
			var current_height = (vertices[i] as Vector3).length()
			vertices[i] = normal * max(current_height + uplift, SEA_LEVEL + uplift * 0.72)

func _build_ocean() -> void:
	ocean_mesh = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = SEA_LEVEL - 0.010
	sphere.height = (SEA_LEVEL - 0.010) * 2.0
	sphere.radial_segments = 48
	sphere.rings = 24
	ocean_mesh.mesh = sphere

	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.02, 0.20, 0.44, 1.0)
	mat.roughness = 0.35
	mat.metallic = 0.0
	mat.emission_enabled = true
	mat.emission = Color(0.02, 0.12, 0.28)
	mat.emission_energy_multiplier = 0.18
	ocean_mesh.material_override = mat
	globe_mesh.add_child(ocean_mesh)

func _build_forests(tree_points: Array) -> void:
	forest_multimesh = MultiMeshInstance3D.new()
	var mm = MultiMesh.new()
	mm.mesh = _make_cone_mesh(Color(0.05, 0.30, 0.09), 0.028, 0.075)
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.instance_count = tree_points.size()
	for i in range(tree_points.size()):
		var item = tree_points[i]
		var normal: Vector3 = item["normal"]
		var basis = _basis_from_normal(normal, float(i) * 1.618).scaled(Vector3.ONE * 0.65)
		mm.set_instance_transform(i, Transform3D(basis, item["pos"]))
	forest_multimesh.multimesh = mm
	globe_mesh.add_child(forest_multimesh)

func _build_mountains(mountain_points: Array) -> void:
	mountain_multimesh = MultiMeshInstance3D.new()
	var mm = MultiMesh.new()
	mm.mesh = _make_cone_mesh(Color(0.50, 0.48, 0.43), 0.045, 0.095)
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.instance_count = mountain_points.size()
	for i in range(mountain_points.size()):
		var item = mountain_points[i]
		var normal: Vector3 = item["normal"]
		var basis = _basis_from_normal(normal, float(i) * 0.77)
		mm.set_instance_transform(i, Transform3D(basis, item["pos"]))
	mountain_multimesh.multimesh = mm
	globe_mesh.add_child(mountain_multimesh)

func _make_cone_mesh(color: Color, radius: float, height: float) -> ArrayMesh:
	var verts = PackedVector3Array()
	var normals = PackedVector3Array()
	var colors = PackedColorArray()
	var segments = 7
	var tip = Vector3(0.0, height, 0.0)
	var base_center = Vector3.ZERO
	for i in range(segments):
		var a = float(i) / float(segments) * TAU
		var b = float(i + 1) / float(segments) * TAU
		var p1 = Vector3(cos(a) * radius, 0.0, sin(a) * radius)
		var p2 = Vector3(cos(b) * radius, 0.0, sin(b) * radius)
		var side_normal = (p2 - p1).cross(tip - p1).normalized()
		for v in [p1, p2, tip]:
			verts.push_back(v)
			normals.push_back(side_normal)
			colors.push_back(color)
		for v in [p2, p1, base_center]:
			verts.push_back(v)
			normals.push_back(Vector3.DOWN)
			colors.push_back(color)

	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.9
	mesh.surface_set_material(0, mat)
	return mesh

func _basis_from_normal(normal: Vector3, spin: float) -> Basis:
	var tangent = normal.cross(Vector3.UP)
	if tangent.length_squared() < 0.001:
		tangent = normal.cross(Vector3.RIGHT)
	tangent = tangent.normalized()
	var bitangent = tangent.cross(normal).normalized()
	return Basis(tangent, normal, bitangent).rotated(normal, spin)

func _create_icosphere(subdivisions: int) -> Dictionary:
	var t = (1.0 + sqrt(5.0)) / 2.0
	var vertices: Array = [
		Vector3(-1, t, 0).normalized(), Vector3(1, t, 0).normalized(),
		Vector3(-1, -t, 0).normalized(), Vector3(1, -t, 0).normalized(),
		Vector3(0, -1, t).normalized(), Vector3(0, 1, t).normalized(),
		Vector3(0, -1, -t).normalized(), Vector3(0, 1, -t).normalized(),
		Vector3(t, 0, -1).normalized(), Vector3(t, 0, 1).normalized(),
		Vector3(-t, 0, -1).normalized(), Vector3(-t, 0, 1).normalized(),
	]
	var faces: Array = [
		[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11],
		[1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6], [7, 1, 8],
		[3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9],
		[4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1],
	]
	for _s in range(subdivisions):
		var midpoint_cache: Dictionary = {}
		var next_faces: Array = []
		for face in faces:
			var a = _midpoint_index(face[0], face[1], vertices, midpoint_cache)
			var b = _midpoint_index(face[1], face[2], vertices, midpoint_cache)
			var c = _midpoint_index(face[2], face[0], vertices, midpoint_cache)
			next_faces.append([face[0], a, c])
			next_faces.append([face[1], b, a])
			next_faces.append([face[2], c, b])
			next_faces.append([a, b, c])
		faces = next_faces
	return {"vertices": vertices, "faces": faces}

func _midpoint_index(i1: int, i2: int, vertices: Array, cache: Dictionary) -> int:
	var low = min(i1, i2)
	var high = max(i1, i2)
	var key = str(low) + ":" + str(high)
	if cache.has(key):
		return cache[key]
	var midpoint = ((vertices[i1] as Vector3) + (vertices[i2] as Vector3)).normalized()
	vertices.append(midpoint)
	var index = vertices.size() - 1
	cache[key] = index
	return index

func _build_globe_guides() -> void:
	var line_mat = StandardMaterial3D.new()
	line_mat.albedo_color = Color(0.55, 0.90, 1.0, 0.45)
	line_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	for lat in [-60.0, -30.0, 0.0, 30.0, 60.0]:
		var line = _make_latitude_line(lat)
		line.material_override = line_mat
		globe_mesh.add_child(line)

	for lon in range(0, 180, 30):
		var line = _make_longitude_line(float(lon))
		line.material_override = line_mat
		globe_mesh.add_child(line)

func _make_latitude_line(lat: float) -> MeshInstance3D:
	var mesh = ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for i in range(97):
		var lon = -180.0 + float(i) * 360.0 / 96.0
		mesh.surface_add_vertex(_lat_lon_to_vec3(lat, lon, 1.015))
	mesh.surface_end()

	var line = MeshInstance3D.new()
	line.mesh = mesh
	return line

func _make_longitude_line(lon: float) -> MeshInstance3D:
	var mesh = ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for i in range(97):
		var lat = -90.0 + float(i) * 180.0 / 96.0
		mesh.surface_add_vertex(_lat_lon_to_vec3(lat, lon, 1.016))
	mesh.surface_end()

	var line = MeshInstance3D.new()
	line.mesh = mesh
	return line

# ─────────────────────────────────────────────
#  Atmosfera translúcida
# ─────────────────────────────────────────────
func _build_atmosphere() -> void:
	atmosphere_mesh = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = ATMOSPHERE_RADIUS
	sphere.height = ATMOSPHERE_RADIUS * 2.0
	sphere.radial_segments = 48
	sphere.rings = 24
	atmosphere_mesh.mesh = sphere

	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.20, 0.58, 1.0, 0.055)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_FRONT
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission = Color(0.10, 0.42, 1.0)
	mat.emission_energy_multiplier = 0.36
	atmosphere_mesh.material_override = mat
	add_child(atmosphere_mesh)

func _build_clouds() -> void:
	cloud_mesh = MeshInstance3D.new()
	var mesh = _make_cloud_band_mesh()
	cloud_mesh.mesh = mesh

	var mat = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	cloud_mesh.material_override = mat
	globe_mesh.add_child(cloud_mesh)

func _make_cloud_band_mesh() -> ArrayMesh:
	var rng = RandomNumberGenerator.new()
	rng.seed = MAP_SEED + 99
	var verts = PackedVector3Array()
	var normals = PackedVector3Array()
	var colors = PackedColorArray()

	for band in range(26):
		var lat = rng.randf_range(-58.0, 58.0)
		var lon = rng.randf_range(-180.0, 180.0)
		var arc = rng.randf_range(12.0, 34.0)
		var width = rng.randf_range(1.8, 4.8)
		var steps = 5
		for step in range(steps):
			var t0 = float(step) / float(steps)
			var t1 = float(step + 1) / float(steps)
			var lon0 = lon + (t0 - 0.5) * arc
			var lon1 = lon + (t1 - 0.5) * arc
			var wobble0 = sin((t0 + band) * 4.1) * width * 0.35
			var wobble1 = sin((t1 + band) * 4.1) * width * 0.35
			var p1 = _lat_lon_to_vec3(lat - width + wobble0, lon0, CLOUD_LAYER_RADIUS)
			var p2 = _lat_lon_to_vec3(lat + width + wobble0, lon0, CLOUD_LAYER_RADIUS)
			var p3 = _lat_lon_to_vec3(lat + width + wobble1, lon1, CLOUD_LAYER_RADIUS)
			var p4 = _lat_lon_to_vec3(lat - width + wobble1, lon1, CLOUD_LAYER_RADIUS)
			var color = Color(0.92, 0.97, 1.0, rng.randf_range(0.035, 0.085))
			_add_colored_triangle(verts, normals, colors, p1, p2, p3, color)
			_add_colored_triangle(verts, normals, colors, p1, p3, p4, color)

	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func _add_colored_triangle(verts: PackedVector3Array, normals: PackedVector3Array, colors: PackedColorArray, a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	var normal = ((b - a).cross(c - a)).normalized()
	for v in [a, b, c]:
		verts.push_back(v)
		normals.push_back(normal)
		colors.push_back(color)

# ─────────────────────────────────────────────
#  Campo de estrelas
# ─────────────────────────────────────────────
func _build_stars() -> void:
	var multi = MultiMeshInstance3D.new()
	var mm = MultiMesh.new()
	mm.mesh = SphereMesh.new()
	(mm.mesh as SphereMesh).radius = 0.015
	(mm.mesh as SphereMesh).height = 0.03
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.instance_count = 800

	var star_mat = StandardMaterial3D.new()
	star_mat.albedo_color = Color.WHITE
	star_mat.emission_enabled = true
	star_mat.emission = Color.WHITE
	star_mat.emission_energy_multiplier = 2.0
	(mm.mesh as SphereMesh).material = star_mat

	for i in range(800):
		var phi = randf() * TAU
		var costheta = randf_range(-1.0, 1.0)
		var sintheta = sqrt(1.0 - costheta * costheta)
		var r = randf_range(30.0, 50.0)
		var pos = Vector3(sintheta * cos(phi), costheta, sintheta * sin(phi)) * r
		var t = Transform3D(Basis(), pos)
		mm.set_instance_transform(i, t)

	multi.multimesh = mm
	add_child(multi)

# ─────────────────────────────────────────────
#  Iluminação
# ─────────────────────────────────────────────
func _setup_lights() -> void:
	var sun = DirectionalLight3D.new()
	sun.light_energy = 1.8
	sun.light_color = Color(1.0, 0.95, 0.85)
	sun.look_at_from_position(Vector3(5, 3, 5), Vector3.ZERO)
	add_child(sun)

	var ambient = OmniLight3D.new()
	ambient.light_energy = 0.3
	ambient.light_color = Color(0.3, 0.4, 0.7)
	ambient.omni_range = 100
	add_child(ambient)

# ─────────────────────────────────────────────
#  Marcadores dos países
# ─────────────────────────────────────────────
func _build_markers() -> void:
	for id in COUNTRY_POSITIONS:
		var pos_data = COUNTRY_POSITIONS[id]
		var world_pos = _lat_lon_to_vec3(pos_data["lat"], pos_data["lon"], 1.04)
		var marker = _create_marker(id, world_pos)
		globe_mesh.add_child(marker)
		markers[id] = marker

func _create_marker(country_id: int, world_pos: Vector3) -> Node3D:
	var root = Node3D.new()
	root.position = world_pos
	root.look_at_from_position(world_pos, world_pos * 2.0)
	root.set_meta("country_id", country_id)

	# Área de colisão para raycast de seleção
	var area = Area3D.new()
	area.set_meta("country_id", country_id)
	var col = CollisionShape3D.new()
	var shape = SphereShape3D.new()
	shape.radius = 0.07
	col.shape = shape
	area.add_child(col)
	root.add_child(area)

	# Bolinha principal
	var dot = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.035
	sphere.height = 0.07
	dot.mesh = sphere
	dot.set_meta("country_id", country_id)

	var mat = StandardMaterial3D.new()
	mat.albedo_color = ERA_COLORS[0]
	mat.emission_enabled = true
	mat.emission = ERA_COLORS[0]
	mat.emission_energy_multiplier = 1.5
	dot.material_override = mat
	dot.set_meta("mat", mat)
	root.add_child(dot)
	root.set_meta("dot", dot)

	# Anel pulsante ao redor
	var ring = MeshInstance3D.new()
	var torus = TorusMesh.new()
	torus.inner_radius = 0.04
	torus.outer_radius = 0.06
	ring.mesh = torus
	var ring_mat = StandardMaterial3D.new()
	ring_mat.albedo_color = Color(ERA_COLORS[0], 0.4)
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.emission_enabled = true
	ring_mat.emission = ERA_COLORS[0]
	ring_mat.emission_energy_multiplier = 0.5
	ring.material_override = ring_mat
	ring.set_meta("mat", ring_mat)
	root.add_child(ring)
	root.set_meta("ring", ring)

	var crisis = MeshInstance3D.new()
	var crisis_sphere = SphereMesh.new()
	crisis_sphere.radius = 0.075
	crisis_sphere.height = 0.15
	crisis.mesh = crisis_sphere
	var crisis_mat = StandardMaterial3D.new()
	crisis_mat.albedo_color = Color(0.04, 0.0, 0.0, 0.0)
	crisis_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	crisis_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	crisis_mat.emission_enabled = true
	crisis_mat.emission = Color(0.35, 0.02, 0.0)
	crisis_mat.emission_energy_multiplier = 0.0
	crisis.material_override = crisis_mat
	crisis.set_meta("mat", crisis_mat)
	root.add_child(crisis)
	root.set_meta("crisis", crisis)

	return root

# ─────────────────────────────────────────────
#  Converte lat/lon → posição 3D na superfície
# ─────────────────────────────────────────────
func _lat_lon_to_vec3(lat: float, lon: float, radius: float = 1.0) -> Vector3:
	var phi = deg_to_rad(90.0 - lat)
	var theta = deg_to_rad(lon + 180.0)
	return Vector3(
		-sin(phi) * cos(theta) * radius,
		cos(phi) * radius,
		sin(phi) * sin(theta) * radius
	)

# ─────────────────────────────────────────────
#  Atualiza visual dos marcadores conforme dados
# ─────────────────────────────────────────────
func update_country(data: Dictionary) -> void:
	var id = data["id"]
	var marker = markers.get(id)
	if not marker:
		return

	var era = data.get("era", 0)
	var color = ERA_COLORS.get(era, Color.WHITE)
	var pop = data.get("population", 50.0)
	var economy = data.get("economy", 50.0)
	var technology = data.get("technology", 0.0)
	var stability = data.get("stability", 60.0)
	var trend = data.get("trend", {})
	var pop_trend = float(trend.get("population", 0.0))
	var at_war = data.get("at_war_with", []).size() > 0
	var collapsing = stability < 25.0 or economy < 18.0

	var dot = marker.get_meta("dot") as MeshInstance3D
	var mat = dot.get_meta("mat") as StandardMaterial3D
	mat.albedo_color = color
	mat.emission = Color.RED if at_war else color
	mat.emission_energy_multiplier = 3.3 if at_war else 1.4 + technology / 100.0

	var growth_bonus = clampf(pop_trend / 6.0, -0.12, 0.24)
	var scale_factor = 1.0 + (pop / 200.0) * 0.8 + growth_bonus
	dot.scale = Vector3.ONE * scale_factor

	var ring = marker.get_meta("ring") as MeshInstance3D
	var ring_mat = ring.get_meta("mat") as StandardMaterial3D
	var ring_color = Color.RED if at_war else color.lightened(0.15)
	ring_mat.albedo_color = Color(ring_color, 0.52 if at_war else 0.34)
	ring_mat.emission = ring_color
	ring_mat.emission_energy_multiplier = 1.2 if at_war else 0.55

	var crisis = marker.get_meta("crisis") as MeshInstance3D
	var crisis_mat = crisis.get_meta("mat") as StandardMaterial3D
	var crisis_alpha = 0.0
	if collapsing:
		crisis_alpha = clampf((35.0 - min(stability, economy)) / 35.0, 0.18, 0.58)
	crisis_mat.albedo_color = Color(0.09, 0.0, 0.0, crisis_alpha)
	crisis_mat.emission_energy_multiplier = crisis_alpha * 1.8
	crisis.visible = crisis_alpha > 0.01

	_update_city_lights(id, era, technology, economy, collapsing)

func select_country(country_id: int) -> void:
	selected_country_id = country_id
	for id in markers:
		var marker = markers[id] as Node3D
		marker.scale = Vector3.ONE * (1.35 if id == selected_country_id else 1.0)

func _update_city_lights(country_id: int, era: int, technology: float, economy: float, collapsing: bool) -> void:
	var visible_light_count = 0
	if era >= 3:
		visible_light_count = clampi(int((technology + economy) / 18.0), 4, 12)
	elif era == 2 and economy > 70.0:
		visible_light_count = 2

	if visible_light_count <= 0:
		var old = city_lights.get(country_id)
		if old and is_instance_valid(old):
			old.visible = false
		return

	var lights = city_lights.get(country_id)
	if not lights or not is_instance_valid(lights):
		lights = MultiMeshInstance3D.new()
		var mm = MultiMesh.new()
		var sphere = SphereMesh.new()
		sphere.radius = 0.010
		sphere.height = 0.020
		sphere.radial_segments = 8
		sphere.rings = 4
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.82, 0.32)
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.62, 0.16)
		mat.emission_energy_multiplier = 2.2
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		sphere.material = mat
		mm.mesh = sphere
		mm.transform_format = MultiMesh.TRANSFORM_3D
		lights.multimesh = mm
		globe_mesh.add_child(lights)
		city_lights[country_id] = lights

	var mmesh = lights.multimesh
	mmesh.instance_count = visible_light_count
	var positions = _country_light_positions(country_id, visible_light_count)
	var brightness = 0.45 if collapsing else 1.0
	for i in range(visible_light_count):
		var basis = Basis().scaled(Vector3.ONE * (0.75 + float(i % 3) * 0.12) * brightness)
		mmesh.set_instance_transform(i, Transform3D(basis, positions[i]))
	lights.visible = true

func _country_light_positions(country_id: int, count: int) -> Array:
	var pos_data = COUNTRY_POSITIONS.get(country_id)
	if not pos_data:
		return []
	var center = _lat_lon_to_vec3(pos_data["lat"], pos_data["lon"], 1.095)
	var normal = center.normalized()
	var tangent = normal.cross(Vector3.UP)
	if tangent.length_squared() < 0.001:
		tangent = normal.cross(Vector3.RIGHT)
	tangent = tangent.normalized()
	var bitangent = tangent.cross(normal).normalized()
	var points: Array = []
	for i in range(count):
		var angle = float(i) * 2.399
		var radius = 0.025 + float(i % 4) * 0.010
		var offset = (tangent * cos(angle) + bitangent * sin(angle)) * radius
		points.append((center + offset).normalized() * 1.096)
	return points

# ─────────────────────────────────────────────
#  Desenha linha de guerra entre dois países
# ─────────────────────────────────────────────
func draw_war_line(id_a: int, id_b: int) -> void:
	var pos_a_data = COUNTRY_POSITIONS.get(id_a)
	var pos_b_data = COUNTRY_POSITIONS.get(id_b)
	if not pos_a_data or not pos_b_data:
		return

	var pos_a = _lat_lon_to_vec3(pos_a_data["lat"], pos_a_data["lon"], 1.08)
	var pos_b = _lat_lon_to_vec3(pos_b_data["lat"], pos_b_data["lon"], 1.08)

	# Arco entre os dois pontos
	var points = PackedVector3Array()
	for i in range(21):
		var t = float(i) / 20.0
		var lerped = pos_a.lerp(pos_b, t)
		lerped = lerped.normalized() * 1.12   # arco levemente elevado
		points.append(lerped)

	var line_geo = ImmediateMesh.new()
	line_geo.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for p in points:
		line_geo.surface_add_vertex(p)
	line_geo.surface_end()

	var line_mesh = MeshInstance3D.new()
	line_mesh.mesh = line_geo
	var line_mat = StandardMaterial3D.new()
	line_mat.albedo_color = Color(1.0, 0.08, 0.04, 0.88)
	line_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	line_mat.emission_enabled = true
	line_mat.emission = Color.RED
	line_mat.emission_energy_multiplier = 2.6
	line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line_mesh.material_override = line_mat
	line_mesh.set_meta("mat", line_mat)
	line_mesh.set_meta("born", _time)
	globe_mesh.add_child(line_mesh)
	war_lines.append(line_mesh)

	_spawn_impact_flash(pos_a)
	_spawn_impact_flash(pos_b)

	# Remove a linha após 3 segundos
	var timer = get_tree().create_timer(3.0)
	timer.timeout.connect(func():
		if is_instance_valid(line_mesh):
			line_mesh.queue_free()
		war_lines.erase(line_mesh)
	)

func _spawn_impact_flash(pos: Vector3) -> void:
	var flash = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.035
	sphere.height = 0.070
	sphere.radial_segments = 12
	sphere.rings = 6
	flash.mesh = sphere
	flash.position = pos.normalized() * 1.105
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.18, 0.04, 0.7)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.10, 0.02)
	mat.emission_energy_multiplier = 3.0
	flash.material_override = mat
	flash.set_meta("born", _time)
	flash.set_meta("mat", mat)
	globe_mesh.add_child(flash)
	war_lines.append(flash)
	var timer = get_tree().create_timer(1.6)
	timer.timeout.connect(func():
		if is_instance_valid(flash):
			flash.queue_free()
		war_lines.erase(flash)
	)

# ─────────────────────────────────────────────
#  Rotação por drag do mouse / toque
# ─────────────────────────────────────────────
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_dragging = true
				_last_mouse = event.position
				_rotation_velocity = Vector2.ZERO
				_drag_distance = 0.0
			else:
				_dragging = false
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom = max(2.0, _zoom - 0.3)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom = min(7.0, _zoom + 0.3)

	elif event is InputEventMouseMotion:
		if _dragging:
			var delta = event.position - _last_mouse
			_drag_distance += delta.length()
			_rotation_velocity = delta * 0.005
			globe_mesh.rotation.y += delta.x * 0.005
			globe_mesh.rotation.x += delta.y * 0.005
			globe_mesh.rotation.x = clampf(globe_mesh.rotation.x, -1.3, 1.3)
			_last_mouse = event.position

	elif event is InputEventScreenTouch:
		_dragging = event.pressed
		if event.pressed:
			_last_mouse = event.position

	elif event is InputEventScreenDrag:
		var delta = event.position - _last_mouse
		globe_mesh.rotation.y += delta.x * 0.005
		globe_mesh.rotation.x += delta.y * 0.005
		globe_mesh.rotation.x = clampf(globe_mesh.rotation.x, -1.3, 1.3)
		_last_mouse = event.position

func handle_click(viewport_pos: Vector2) -> void:
	_try_select_country(viewport_pos)

# ─────────────────────────────────────────────
#  Tenta selecionar um país via raycast
# ─────────────────────────────────────────────
func _try_select_country(_screen_pos: Vector2) -> void:
	var viewport_pos = get_viewport().get_mouse_position()
	var selected_id = _pick_marker_from_screen(viewport_pos)
	if selected_id > 0:
		emit_signal("country_selected", selected_id)
		return

	var from = camera.project_ray_origin(viewport_pos)
	var to = from + camera.project_ray_normal(viewport_pos) * 100.0

	var space = get_world_3d().direct_space_state
	var params = PhysicsRayQueryParameters3D.create(from, to)
	var result = space.intersect_ray(params)
	if result and result.collider:
		var id = result.collider.get_meta("country_id", -1)
		if id > 0:
			emit_signal("country_selected", id)

func _pick_marker_from_screen(screen_pos: Vector2) -> int:
	var closest_id = -1
	var closest_distance = 48.0

	for id in markers:
		var marker = markers[id] as Node3D
		var marker_pos = marker.global_transform.origin
		if camera.is_position_behind(marker_pos):
			continue

		var projected = camera.unproject_position(marker_pos)
		var distance = projected.distance_to(screen_pos)
		if distance < closest_distance:
			closest_distance = distance
			closest_id = id

	return closest_id

# ─────────────────────────────────────────────
#  _process: animações contínuas
# ─────────────────────────────────────────────
func _process(delta: float) -> void:
	_time += delta

	if not globe_mesh or not camera:
		return

	if not _dragging:
		globe_mesh.rotation.y += 0.15 * delta
		_rotation_velocity = _rotation_velocity.lerp(Vector2.ZERO, 0.05)

	camera.position.z = lerp(camera.position.z, _zoom, delta * 5.0)

	if cloud_mesh:
		cloud_mesh.rotation.y += 0.035 * delta
		cloud_mesh.rotation.x = sin(_time * 0.12) * 0.035
	if atmosphere_mesh:
		var atmo_pulse = 1.0 + sin(_time * 0.6) * 0.006
		atmosphere_mesh.scale = Vector3.ONE * atmo_pulse

	# Pulso dos marcadores
	for id in markers:
		var marker = markers[id] as Node3D
		var ring = marker.get_meta("ring") as MeshInstance3D
		var crisis = marker.get_meta("crisis") as MeshInstance3D
		var pulse = 0.8 + sin(_time * 2.0 + id * 0.7) * 0.2
		ring.scale = Vector3.ONE * pulse
		if crisis.visible:
			crisis.scale = Vector3.ONE * (0.9 + sin(_time * 3.4 + id) * 0.12)

	for item in war_lines.duplicate():
		if not is_instance_valid(item):
			war_lines.erase(item)
			continue
		var mat = item.get_meta("mat", null) as StandardMaterial3D
		if mat:
			var age = _time - float(item.get_meta("born", _time))
			var pulse = 1.0 + sin(_time * 8.0 + age) * 0.35
			mat.emission_energy_multiplier = 1.8 + pulse * 1.5
			if item is MeshInstance3D:
				item.scale = Vector3.ONE * (1.0 + sin(_time * 7.0 + age) * 0.08)
