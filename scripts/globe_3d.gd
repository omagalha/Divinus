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

const MAP_SEED = 42077
const CONTINENT_COUNT = 7

var globe_mesh: MeshInstance3D
var continent_meshes: Array = []
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
	_generate_procedural_continents(MAP_SEED)
	_build_globe_guides()
	_build_atmosphere()
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
	var world_env = WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

# ─────────────────────────────────────────────
#  Constrói o globo principal
# ─────────────────────────────────────────────
func _build_globe() -> void:
	globe_mesh = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 64
	sphere.rings = 32
	globe_mesh.mesh = sphere

	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.07, 0.28, 0.58)
	mat.metallic = 0.0
	mat.roughness = 0.55
	mat.emission_enabled = true
	mat.emission = Color(0.03, 0.18, 0.40)
	mat.emission_energy_multiplier = 1.8
	globe_mesh.material_override = mat
	add_child(globe_mesh)

func _generate_procedural_continents(seed_value: int) -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_value

	var land_mat = StandardMaterial3D.new()
	land_mat.albedo_color = Color(0.16, 0.44, 0.25)
	land_mat.roughness = 0.85
	land_mat.emission_enabled = true
	land_mat.emission = Color(0.02, 0.11, 0.04)
	land_mat.emission_energy_multiplier = 0.45

	var coast_mat = StandardMaterial3D.new()
	coast_mat.albedo_color = Color(0.54, 0.74, 0.48, 0.75)
	coast_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	coast_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var centers = _continent_centers(rng)
	for center in centers:
		var land = _make_continent_blob(center["lat"], center["lon"], center["radius"], center["stretch"], center["tilt"], rng)
		land.material_override = land_mat
		globe_mesh.add_child(land)
		continent_meshes.append(land)

		var coast = _make_continent_outline(center["lat"], center["lon"], center["radius"], center["stretch"], center["tilt"], rng)
		coast.material_override = coast_mat
		globe_mesh.add_child(coast)
		continent_meshes.append(coast)

func _continent_centers(rng: RandomNumberGenerator) -> Array:
	var centers: Array = []
	for i in range(CONTINENT_COUNT):
		centers.append({
			"lat": rng.randf_range(-48.0, 58.0),
			"lon": rng.randf_range(-175.0, 175.0),
			"radius": rng.randf_range(12.0, 28.0),
			"stretch": rng.randf_range(0.55, 1.45),
			"tilt": rng.randf_range(0.0, TAU),
		})

	# Garante massas de terra próximas aos países atuais.
	centers.append({"lat": 45.0, "lon": 10.0, "radius": 24.0, "stretch": 1.25, "tilt": 0.5})
	centers.append({"lat": -18.0, "lon": -65.0, "radius": 23.0, "stretch": 0.8, "tilt": 1.2})
	centers.append({"lat": -18.0, "lon": 130.0, "radius": 16.0, "stretch": 1.0, "tilt": 0.2})
	return centers

func _make_continent_blob(lat: float, lon: float, radius_deg: float, stretch: float, tilt: float, rng: RandomNumberGenerator) -> MeshInstance3D:
	var mesh = ImmediateMesh.new()
	var segments = 34
	var center = _lat_lon_to_vec3(lat, lon, 1.025)
	var border = _continent_border_points(lat, lon, radius_deg, stretch, tilt, rng, segments, 1.027)

	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(segments):
		var a = border[i]
		var b = border[(i + 1) % segments]
		mesh.surface_add_vertex(center)
		mesh.surface_add_vertex(a)
		mesh.surface_add_vertex(b)
	mesh.surface_end()

	var instance = MeshInstance3D.new()
	instance.mesh = mesh
	return instance

func _make_continent_outline(lat: float, lon: float, radius_deg: float, stretch: float, tilt: float, rng: RandomNumberGenerator) -> MeshInstance3D:
	var mesh = ImmediateMesh.new()
	var segments = 52
	var border = _continent_border_points(lat, lon, radius_deg, stretch, tilt, rng, segments, 1.031)

	mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for point in border:
		mesh.surface_add_vertex(point)
	mesh.surface_add_vertex(border[0])
	mesh.surface_end()

	var instance = MeshInstance3D.new()
	instance.mesh = mesh
	return instance

