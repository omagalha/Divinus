extends Node

var simulator: WorldSimulator
var selected_country_id: int = -1
var selected_power_id: String = ""

var label_year: Label
var label_points: Label
var label_selected_country: Label
var country_detail_label: Label
var news_container: VBoxContainer
var globe: Node3D
var globe_viewport: SubViewport
var globe_container: SubViewportContainer
var _globe_press_pos: Vector2 = Vector2.ZERO
var country_nodes: Dictionary = {}
var power_buttons: Array = []
var country_buttons: Dictionary = {}

# Posições dos países no mapa (% da área do mapa)
const COUNTRY_POSITIONS = {
	1: Vector2(0.20, 0.30),  # Valdoria
	2: Vector2(0.55, 0.20),  # Kharuum
	3: Vector2(0.75, 0.35),  # Sylveth
	4: Vector2(0.40, 0.55),  # Dorrakan
	5: Vector2(0.15, 0.60),  # Aeloria
	6: Vector2(0.65, 0.65),  # Vrexmoor
	7: Vector2(0.30, 0.75),  # Thessomar
	8: Vector2(0.80, 0.75),  # Korrath
	9: Vector2(0.50, 0.40),  # Lunaris
	10: Vector2(0.85, 0.50), # Zethara
}

const ERA_COLORS = {
	0: Color(0.6, 0.4, 0.2),   # Tribal — marrom
	1: Color(0.7, 0.6, 0.2),   # Antiga — dourado
	2: Color(0.3, 0.6, 0.4),   # Medieval — verde
	3: Color(0.2, 0.5, 0.9),   # Moderna — azul
	4: Color(0.8, 0.2, 0.9),   # Futura — roxo
}

func _ready() -> void:
	simulator = WorldSimulator.new()
	add_child(simulator)
	simulator.apply_scenario(str(ProjectSettings.get_setting("divinus/selected_scenario", "standard")))
	simulator.turn_completed.connect(_on_turn_completed)
	simulator.game_over.connect(_on_game_over)

	_build_ui()
	_refresh_ui()
	_add_news([simulator.get_scenario_intro()])

# ─────────────────────────────────────────────
#  Layout desktop: tudo visível de uma vez
#
#  ┌──────────────────────────────────────────┐
#  │  HEADER: título | ano | pontos           │
#  ├─────────────────────┬────────────────────┤
#  │                     │  📰 NOTÍCIAS       │
#  │    MAPA VISUAL      │  (scroll)          │
#  │  (países/bolinhas)  │                    │
#  │                     │                    │
#  ├─────────────────────┴────────────────────┤
#  │  PODERES  [⚡Abençoar] [📉Crise] ...     │
#  │  [ ▶  AVANÇAR 1 ANO ]                   │
#  └──────────────────────────────────────────┘
# ─────────────────────────────────────────────
func _build_ui() -> void:
	var root = VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)

	# HEADER
	root.add_child(_make_header())

	# MEIO: mapa + notícias lado a lado
	var middle = HSplitContainer.new()
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle.split_offset = 700
	root.add_child(middle)

	middle.add_child(_make_map_panel())
	middle.add_child(_make_news_panel())

	# FOOTER: poderes + botão avançar
	root.add_child(_make_footer())

