class_name CivilizationLayer
extends Node3D

signal era_changed(old_era: int, new_era: int)

const CLUSTER_RADIUS := 0.075
const BASE_SCALE := 0.045
const MAX_STRUCTURES := 18
const MODERN_MODEL_SCALE := 0.032
const MODERN_CITY_MODELS := [
	"res://assets/civilizations/modern/city/commercial/low-detail-building-a.glb",
	"res://assets/civilizations/modern/city/commercial/low-detail-building-b.glb",
	"res://assets/civilizations/modern/city/commercial/low-detail-building-c.glb",
	"res://assets/civilizations/modern/city/commercial/low-detail-building-d.glb",
	"res://assets/civilizations/modern/city/commercial/building-skyscraper-a.glb",
	"res://assets/civilizations/modern/city/commercial/building-skyscraper-b.glb",
]
const MODERN_INDUSTRIAL_MODEL := "res://assets/civilizations/modern/city/industrial/building-a.glb"
const MODERN_CHIMNEY_MODEL := "res://assets/civilizations/modern/city/industrial/chimney-medium.glb"

var _country_id: int = -1
var _current_era: int = -1
var _country_data: Dictionary = {}
var _structures: Array[Node3D] = []
var _effects: Array[Node3D] = []
var _lights: Array[OmniLight3D] = []
var _orbiters: Array[Node3D] = []
var _time := 0.0
var _collapse_active := false

func setup(country_id: int) -> void:
	_country_id = country_id

func update_civilization(data: Dictionary) -> void:
	_country_data = data
	var new_era = int(data.get("era", 0))
	if new_era != _current_era:
		var old_era = _current_era
		_current_era = new_era
		_rebuild()
		emit_signal("era_changed", old_era, new_era)
	else:
		_update_intensity()

	if float(data.get("stability", 60.0)) < 22.0 or float(data.get("economy", 50.0)) < 16.0:
		trigger_collapse_effect()

func trigger_war_effect() -> void:
	for i in range(3):
		var flash = _make_light(Color(1.0, 0.08, 0.04), 1.7, 0.22)
		flash.position = _cluster_pos(i, 3, 0.040)
		_lights.append(flash)
		add_child(flash)
		var timer = get_tree().create_timer(0.7 + float(i) * 0.22)
		timer.timeout.connect(func():
			if is_instance_valid(flash):
				flash.queue_free()
			_lights.erase(flash)
		)

func trigger_collapse_effect() -> void:
	if _collapse_active:
		return
	_collapse_active = true
	for light in _lights:
		if is_instance_valid(light):
			light.light_color = light.light_color.lerp(Color(0.9, 0.05, 0.02), 0.55)
			light.light_energy *= 0.55
	for i in range(min(3, _structures.size())):
		var ember = _make_beacon(Color(0.95, 0.12, 0.02), 0.010)
		ember.position = _cluster_pos(i, 3, 0.050)
		_structures.append(ember)
		add_child(ember)

func trigger_power_effect(power_id: String) -> void:
	match power_id:
		"bless":
			_spawn_timed_beacon(Color(1.0, 0.82, 0.18), 0.018, 1.4)
		"economic_crisis":
			_add_smoke(Color(0.18, 0.16, 0.14, 0.45), 14, 1.8, Vector3.ZERO)
		"tech_boost":
			_spawn_timed_beacon(Color(0.20, 0.70, 1.0), 0.016, 1.2)
		"natural_disaster":
			trigger_collapse_effect()
			_add_smoke(Color(0.34, 0.28, 0.23, 0.55), 20, 2.2, Vector3(0.018, 0.0, -0.010))
		"force_peace":
			_spawn_timed_beacon(Color(0.70, 1.0, 0.78), 0.015, 1.0)
		"spread_ideology":
			_spawn_timed_beacon(Color(0.90, 0.45, 1.0), 0.014, 1.1)
		"regress":
			_spawn_timed_beacon(Color(0.45, 0.50, 0.60), 0.014, 1.0)

func get_visual_state() -> Dictionary:
	return {
		"country_id": _country_id,
		"era": _current_era,
		"structures": _structures.size(),
		"effects": _effects.size(),
		"lights": _lights.size(),
		"orbiters": _orbiters.size(),
		"collapse": _collapse_active,
	}