func _continent_border_points(lat: float, lon: float, radius_deg: float, stretch: float, tilt: float, rng: RandomNumberGenerator, segments: int, surface_radius: float) -> Array:
	var points: Array = []
	for i in range(segments):
		var angle = float(i) / float(segments) * TAU
		var local_x = cos(angle)
		var local_y = sin(angle)
		var rotated_x = local_x * cos(tilt) - local_y * sin(tilt)
		var rotated_y = local_x * sin(tilt) + local_y * cos(tilt)
		var wobble = 0.74 + rng.randf() * 0.42 + sin(angle * 3.0 + lat) * 0.08
		var d_lat = rotated_y * radius_deg * wobble / max(0.45, stretch)
		var d_lon = rotated_x * radius_deg * wobble * stretch / max(0.35, cos(deg_to_rad(lat)))
		points.append(_lat_lon_to_vec3(clampf(lat + d_lat, -78.0, 78.0), _wrap_lon(lon + d_lon), surface_radius))
	return points

func _wrap_lon(lon: float) -> float:
	var wrapped = fmod(lon + 180.0, 360.0)
	if wrapped < 0.0:
		wrapped += 360.0
	return wrapped - 180.0

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
	var atmo = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 1.04
	sphere.height = 2.08
	sphere.radial_segments = 32
	sphere.rings = 16
	atmo.mesh = sphere

	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.25, 0.65, 1.0, 0.18)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_FRONT
	mat.emission_enabled = true
	mat.emission = Color(0.08, 0.32, 0.8)
	mat.emission_energy_multiplier = 0.7
	atmo.material_override = mat
	add_child(atmo)

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
	var at_war = data.get("at_war_with", []).size() > 0

	var dot = marker.get_meta("dot") as MeshInstance3D
	var mat = dot.get_meta("mat") as StandardMaterial3D
	mat.albedo_color = color
	mat.emission = Color.RED if at_war else color
	mat.emission_energy_multiplier = 3.0 if at_war else 1.5

	var scale_factor = 1.0 + (pop / 200.0) * 0.8
	dot.scale = Vector3.ONE * scale_factor

	var ring = marker.get_meta("ring") as MeshInstance3D
	var ring_mat = ring.get_meta("mat") as StandardMaterial3D
	ring_mat.albedo_color = Color(Color.RED if at_war else color, 0.4)
	ring_mat.emission = Color.RED if at_war else color

func select_country(country_id: int) -> void:
	selected_country_id = country_id
	for id in markers:
		var marker = markers[id] as Node3D
		marker.scale = Vector3.ONE * (1.35 if id == selected_country_id else 1.0)

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
	line_mat.albedo_color = Color.RED
	line_mat.emission_enabled = true
	line_mat.emission = Color.RED
	line_mat.emission_energy_multiplier = 2.0
	line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line_mesh.material_override = line_mat
	add_child(line_mesh)
	war_lines.append(line_mesh)

	# Remove a linha após 3 segundos
	var timer = get_tree().create_timer(3.0)
	timer.timeout.connect(func():
		if is_instance_valid(line_mesh):
			line_mesh.queue_free()
		war_lines.erase(line_mesh)
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
		globe_mesh.rotation.y += 0.001
		_rotation_velocity = _rotation_velocity.lerp(Vector2.ZERO, 0.05)

	camera.position.z = lerp(camera.position.z, _zoom, delta * 5.0)

	# Pulso dos marcadores
	for id in markers:
		var marker = markers[id] as Node3D
		var ring = marker.get_meta("ring") as MeshInstance3D
		var pulse = 0.8 + sin(_time * 2.0 + id * 0.7) * 0.2
		ring.scale = Vector3.ONE * pulse