# ─────────────────────────────────────────────
#  HEADER
# ─────────────────────────────────────────────
func _make_header() -> Control:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 60)
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 30)
	panel.add_child(hbox)

	var title = Label.new()
	title.text = "⚡ DIVINUS"
	title.add_theme_font_size_override("font_size", 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(title)

	var sep = Label.new()
	sep.text = "Simulador de Civilizações"
	sep.add_theme_font_size_override("font_size", 16)
	sep.modulate = Color(0.6, 0.6, 0.6)
	sep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(sep)

	label_year = Label.new()
	label_year.text = "📅 Ano 1"
	label_year.add_theme_font_size_override("font_size", 22)
	hbox.add_child(label_year)

	label_points = Label.new()
	label_points.text = "   ⚡ 5 pontos"
	label_points.add_theme_font_size_override("font_size", 22)
	label_points.modulate = Color(1.0, 0.85, 0.2)
	hbox.add_child(label_points)

	return panel

# ─────────────────────────────────────────────
#  MAPA VISUAL com bolinhas
# ─────────────────────────────────────────────
func _make_map_panel() -> Control:
	var panel = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(vbox)

	var title = Label.new()
	title.text = "🌍 GLOBO MUNDIAL"
	title.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title)

	label_selected_country = Label.new()
	label_selected_country.text = "Selecione um país no globo."
	label_selected_country.add_theme_font_size_override("font_size", 14)
	label_selected_country.modulate = Color(0.75, 0.75, 0.75)
	vbox.add_child(label_selected_country)

	var detail_panel = PanelContainer.new()
	detail_panel.custom_minimum_size = Vector2(0, 122)
	vbox.add_child(detail_panel)

	country_detail_label = Label.new()
	country_detail_label.text = "Clique em um marcador para abrir a ficha do país."
	country_detail_label.add_theme_font_size_override("font_size", 13)
	country_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	country_detail_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	country_detail_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	country_detail_label.modulate = Color(0.86, 0.86, 0.86)
	detail_panel.add_child(country_detail_label)

	# Legenda de eras
	var legend = HBoxContainer.new()
	legend.add_theme_constant_override("separation", 12)
	vbox.add_child(legend)

	var era_names = ["Tribal", "Antiga", "Medieval", "Moderna", "Futura"]
	var era_colors_list = [Color(0.6,0.4,0.2), Color(0.7,0.6,0.2), Color(0.3,0.6,0.4), Color(0.2,0.5,0.9), Color(0.8,0.2,0.9)]
	for i in range(5):
		var dot = Label.new()
		dot.text = "● " + era_names[i]
		dot.add_theme_font_size_override("font_size", 13)
		dot.modulate = era_colors_list[i]
		legend.add_child(dot)

	globe_container = SubViewportContainer.new()
	globe_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	globe_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	globe_container.stretch = true
	globe_container.clip_contents = true
	vbox.add_child(globe_container)

	globe_viewport = SubViewport.new()
	globe_viewport.size = Vector2i(1200, 800)
	globe_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	globe_container.add_child(globe_viewport)

	var globe_scene = load("res://scenes/Globe3D.tscn")
	if globe_scene:
		globe = globe_scene.instantiate()
		globe_viewport.add_child(globe)
		globe.connect("country_selected", Callable(self, "_on_country_dot_pressed"))
	else:
		var fallback = Label.new()
		fallback.text = "Globe3D.tscn não encontrada."
		fallback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fallback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		globe_container.add_child(fallback)

	globe_container.gui_input.connect(_on_globe_container_input)

	return panel

func _make_grid(_parent: Control) -> Control:
	# Grade visual simples como linhas
	var c = Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Apenas decorativo — sem lógica
	return c

func _make_country_dot(data: Dictionary, _map_area: Control) -> Control:
	var container = Control.new()
	container.set_meta("country_id", data["id"])

	# Posição relativa — será ajustada no _process
	var pos = COUNTRY_POSITIONS.get(data["id"], Vector2(0.5, 0.5))
	container.set_meta("rel_pos", pos)

	# Botão circular (bolinha)
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(80, 80)
	btn.size = Vector2(80, 80)
	var era = data.get("era", 0)
	btn.modulate = ERA_COLORS.get(era, Color.WHITE)
	btn.text = data["name"].substr(0, 3)
	btn.add_theme_font_size_override("font_size", 13)
	btn.pressed.connect(_on_country_dot_pressed.bind(data["id"]))
	container.add_child(btn)

	# Label com nome embaixo
	var lbl = Label.new()
	lbl.text = data["name"]
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.position = Vector2(-10, 82)
	container.add_child(lbl)

	# Stats pequenos
	var stats = Label.new()
	stats.text = "💰" + str(int(data["economy"])) + " 🔬" + str(int(data["technology"]))
	stats.add_theme_font_size_override("font_size", 11)
	stats.position = Vector2(-15, 98)
	stats.modulate = Color(0.8, 0.8, 0.8)
	container.add_child(stats)
	container.set_meta("stats_label", stats)
	container.set_meta("btn", btn)
	container.set_meta("name_label", lbl)

	return container