func _rebuild() -> void:
	_clear()
	_collapse_active = false
	match _current_era:
		0:
			_build_tribal()
		1:
			_build_ancient()
		2:
			_build_medieval()
		3:
			_build_modern()
		4:
			_build_future()
		_:
			_build_tribal()
	_update_intensity()

func _clear() -> void:
	for node in _structures + _effects + _lights + _orbiters:
		if is_instance_valid(node):
			node.queue_free()
	_structures.clear()
	_effects.clear()
	_lights.clear()
	_orbiters.clear()

func _build_tribal() -> void:
	_add_structure(_make_pad(Color(0.22, 0.34, 0.18)), Vector3.ZERO)
	var count = clampi(int(float(_country_data.get("population", 20.0)) / 28.0), 1, 5)
	for i in range(count):
		_add_structure(_make_cone(Color(0.48, 0.30, 0.16), BASE_SCALE * 0.55, BASE_SCALE * 0.95), _cluster_pos(i, count, 0.040))
	_add_structure(_make_beacon(Color(1.0, 0.45, 0.08), 0.010), Vector3.ZERO)
	_add_smoke(Color(0.50, 0.44, 0.36, 0.22), 8, 2.0, Vector3.ZERO)
	_add_light(Color(1.0, 0.42, 0.08), 0.45, 0.16, true)

func _build_ancient() -> void:
	_add_structure(_make_pad(Color(0.48, 0.40, 0.18)), Vector3.ZERO)
	var faith = float(_country_data.get("faith", 40.0))
	var farms = clampi(int(float(_country_data.get("economy", 40.0)) / 24.0), 1, 4)
	_add_structure(_make_box(Color(0.82, 0.70, 0.43), Vector3(0.030, 0.026 + faith / 2200.0, 0.030)), Vector3.ZERO)
	for i in range(farms):
		_add_structure(_make_box(Color(0.46, 0.62, 0.28), Vector3(0.028, 0.008, 0.020)), _cluster_pos(i, farms, 0.055))
		_add_structure(_make_road(0.055, 0.006, Color(0.55, 0.45, 0.28), float(i) / max(1.0, float(farms)) * TAU), Vector3.ZERO)
	if faith > 65.0:
		_add_structure(_make_cone(Color(0.86, 0.74, 0.46), 0.026, 0.046), Vector3(0.045, 0.000, 0.016))
	_add_light(Color(1.0, 0.78, 0.34), 0.42, 0.18, false)

func _build_medieval() -> void:
	_add_structure(_make_pad(Color(0.22, 0.38, 0.24)), Vector3.ZERO)
	var military = float(_country_data.get("military", 45.0))
	var villages = clampi(int(float(_country_data.get("population", 65.0)) / 35.0), 2, 6)
	if military > 45.0:
		_add_structure(_make_box(Color(0.50, 0.48, 0.42), Vector3(0.038, 0.052, 0.038)), Vector3.ZERO)
	for i in range(villages):
		_add_structure(_make_cone(Color(0.45, 0.28, 0.18), 0.018, 0.038), _cluster_pos(i, villages, 0.060))
		_add_structure(_make_road(0.064, 0.005, Color(0.36, 0.31, 0.24), float(i) / max(1.0, float(villages)) * TAU), Vector3.ZERO)
	if float(_country_data.get("faith", 40.0)) > 55.0:
		_add_structure(_make_box(Color(0.78, 0.72, 0.60), Vector3(0.020, 0.052, 0.020)), Vector3(-0.050, 0.000, 0.030))
	_add_smoke(Color(0.50, 0.50, 0.48, 0.18), villages * 3, 2.8, Vector3.ZERO)
	_add_light(Color(1.0, 0.62, 0.24), 0.55, 0.20, true)

func _build_modern() -> void:
	_add_structure(_make_pad(Color(0.12, 0.24, 0.34)), Vector3.ZERO)
	var pop = float(_country_data.get("population", 90.0))
	var tech = float(_country_data.get("technology", 45.0))
	var count = clampi(int(pop / 13.0), 5, MAX_STRUCTURES)
	for i in range(count):
		var height = 0.032 + tech / 1700.0 + float(i % 4) * 0.006
		_add_structure(_make_modern_building(i, height, tech), _cluster_pos(i, count, 0.070))
	if float(_country_data.get("economy", 50.0)) > 55.0:
		_add_structure(_make_modern_industrial_site(), Vector3(-0.065, 0.000, -0.018))
	_add_pollution_if_needed()
	_add_light(Color(1.0, 0.86, 0.48), 0.82, 0.26, false)
	if tech > 60.0:
		_add_light(Color(0.9, 0.12, 0.10), 0.30, 0.10, true)

