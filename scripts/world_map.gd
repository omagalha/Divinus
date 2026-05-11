extends Node

var simulator: WorldSimulator
var selected_country_id: int = -1
var selected_power_id: String = ""

var label_year: Label
var label_points: Label
var label_interference: Label
var _chronicle_panel: Control = null
var label_objective: Label
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
var _choice_modal: Control = null
var _preview_actions: HBoxContainer = null
var _preview_power_id: String = ""
var _preview_country_id: int = -1
var _in_preview: bool = false

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
	simulator.choice_requested.connect(_show_choice_event)

	_build_ui()
	_refresh_ui()
	_add_news([simulator.get_scenario_intro()])
	if simulator.has_method("get_active_objective_text"):
		_add_news([{ "year": simulator.year, "desc": simulator.get_active_objective_text(), "severity": "objective" }])


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
	panel.custom_minimum_size = Vector2(0, 76)
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	panel.add_child(vbox)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 30)
	vbox.add_child(hbox)

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

	label_interference = Label.new()
	label_interference.text = ""
	label_interference.add_theme_font_size_override("font_size", 16)
	label_interference.modulate = Color(1.0, 0.6, 0.2)
	hbox.add_child(label_interference)

	label_objective = Label.new()
	label_objective.text = "Objetivo Divino: aguardando."
	label_objective.add_theme_font_size_override("font_size", 13)
	label_objective.modulate = Color(0.55, 0.85, 1.0)
	label_objective.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(label_objective)

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

	_preview_actions = HBoxContainer.new()
	_preview_actions.add_theme_constant_override("separation", 10)
	_preview_actions.visible = false
	var btn_confirm = Button.new()
	btn_confirm.text = "✅ Confirmar poder"
	btn_confirm.custom_minimum_size = Vector2(160, 40)
	btn_confirm.add_theme_font_size_override("font_size", 14)
	btn_confirm.pressed.connect(_on_power_preview_confirm)
	_preview_actions.add_child(btn_confirm)
	var btn_cancel_prev = Button.new()
	btn_cancel_prev.text = "❌ Cancelar"
	btn_cancel_prev.custom_minimum_size = Vector2(100, 40)
	btn_cancel_prev.add_theme_font_size_override("font_size", 14)
	btn_cancel_prev.pressed.connect(_on_power_preview_cancel)
	_preview_actions.add_child(btn_cancel_prev)
	vbox.add_child(_preview_actions)

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
	globe_container.stretch = false
	globe_container.clip_contents = true
	vbox.add_child(globe_container)

	globe_viewport = SubViewport.new()
	globe_viewport.size = Vector2i(100, 100)
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

	var header_row = HBoxContainer.new()
	vbox.add_child(header_row)

	var title = Label.new()
	title.text = "📰 NOTÍCIAS DO MUNDO"
	title.add_theme_font_size_override("font_size", 18)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(title)

	var btn_history = Button.new()
	btn_history.text = "📖 HISTÓRIA"
	btn_history.add_theme_font_size_override("font_size", 13)
	btn_history.custom_minimum_size = Vector2(110, 32)
	btn_history.modulate = Color(0.75, 0.75, 1.0)
	btn_history.pressed.connect(_show_chronicle_panel)
	header_row.add_child(btn_history)

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

# Usado para itens avulsos: intro, poderes, escolhas
func _add_news(news_array: Array) -> void:
	for item in news_array:
		var label = Label.new()
		label.text = "[Ano " + str(item.get("year", "?")) + "] " + str(item.get("desc", ""))
		label.add_theme_font_size_override("font_size", 13)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.autowrap_mode = TextServer.AUTOWRAP_WORD
		label.modulate = _severity_color(str(item.get("severity", "low")), str(item.get("type", "")))
		news_container.add_child(label)
	await get_tree().process_frame
	var scroll = news_container.get_parent() as ScrollContainer
	if scroll:
		scroll.scroll_vertical = scroll.get_v_scroll_bar().max_value