# ─────────────────────────────────────────────
#  PAINEL DE NOTÍCIAS
# ─────────────────────────────────────────────
func _make_news_panel() -> Control:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(400, 0)

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(vbox)

	var title = Label.new()
	title.text = "📰 NOTÍCIAS DO MUNDO"
	title.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title)

	# Separador
	var sep = HSeparator.new()
	vbox.add_child(sep)

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	news_container = VBoxContainer.new()
	news_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	news_container.add_theme_constant_override("separation", 8)
	scroll.add_child(news_container)
	vbox.add_child(scroll)

	# Mensagem inicial
	var welcome = Label.new()
	welcome.text = "O mundo aguarda suas decisões...\nClique em AVANÇAR para começar."
	welcome.add_theme_font_size_override("font_size", 15)
	welcome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	welcome.autowrap_mode = TextServer.AUTOWRAP_WORD
	welcome.modulate = Color(0.6, 0.6, 0.6)
	news_container.add_child(welcome)

	return panel

func _add_news(news_array: Array) -> void:
	for news in news_array:
		var label = Label.new()
		label.text = "[Ano " + str(news.get("year", "?")) + "] " + news.get("desc", "")
		label.add_theme_font_size_override("font_size", 14)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.autowrap_mode = TextServer.AUTOWRAP_WORD
		match news.get("severity", "low"):
			"critical": label.modulate = Color(1.0, 0.3, 0.3)
			"high":     label.modulate = Color(1.0, 0.6, 0.2)
			"medium":   label.modulate = Color(1.0, 0.9, 0.3)
			_:          label.modulate = Color(0.9, 0.9, 0.9)
		news_container.add_child(label)

		# Linha divisória fina
		var sep = HSeparator.new()
		sep.modulate = Color(0.3, 0.3, 0.3)
		news_container.add_child(sep)

	await get_tree().process_frame
	var scroll = news_container.get_parent() as ScrollContainer
	if scroll:
		scroll.scroll_vertical = scroll.get_v_scroll_bar().max_value

# ─────────────────────────────────────────────
#  FOOTER: poderes + botão avançar
# ─────────────────────────────────────────────
func _make_footer() -> Control:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 130)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	# Label instrução
	var instruction = Label.new()
	instruction.text = "🎯 PODERES DIVINOS  (selecione um poder → clique num marcador do globo)"
	instruction.add_theme_font_size_override("font_size", 13)
	instruction.modulate = Color(0.7, 0.7, 0.7)
	vbox.add_child(instruction)

	# Grid de poderes + botão avançar em linha
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(hbox)

	for power in GodPowers.get_all():
		var btn = Button.new()
		btn.text = power["icon"] + " " + power["name"] + "  ⚡" + str(power["cost"])
		btn.custom_minimum_size = Vector2(130, 60)
		btn.add_theme_font_size_override("font_size", 13)
		btn.tooltip_text = power["desc"]
		btn.set_meta("power_id", power["id"])
		btn.pressed.connect(_on_power_selected.bind(power["id"]))
		hbox.add_child(btn)
		power_buttons.append(btn)

	# Espaçador
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer)

	# Botão avançar — destaque
	var btn_advance = Button.new()
	btn_advance.text = "▶  AVANÇAR 1 ANO"
	btn_advance.custom_minimum_size = Vector2(200, 60)
	btn_advance.add_theme_font_size_override("font_size", 18)
	btn_advance.modulate = Color(0.3, 1.0, 0.5)
	btn_advance.pressed.connect(_on_advance_turn)
	hbox.add_child(btn_advance)

	return panel