func _build_future() -> void:
	_add_structure(_make_pad(Color(0.26, 0.12, 0.40)), Vector3.ZERO)
	var tech = float(_country_data.get("technology", 80.0))
	_add_structure(_make_box(Color(0.42, 0.18, 0.72), Vector3(0.028, 0.080 + tech / 2400.0, 0.028)), Vector3.ZERO)
	for i in range(4):
		var orbiter = _make_beacon(Color(0.1, 0.85, 1.0), 0.007)
		orbiter.set_meta("orbit_radius", 0.052 + float(i) * 0.016)
		orbiter.set_meta("orbit_speed", 0.9 + float(i) * 0.24)
		orbiter.set_meta("orbit_offset", float(i) / 4.0 * TAU)
		_orbiters.append(orbiter)
		add_child(orbiter)
	_add_light(Color(0.64, 0.12, 1.0), 1.25, 0.30, false)
	_add_light(Color(0.1, 0.82, 1.0), 0.62, 0.22, true)
	if str(_country_data.get("visual", {}).get("energy_type", "")) == "dirty_hightech":
		_add_smoke(Color(0.25, 0.14, 0.32, 0.25), 10, 2.8, Vector3.ZERO)

func _process(delta: float) -> void:
	_time += delta
	for light in _lights:
		if not is_instance_valid(light):
			continue
		if light.get_meta("pulse", false):
			var base = float(light.get_meta("base_energy", light.light_energy))
			light.light_energy = base * (0.78 + sin(_time * 4.0 + float(light.get_instance_id() % 11)) * 0.22)
	for orbiter in _orbiters:
		if not is_instance_valid(orbiter):
			continue
		var radius = float(orbiter.get_meta("orbit_radius", 0.060))
		var speed = float(orbiter.get_meta("orbit_speed", 1.0))
		var offset = float(orbiter.get_meta("orbit_offset", 0.0))
		var angle = _time * speed + offset
		orbiter.position = Vector3(cos(angle) * radius, 0.020 + sin(angle * 1.7) * 0.010, sin(angle) * radius)
		orbiter.rotation.y += delta * 2.0

func _update_intensity() -> void:
	var at_war = _country_data.get("at_war_with", []).size() > 0
	var tech = float(_country_data.get("technology", 30.0))
	var population = float(_country_data.get("population", 40.0))
	scale = Vector3.ONE * clampf(0.75 + population / 260.0, 0.75, 1.55)
	for light in _lights:
		if not is_instance_valid(light):
			continue
		if at_war:
			light.light_color = light.light_color.lerp(Color(1.0, 0.08, 0.04), 0.45)
		elif _current_era >= 3:
			light.light_energy = max(light.light_energy, 0.35 + tech / 120.0)

func _add_pollution_if_needed() -> void:
	var visual = _country_data.get("visual", {})
	var pollution = float(visual.get("pollution", 0.0))
	if pollution < 35.0:
		return
	var alpha = clampf(pollution / 150.0, 0.18, 0.55)
	_add_smoke(Color(0.26, 0.25, 0.23, alpha), clampi(int(pollution / 4.0), 8, 24), 3.8, Vector3(-0.030, 0.0, 0.010))

func _add_smoke(color: Color, amount: int, lifetime: float, pos: Vector3) -> void:
	var particles = CPUParticles3D.new()
	particles.position = pos + Vector3(0.0, 0.030, 0.0)
	particles.amount = amount
	particles.lifetime = lifetime
	particles.emitting = true
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 0.010
	particles.direction = Vector3(0.1, 1.0, 0.0)
	particles.spread = 35.0
	particles.gravity = Vector3(0.0, 0.010, 0.0)
	particles.initial_velocity_min = 0.010
	particles.initial_velocity_max = 0.028
	particles.scale_amount_min = 0.006
	particles.scale_amount_max = 0.017
	particles.color = color
	_effects.append(particles)
	add_child(particles)

func _spawn_timed_beacon(color: Color, radius: float, lifetime: float) -> void:
	var beacon = _make_beacon(color, radius)
	beacon.position = Vector3(0.0, 0.020, 0.0)
	_effects.append(beacon)
	add_child(beacon)
	var light = _make_light(color, 1.2, 0.20)
	light.set_meta("pulse", true)
	light.set_meta("base_energy", 1.2)
	_lights.append(light)
	add_child(light)
	var timer = get_tree().create_timer(lifetime)
	timer.timeout.connect(func():
		if is_instance_valid(beacon):
			beacon.queue_free()
		if is_instance_valid(light):
			light.queue_free()
		_effects.erase(beacon)
		_lights.erase(light)
	)