# Exibe o pacote de notícias do turno como jornal estruturado
func _display_turn_summary(turn_year: int, news_array: Array) -> void:
	if news_array.is_empty():
		return

	var headlines: Array = []
	var important: Array = []
	var omens_list: Array = []

	for event in news_array:
		var sev = str(event.get("severity", "low"))
		var tp  = str(event.get("type", ""))
		if sev == "critical" or tp in ["leader_declares_war", "war_declared", "era_advance"]:
			headlines.append(event)
		elif sev == "omen" or tp == "omen":
			omens_list.append(event)
		elif sev in ["high", "medium", "objective"]:
			important.append(event)

	if selected_country_id > 0:
		headlines  = _focus_sort(headlines,  selected_country_id)
		important  = _focus_sort(important,  selected_country_id)
		omens_list = _focus_sort(omens_list, selected_country_id)

	var block = VBoxContainer.new()
	block.add_theme_constant_override("separation", 4)
	news_container.add_child(block)

	# Cabeçalho do ano
	var year_lbl = Label.new()
	year_lbl.text = "─── ANO " + str(turn_year) + " ───"
	year_lbl.add_theme_font_size_override("font_size", 13)
	year_lbl.modulate = Color(0.38, 0.38, 0.38)
	block.add_child(year_lbl)

	# Indicador de foco
	if selected_country_id > 0:
		var cd = _get_country_snapshot(selected_country_id)
		if not cd.is_empty():
			var fl = Label.new()
			fl.text = "📍 Foco: " + str(cd.get("name", ""))
			fl.add_theme_font_size_override("font_size", 12)
			fl.modulate = Color(0.50, 0.82, 1.0)
			block.add_child(fl)

	# Manchete principal
	if not headlines.is_empty():
		var hl = headlines[0]
		var hl_lbl = Label.new()
		hl_lbl.text = "📰  " + str(hl.get("desc", ""))
		hl_lbl.add_theme_font_size_override("font_size", 15)
		hl_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		hl_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hl_lbl.modulate = _severity_color(str(hl.get("severity", "low")), str(hl.get("type", "")))
		block.add_child(hl_lbl)

	# Notícias importantes — até 3 no total (outras manchetes + important)
	var shown = 0
	for i in range(1, headlines.size()):
		if shown >= 2: break
		_add_news_item(block, headlines[i], 14, "  ▸ ")
		shown += 1
	for event in important:
		if shown >= 3: break
		_add_news_item(block, event, 13, "  • ")
		shown += 1

	# Presságios — até 2
	if not omens_list.is_empty():
		var oh = Label.new()
		oh.text = "  Presságios"
		oh.add_theme_font_size_override("font_size", 12)
		oh.modulate = Color(0.38, 0.58, 0.80)
		block.add_child(oh)
		for i in range(mini(2, omens_list.size())):
			_add_news_item(block, omens_list[i], 13, "  ◈ ")

	# Resumo narrativo
	var summary = _generate_year_summary(news_array)
	if summary != "":
		var sl = Label.new()
		sl.text = summary
		sl.add_theme_font_size_override("font_size", 12)
		sl.autowrap_mode = TextServer.AUTOWRAP_WORD
		sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sl.modulate = Color(0.42, 0.42, 0.42)
		block.add_child(sl)

	await get_tree().process_frame
	var scroll = news_container.get_parent() as ScrollContainer
	if scroll:
		scroll.scroll_vertical = scroll.get_v_scroll_bar().max_value

func _add_news_item(parent: Control, event: Dictionary, font_size: int, bullet: String) -> void:
	var label = Label.new()
	label.text = bullet + str(event.get("desc", ""))
	label.add_theme_font_size_override("font_size", font_size)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.modulate = _severity_color(str(event.get("severity", "low")), str(event.get("type", "")))
	parent.add_child(label)

func _severity_color(severity: String, type: String) -> Color:
	if type in ["leader_declares_war", "war_declared"]:
		return Color(1.0, 0.22, 0.22)    # vermelho vivo — guerra real
	match severity:
		"critical":  return Color(1.0, 0.42, 0.30)   # vermelho suave
		"high":      return Color(1.0, 0.62, 0.20)   # laranja
		"medium":    return Color(0.95, 0.85, 0.45)  # amarelo suave
		"omen":      return Color(0.50, 0.78, 1.00)  # azul
		"objective": return Color(0.40, 1.00, 0.65)  # verde
		_:           return Color(0.58, 0.58, 0.58)  # cinza — cotidiano

