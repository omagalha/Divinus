# ─────────────────────────────────────────────
#  globe_integration.gd
#  Cola o Globe3D com o WorldSimulator existente
#  Adiciona esse script como filho do WorldMap
# ─────────────────────────────────────────────
extends Node

var simulator: WorldSimulator = null
var globe: Node3D = null

func _ready() -> void:
	var globe_scene = load("res://scenes/Globe3D.tscn")
	if not globe_scene:
		push_error("Globe3D.tscn não encontrada. Cria a cena primeiro.")
		return

	globe = globe_scene.instantiate()
	get_parent().add_child(globe)
	globe.connect("country_selected", Callable(self, "_on_country_selected"))

# Chamado por world_map._ready() após criar o simulator
func initialize(sim: WorldSimulator) -> void:
	simulator = sim
	simulator.turn_completed.connect(_on_turn_completed)
	_refresh_globe()

func _on_turn_completed(_year: int, _news: Array) -> void:
	_refresh_globe()
	# Desenha linhas de guerra nos países em conflito
	var snapshot = simulator.get_world_snapshot()
	for data in snapshot:
		for enemy_id in data["at_war_with"]:
			if enemy_id > data["id"]:  # evita duplicata
				globe.draw_war_line(data["id"], enemy_id)

func _refresh_globe() -> void:
	if not globe:
		return
	var snapshot = simulator.get_world_snapshot()
	for data in snapshot:
		globe.update_country(data)

func _on_country_selected(country_id: int) -> void:
	# Repassa para o world_map usar os poderes
	if get_parent().has_method("_on_country_dot_pressed"):
		get_parent()._on_country_dot_pressed(country_id)