# ─────────────────────────────────────────────
#  Posiciona bolinhas no mapa em _process
# ─────────────────────────────────────────────
func _process(_delta: float) -> void:
	for id in country_nodes:
		var node = country_nodes[id] as Control
		var rel_pos = node.get_meta("rel_pos") as Vector2
		var map_area = node.get_parent() as Control
		if map_area:
			var map_size = map_area.size
			node.position = Vector2(rel_pos.x * map_size.x - 40, rel_pos.y * map_size.y - 40)

# ─────────────────────────────────────────────
#  Callbacks
# ─────────────────────────────────────────────
func _on_globe_container_input(event: InputEvent) -> void:
	if not globe:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_globe_press_pos = event.position
		else:
			var drag = (event.position - _globe_press_pos).length()
			if drag < 8.0:
				var ratio = Vector2(globe_viewport.size) / globe_container.size
				globe.handle_click(event.position * ratio)

func _on_country_dot_pressed(country_id: int) -> void:
	selected_country_id = country_id
	_update_selected_country_label()
	if globe and globe.has_method("select_country"):
		globe.select_country(country_id)
	if selected_power_id != "":
		var result = simulator.use_god_power(selected_power_id, country_id)
		_add_news([{ "year": simulator.year, "desc": result, "severity": "low" }])
		selected_power_id = ""
		_clear_power_highlights()
		_refresh_ui()
	else:
		_highlight_country(country_id)

func _on_power_selected(power_id: String) -> void:
	selected_power_id = power_id
	_highlight_power(power_id)
	_add_news([{
		"year": simulator.year,
		"desc": "🎯 Poder selecionado. Clique num marcador do globo para aplicar.",
		"severity": "low"
	}])

func _on_advance_turn() -> void:
	selected_power_id = ""
	_clear_power_highlights()
	simulator.advance_turn()

func _on_turn_completed(_year: int, news: Array) -> void:
	_add_news(news)
	_refresh_ui()
	_draw_war_lines()

func _on_game_over(ending: String) -> void:
	var label = Label.new()
	label.text = "\n══════════════\n" + ending + "\n══════════════"
	label.add_theme_font_size_override("font_size", 18)
	label.modulate = Color.GOLD
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	news_container.add_child(label)

# ─────────────────────────────────────────────
#  Refresh — atualiza bolinhas e labels
# ─────────────────────────────────────────────
func _refresh_ui() -> void:
	label_year.text = "📅 Ano " + str(simulator.year)
	label_points.text = "   ⚡ " + str(simulator.god_power_points) + " pontos"

	var snapshot = simulator.get_world_snapshot()
	for data in snapshot:
		if globe and globe.has_method("update_country"):
			globe.update_country(data)

		var node = country_nodes.get(data["id"])
		if not node:
			continue

		# Atualiza cor pela era
		var btn = node.get_meta("btn") as Button
		var era = data.get("era", 0)
		btn.modulate = ERA_COLORS.get(era, Color.WHITE)

		# Ícone de guerra
		var name_lbl = node.get_meta("name_label") as Label
		var war = data["at_war_with"].size() > 0
		name_lbl.text = ("⚔️ " if war else "") + data["name"]
		name_lbl.modulate = Color.RED if war else Color.WHITE

		# Stats
		var stats_lbl = node.get_meta("stats_label") as Label
		stats_lbl.text = "💰" + str(int(data["economy"])) + " 🔬" + str(int(data["technology"])) + " 👥" + str(int(data["population"])) + "M"

	_update_selected_country_label()

func _draw_war_lines() -> void:
	if not globe or not globe.has_method("draw_war_line"):
		return
	var snapshot = simulator.get_world_snapshot()
	for data in snapshot:
		for enemy_id in data["at_war_with"]:
			if enemy_id > data["id"]:
				globe.draw_war_line(data["id"], enemy_id)