func _generate_year_summary(news_array: Array) -> String:
	var wars     = news_array.filter(func(e): return str(e.get("type","")) in ["leader_declares_war", "war_declared"])
	var eras     = news_array.filter(func(e): return str(e.get("type","")) == "era_advance")
	var obj_ok   = news_array.filter(func(e): return str(e.get("type","")) == "divine_objective_completed")
	var obj_fail = news_array.filter(func(e): return str(e.get("type","")) == "divine_objective_failed")
	var divine   = news_array.filter(func(e): return str(e.get("type","")) == "divine_consequence")

	var parts: Array = []
	if wars.size() >= 2:
		parts.append("Um ano marcado por guerras.")
	elif wars.size() == 1:
		parts.append("Uma nova guerra eclodiu no mundo.")
	if not eras.is_empty():
		parts.append("Uma civilização cruzou para uma nova era.")
	if not obj_ok.is_empty():
		parts.append("Objetivo divino cumprido.")
	if not obj_fail.is_empty():
		parts.append("Objetivo divino fracassou.")
	if not divine.is_empty():
		match str(divine[0].get("severity", "")):
			"critical": parts.append("O mundo sentiu o peso da interferência divina.")
			"high":     parts.append("Teocracias crescem sob a sombra dos deuses.")
			_:          parts.append("Sinais divinos foram percebidos.")
	if parts.is_empty():
		var tense = news_array.filter(func(e): return str(e.get("severity","")) in ["high","critical"]).size()
		parts.append("Um ano agitado em vários fronts." if tense >= 3 else "O mundo respirou com relativa calma.")
	return " ".join(parts)

func _focus_sort(events: Array, country_id: int) -> Array:
	var focused: Array = []
	var others: Array  = []
	for event in events:
		if country_id in event.get("countries", []):
			focused.append(event)
		else:
			others.append(event)
	return focused + others

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
	# Mantém o SubViewport com o mesmo tamanho do container para centralizar o globo
	if globe_viewport and globe_container and globe_container.size.x > 10:
		var target = Vector2i(int(globe_container.size.x), int(globe_container.size.y))
		if globe_viewport.size != target:
			globe_viewport.size = target

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
	if globe and globe.has_method("select_country"):
		globe.select_country(country_id)
	if selected_power_id != "":
		_show_power_preview(selected_power_id, country_id)
	else:
		_in_preview = false
		_update_selected_country_label()
		_highlight_country(country_id)

func _on_power_selected(power_id: String) -> void:
	if _in_preview:
		_cancel_power_preview()
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
	_display_turn_summary(_year, news)
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
	_update_interference_label()

	if label_objective and simulator.has_method("get_active_objective_text"):
		label_objective.text = simulator.get_active_objective_text()

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

	if globe and globe.has_method("update_all_civilizations"):
		globe.update_all_civilizations(snapshot)

	_update_selected_country_label()

func _update_interference_label() -> void:
	if not label_interference:
		return
	var level = simulator.divine_interference
	if level >= 10:
		label_interference.text = "   🌩️ Interferência Crítica"
		label_interference.modulate = Color(1.0, 0.2, 0.2)
	elif level >= 6:
		label_interference.text = "   ⚡ Interferência Alta"
		label_interference.modulate = Color(1.0, 0.5, 0.1)
	elif level >= 3:
		label_interference.text = "   ✨ Interferência Perceptível"
		label_interference.modulate = Color(1.0, 0.85, 0.3)
	else:
		label_interference.text = ""

func _draw_war_lines() -> void:
	if not globe or not globe.has_method("draw_war_line"):
		return
	var snapshot = simulator.get_world_snapshot()
	for data in snapshot:
		for enemy_id in data["at_war_with"]:
			if enemy_id > data["id"]:
				globe.draw_war_line(data["id"], enemy_id)