func _cluster_pos(index: int, total: int, radius: float) -> Vector3:
	var angle = float(index) / max(1.0, float(total)) * TAU + float(_country_id) * 0.41
	return Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)

func _add_structure(node: Node3D, pos: Vector3) -> void:
	node.position += pos
	_structures.append(node)
	add_child(node)

func _make_modern_building(index: int, fallback_height: float, tech: float) -> Node3D:
	var model_path = str(MODERN_CITY_MODELS[index % MODERN_CITY_MODELS.size()])
	var model_scale = MODERN_MODEL_SCALE * clampf(0.85 + tech / 260.0, 0.85, 1.25)
	var model = _make_imported_model(model_path, model_scale, float(index % 8) * TAU / 8.0)
	if model:
		return model
	return _make_box(Color(0.18, 0.34, 0.48), Vector3(0.018, fallback_height, 0.018))

func _make_modern_industrial_site() -> Node3D:
	var root = Node3D.new()
	var factory = _make_imported_model(MODERN_INDUSTRIAL_MODEL, MODERN_MODEL_SCALE * 0.95, -0.25)
	if factory:
		factory.position = Vector3.ZERO
		root.add_child(factory)
	else:
		var fallback = _make_box(Color(0.34, 0.34, 0.32), Vector3(0.045, 0.030, 0.024))
		root.add_child(fallback)

	var chimney = _make_imported_model(MODERN_CHIMNEY_MODEL, MODERN_MODEL_SCALE * 0.75, 0.15)
	if chimney:
		chimney.position = Vector3(0.025, 0.0, -0.010)
		root.add_child(chimney)
	return root

func _make_imported_model(path: String, model_scale: float, rotation_y: float) -> Node3D:
	if not ResourceLoader.exists(path):
		return null
	var resource = load(path)
	if not resource is PackedScene:
		return null
	var root = Node3D.new()
	var scene = (resource as PackedScene).instantiate()
	if not scene is Node3D:
		scene.queue_free()
		return null
	root.add_child(scene)
	scene.scale = Vector3.ONE * model_scale
	scene.rotation.y = rotation_y
	scene.position.y = 0.006
	return root

func _make_pad(color: Color) -> MeshInstance3D:
	var mesh = CylinderMesh.new()
	mesh.top_radius = CLUSTER_RADIUS
	mesh.bottom_radius = CLUSTER_RADIUS
	mesh.height = 0.006
	mesh.radial_segments = 18
	var node = MeshInstance3D.new()
	node.mesh = mesh
	node.position.y = 0.003
	node.material_override = _make_mat(Color(color, 0.92))
	return node

func _add_light(color: Color, energy: float, light_range: float, pulse: bool) -> void:
	var light = _make_light(color, energy, light_range)
	if pulse:
		light.set_meta("pulse", true)
		light.set_meta("base_energy", energy)
	_lights.append(light)
	add_child(light)

func _make_light(color: Color, energy: float, light_range: float) -> OmniLight3D:
	var light = OmniLight3D.new()
	light.light_color = color
	light.light_energy = energy
	light.omni_range = light_range
	light.shadow_enabled = false
	return light

func _make_box(color: Color, size: Vector3) -> MeshInstance3D:
	var mesh = BoxMesh.new()
	mesh.size = size
	var node = MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = _make_mat(color)
	node.position.y = size.y * 0.5
	return node

func _make_cone(color: Color, radius: float, height: float) -> MeshInstance3D:
	var mesh = CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 6
	var node = MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = _make_mat(color)
	node.position.y = height * 0.5
	return node

func _make_beacon(color: Color, radius: float) -> MeshInstance3D:
	var mesh = SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 8
	mesh.rings = 4
	var node = MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = _make_mat(color, true)
	return node

func _make_road(length: float, width: float, color: Color, angle: float) -> MeshInstance3D:
	var node = _make_box(color, Vector3(width, 0.004, length))
	node.rotation.y = angle
	node.position.y = 0.002
	return node

func _make_mat(color: Color, emissive := false) -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.82
	if emissive:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 1.5
	return mat