func _update_selected_country_label() -> void:
	if not label_selected_country:
		return
	if selected_country_id < 0:
		label_selected_country.text = "Selecione um país no globo."
		if country_detail_label:
			country_detail_label.text = "Clique em um marcador para abrir a ficha do país."
		return
	var data = _get_country_snapshot(selected_country_id)
	if data.is_empty():
		label_selected_country.text = "País selecionado: #" + str(selected_country_id)
		if country_detail_label:
			country_detail_label.text = "Sem dados disponíveis."
		return
	var leader = data.get("leader", {})
	var leader_text = ""
	if not leader.is_empty():
		leader_text = " | " + leader["display_name"] + " (" + leader["trait_label"] + ")"
	var allies_count = data.get("allies", []).size()
	label_selected_country.text = data["name"] + leader_text + " | Alianças " + str(allies_count) + " | " + data["era_name"] + " | Economia " + str(int(data["economy"])) + " | Tecnologia " + str(int(data["technology"])) + " | Estabilidade " + str(int(data["stability"]))
	if country_detail_label:
		country_detail_label.text = _format_country_detail(data)

func _get_country_snapshot(country_id: int) -> Dictionary:
	for data in simulator.get_world_snapshot():
		if data["id"] == country_id:
			return data
	return {}

func _format_country_detail(data: Dictionary) -> String:
	var leader = data.get("leader", {})
	var leader_line = "Líder: desconhecido"
	if not leader.is_empty():
		leader_line = "Líder: " + leader["display_name"] + " | Traços: " + leader["trait_label"]

	var allies_line = "Alianças: " + _country_names_from_ids(data.get("allies", []))
	var wars_line = "Guerras ativas: " + _country_names_from_ids(data.get("at_war_with", []))
	var trend_line = "Tendência: " + _format_trends(data.get("trend", {}))
	var war_history_line = "Histórico de guerras: " + _format_history(data.get("war_history", []), 2)
	var timeline_line = "Timeline: " + _format_history(data.get("event_history", []), 3)

	return leader_line + "\n" + allies_line + "\n" + wars_line + "\n" + trend_line + "\n" + war_history_line + "\n" + timeline_line

func _country_names_from_ids(ids: Array) -> String:
	if ids.is_empty():
		return "nenhuma"
	var names: Array = []
	for id in ids:
		var data = _get_country_snapshot(int(id))
		names.append(data.get("name", "#" + str(id)))
	return ", ".join(names)

func _format_trends(trend: Dictionary) -> String:
	if trend.is_empty():
		return "sem variação registrada"
	return "Eco " + _signed(trend.get("economy", 0.0)) + " | Tec " + _signed(trend.get("technology", 0.0)) + " | Estab " + _signed(trend.get("stability", 0.0)) + " | Pop " + _signed(trend.get("population", 0.0)) + "M"

func _signed(value) -> String:
	var number = float(value)
	if number > 0:
		return "+" + str(number)
	return str(number)

func _format_history(history: Array, limit: int) -> String:
	if history.is_empty():
		return "sem registros"
	var parts: Array = []
	var count = min(limit, history.size())
	for i in range(count):
		var entry = history[i]
		parts.append("Ano " + str(entry.get("year", "?")) + ": " + _shorten(str(entry.get("desc", "")), 82))
	return " / ".join(parts)

func _shorten(text: String, max_len: int) -> String:
	if text.length() <= max_len:
		return text
	return text.substr(0, max_len - 3) + "..."

func _highlight_country(country_id: int) -> void:
	for id in country_nodes:
		var node = country_nodes[id] as Control
		var btn = node.get_meta("btn") as Button
		btn.scale = Vector2(1.0, 1.0)
	var sel = country_nodes.get(country_id)
	if sel:
		var btn = sel.get_meta("btn") as Button
		btn.scale = Vector2(1.3, 1.3)

func _highlight_power(power_id: String) -> void:
	_clear_power_highlights()
	for btn in power_buttons:
		if str(btn.get_meta("power_id", "")) == power_id:
			btn.modulate = Color.GOLD

func _clear_power_highlights() -> void:
	for btn in power_buttons:
		btn.modulate = Color.WHITE
	# Reset escala dos países
	for id in country_nodes:
		var node = country_nodes[id] as Control
		var btn = node.get_meta("btn") as Button
		btn.scale = Vector2(1.0, 1.0)