func _show_power_preview(power_id: String, country_id: int) -> void:
	_preview_power_id = power_id
	_preview_country_id = country_id
	_in_preview = true

	var data = _get_country_snapshot(country_id)
	var power = GodPowers.get_by_id(power_id)
	if power.is_empty() or data.is_empty():
		return

	var preview = GodPowers.get_preview(power_id)
	var cost = int(power["cost"])
	var can_afford = simulator.god_power_points >= cost

	var stat_labels = {"economy": "Economia", "stability": "Estabilidade", "technology": "Tecnologia", "military": "Militar"}
	var lines: Array = []
	lines.append(str(power["icon"]) + "  " + str(power["name"]) + "  →  " + str(data["name"]))
	lines.append("─────────────────────")

	for key in ["economy", "stability", "technology", "military"]:
		if not preview.has(key):
			continue
		var delta = int(preview[key])
		var curr = int(data.get(key, 0))
		var projected = clampi(curr + delta, 0, 100)
		var sign_str = "+" if delta > 0 else ""
		var arrow = " ▲" if delta > 0 else " ▼"
		lines.append("  " + str(stat_labels[key]) + "  " + str(curr) + arrow + "  " + str(projected) + "  (" + sign_str + str(delta) + ")")

	if preview.has("population_pct"):
		var pct = int(preview["population_pct"])
		var sign_str = "+" if pct > 0 else ""
		lines.append("  População  " + sign_str + str(pct) + "%")

	if preview.get("war_cleared", false):
		var wars = (data.get("at_war_with", []) as Array).size()
		if wars > 0:
			lines.append("  ☮️ Encerrará " + str(wars) + " conflito(s) ativo(s)")
		else:
			lines.append("  País não está em guerra atualmente")

	if preview.get("ideology_change", false):
		lines.append("  Ideologia mudará aleatoriamente  (atual: " + str(data.get("ideology", "?")) + ")")

	if preview.get("era_regress", false):
		if int(data.get("era", 0)) == 0:
			lines.append("  ⚠️ Já na Era Tribal — sem efeito de regressão")
		else:
			lines.append("  Era regredirá: " + str(data.get("era_name", "")) + " → anterior")

	var rel_hint = str(preview.get("relation_hint", ""))
	if rel_hint != "":
		lines.append("  🤝 " + rel_hint)

	lines.append("")
	var hint = _get_power_objective_hint(power_id, data)
	if hint != "":
		lines.append(hint)

	if can_afford:
		lines.append("⚡ Custo: " + str(cost) + " pontos  (você tem: " + str(simulator.god_power_points) + ")")
	else:
		lines.append("❌ Pontos insuficientes — custo: " + str(cost) + ", você tem: " + str(simulator.god_power_points))

	label_selected_country.text = "🔍 PRÉVIA DO PODER"
	country_detail_label.text = "\n".join(lines)

	if _preview_actions:
		_preview_actions.visible = true
		var confirm_btn = _preview_actions.get_child(0) as Button
		if confirm_btn:
			confirm_btn.disabled = not can_afford
			confirm_btn.modulate = Color.WHITE if can_afford else Color(0.5, 0.5, 0.5)

func _get_power_objective_hint(power_id: String, data: Dictionary) -> String:
	match power_id:
		"bless":
			if int(data.get("stability", 100)) < 40:
				return "💡 Pode ajudar: país em crise de estabilidade"
			if int(data.get("economy", 100)) < 40:
				return "💡 Pode ajudar: economia fraca"
		"tech_boost":
			if int(data.get("technology", 100)) < 55:
				return "💡 Pode acelerar avanço de era"
		"force_peace":
			if (data.get("at_war_with", []) as Array).size() > 0:
				return "💡 Encerra conflito ativo — pode salvar o país"
		"economic_crisis":
			if (data.get("at_war_with", []) as Array).size() > 0:
				return "⚠️ País em guerra — crise pode levar ao colapso"
		"regress":
			if int(data.get("military", 0)) > 70:
				return "⚠️ País militarizado — regressão pode gerar instabilidade severa"
	return ""

func _on_power_preview_confirm() -> void:
	var power_id = _preview_power_id
	var country_id = _preview_country_id
	_cancel_power_preview()
	var news = simulator.use_god_power(power_id, country_id)
	_add_news(news)
	if globe and globe.has_method("trigger_power_visual"):
		globe.trigger_power_visual(country_id, power_id)
	selected_power_id = ""
	_clear_power_highlights()
	_refresh_ui()

func _on_power_preview_cancel() -> void:
	_cancel_power_preview()
	selected_power_id = ""
	_clear_power_highlights()
	_update_selected_country_label()

func _cancel_power_preview() -> void:
	_in_preview = false
	_preview_power_id = ""
	_preview_country_id = -1
	if _preview_actions:
		_preview_actions.visible = false

func _update_selected_country_label() -> void:
	if _in_preview:
		return
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

	var country_id = int(data.get("id", -1))
	var reputation = simulator.get_country_reputation(country_id) if simulator.has_method("get_country_reputation") else ""
	var rep_line = ("Reputação: " + reputation) if reputation != "" else ""

	var allies_line = "Alianças: " + _country_names_from_ids(data.get("allies", []))
	var wars_line = "Guerras ativas: " + _country_names_from_ids(data.get("at_war_with", []))
	var trend_line = "Tendência: " + _format_trends(data.get("trend", {}))
	var war_history_line = "Histórico de guerras: " + _format_history(data.get("war_history", []), 2)
	var timeline_line = "Timeline: " + _format_history(data.get("event_history", []), 3)

	var lines: Array = [leader_line, _format_country_intel(country_id)]
	if rep_line != "":
		lines.append(rep_line)
	lines.append_array([allies_line, wars_line, trend_line, war_history_line, timeline_line])
	return "\n".join(lines)

func _format_country_intel(country_id: int) -> String:
	if not simulator or not simulator.has_method("get_country_intel"):
		return "IA do lider: indisponivel"
	var intel = simulator.get_country_intel(country_id)
	if intel.is_empty():
		return "IA do lider: sem leitura"
	var target = str(intel.get("likely_target_name", ""))
	var target_text = " | Alvo provavel: " + target if target != "" else ""
	return "IA do lider: " + str(intel.get("priority", "Observar")) + " | Risco de guerra: " + str(intel.get("war_risk", "baixo")) + target_text + "\nMotivo: " + str(intel.get("reason", "Sem motivo claro."))

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

# ─────────────────────────────────────────────
#  Painel de Crônica Histórica
# ─────────────────────────────────────────────
func _show_chronicle_panel() -> void:
	if _chronicle_panel:
		_chronicle_panel.queue_free()

	var chronicle = simulator.get_chronicle()
	if not chronicle:
		return

	var snapshot   = simulator.get_world_snapshot()
	var name_map: Dictionary = {}
	for d in snapshot:
		name_map[int(d["id"])] = str(d["name"])

	var overlay = ColorRect.new()
	overlay.color = Color(0.0, 0.0, 0.0, 0.78)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 100

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	overlay.add_child(center)

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 0)
	center.add_child(panel)

	var outer = VBoxContainer.new()
	outer.add_theme_constant_override("separation", 8)
	panel.add_child(outer)

	# Cabeçalho
	var hdr = HBoxContainer.new()
	outer.add_child(hdr)
	var hdr_lbl = Label.new()
	hdr_lbl.text = "📖  CRÔNICA DO MUNDO"
	hdr_lbl.add_theme_font_size_override("font_size", 20)
	hdr_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr.add_child(hdr_lbl)
	var close_btn = Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(36, 36)
	close_btn.pressed.connect(_hide_chronicle_panel)
	hdr.add_child(close_btn)

	outer.add_child(HSeparator.new())

	# Scroll para o conteúdo
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 520)
	outer.add_child(scroll)

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 6)
	scroll.add_child(vbox)

	# ── Rivalidades ──
	var rivalries = chronicle.get_rivalries()
	if not rivalries.is_empty():
		_chron_section(vbox, "⚔️  Rivalidades Históricas")
		for r in rivalries:
			var na = name_map.get(int(r["id_a"]), "?")
			var nb = name_map.get(int(r["id_b"]), "?")
			_chron_row(vbox, na + " × " + nb + "  ·  " + str(r["wars"]) + " guerra(s)", Color(1.0, 0.45, 0.35))

	# ── Pactos ──
	var pacts = chronicle.get_pacts()
	if not pacts.is_empty():
		_chron_section(vbox, "🤝  Pactos Históricos")
		for p in pacts:
			var na = name_map.get(int(p["id_a"]), "?")
			var nb = name_map.get(int(p["id_b"]), "?")
			_chron_row(vbox, na + " & " + nb + "  ·  " + str(p["alliances"]) + " aliança(s)", Color(0.40, 1.00, 0.65))

	# ── Reputações ──
	var has_rep = false
	for d in snapshot:
		var rep = chronicle.get_reputation(int(d["id"]))
		if rep != "":
			if not has_rep:
				_chron_section(vbox, "🏆  Reputações")
				has_rep = true
			_chron_row(vbox, str(d["name"]) + ": " + rep, Color(0.95, 0.85, 0.45))

	# ── Crônica por Década ──
	var decades = chronicle.get_decades()
	if not decades.is_empty():
		_chron_section(vbox, "📅  Crônica por Década")
		for decade in decades:
			var dname = chronicle.get_decade_name(int(decade))
			var dlbl = Label.new()
			dlbl.text = "── Década " + str(decade) + "–" + str(int(decade) + 9) + (("  \"" + dname + "\"") if dname != "" else "")
			dlbl.add_theme_font_size_override("font_size", 13)
			dlbl.modulate = Color(0.60, 0.60, 0.60)
			vbox.add_child(dlbl)
			for bullet in chronicle.get_decade_bullets(int(decade)):
				_chron_row(vbox, "  · " + str(bullet), Color(0.55, 0.55, 0.55))

	add_child(overlay)
	_chronicle_panel = overlay

func _hide_chronicle_panel() -> void:
	if _chronicle_panel:
		_chronicle_panel.queue_free()
		_chronicle_panel = null

func _chron_section(parent: Control, title: String) -> void:
	var sep = HSeparator.new()
	sep.modulate = Color(0.3, 0.3, 0.3)
	parent.add_child(sep)
	var lbl = Label.new()
	lbl.text = title
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.modulate = Color(0.85, 0.85, 1.0)
	parent.add_child(lbl)

func _chron_row(parent: Control, text: String, color: Color) -> void:
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.modulate = color
	parent.add_child(lbl)

# ─────────────────────────────────────────────
#  Modal de evento interativo
# ─────────────────────────────────────────────
func _show_choice_event(event_data: Dictionary) -> void:
	if _choice_modal:
		_choice_modal.queue_free()

	var overlay = ColorRect.new()
	overlay.color = Color(0.0, 0.0, 0.0, 0.72)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 100

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	overlay.add_child(center)

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 0)
	center.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	var country_id = event_data.get("country_id", -1)
	var country_name = _get_country_snapshot(country_id).get("name", "???")

	var badge = Label.new()
	badge.text = "⚡ EVENTO — " + country_name.to_upper()
	badge.add_theme_font_size_override("font_size", 13)
	badge.modulate = Color(1.0, 0.75, 0.2)
	vbox.add_child(badge)

	var title = Label.new()
	title.text = event_data.get("title", "Evento")
	title.add_theme_font_size_override("font_size", 22)
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	var desc = Label.new()
	desc.text = event_data.get("desc", "")
	desc.add_theme_font_size_override("font_size", 15)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc.custom_minimum_size = Vector2(0, 60)
	vbox.add_child(desc)

	vbox.add_child(HSeparator.new())

	var question = Label.new()
	question.text = "O que você fará?"
	question.add_theme_font_size_override("font_size", 13)
	question.modulate = Color(0.65, 0.65, 0.65)
	vbox.add_child(question)

	for i in range(event_data.get("choices", []).size()):
		var choice = event_data["choices"][i]
		var btn = Button.new()
		btn.text = choice.get("label", "Opção") + "     " + choice.get("desc", "")
		btn.custom_minimum_size = Vector2(0, 52)
		btn.add_theme_font_size_override("font_size", 14)
		btn.pressed.connect(_on_choice_selected.bind(event_data, i))
		vbox.add_child(btn)

	add_child(overlay)
	_choice_modal = overlay

func _on_choice_selected(event_data: Dictionary, choice_index: int) -> void:
	if _choice_modal:
		_choice_modal.queue_free()
		_choice_modal = null
	simulator.resolve_choice(event_data, choice_index)
