extends Control

const SCENARIOS = {
	"standard": {
		"name": "Mundo Padrão",
		"desc": "Civilizações equilibradas, alianças iniciais e conflitos surgindo naturalmente."
	},
	"fractured": {
		"name": "Mundo Fragmentado",
		"desc": "Pouca confiança entre países, estabilidade menor e alianças raras."
	},
	"golden_age": {
		"name": "Era Dourada",
		"desc": "Economias fortes, diplomacia favorável e mais espaço para guiar uma utopia."
	},
	"powder_keg": {
		"name": "Barril de Pólvora",
		"desc": "Militarização alta, rivalidades profundas e grande risco de efeito dominó."
	},
}

var selected_scenario: String = "standard"
var scenario_buttons: Dictionary = {}
var description_label: Label

func _ready() -> void:
	_build_ui()
	_select_scenario(selected_scenario)

func _build_ui() -> void:
	var root = VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 18)
	root.offset_left = 90
	root.offset_top = 70
	root.offset_right = -90
	root.offset_bottom = -70
	add_child(root)

	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 18)
	root.add_child(header)

	var title = Label.new()
	title.text = "⚡ DIVINUS"
	title.add_theme_font_size_override("font_size", 42)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var version = Label.new()
	version.text = "PC MVP"
	version.add_theme_font_size_override("font_size", 18)
	version.modulate = Color(0.72, 0.72, 0.72)
	header.add_child(version)

	var subtitle = Label.new()
	subtitle.text = "Escolha o estado inicial do mundo."
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.modulate = Color(0.78, 0.78, 0.78)
	root.add_child(subtitle)

	var body = HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 18)
	root.add_child(body)

	var scenario_list = VBoxContainer.new()
	scenario_list.custom_minimum_size = Vector2(420, 0)
	scenario_list.add_theme_constant_override("separation", 10)
	body.add_child(scenario_list)

	for scenario_id in SCENARIOS.keys():
		var data = SCENARIOS[scenario_id]
		var btn = Button.new()
		btn.text = data["name"]
		btn.custom_minimum_size = Vector2(0, 64)
		btn.add_theme_font_size_override("font_size", 20)
		btn.pressed.connect(_select_scenario.bind(scenario_id))
		scenario_list.add_child(btn)
		scenario_buttons[scenario_id] = btn

	var detail_panel = PanelContainer.new()
	detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(detail_panel)

	var detail_box = VBoxContainer.new()
	detail_box.add_theme_constant_override("separation", 16)
	detail_panel.add_child(detail_box)

	description_label = Label.new()
	description_label.add_theme_font_size_override("font_size", 24)
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	description_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	description_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_box.add_child(description_label)

	var start_row = HBoxContainer.new()
	detail_box.add_child(start_row)

	var start_button = Button.new()
	start_button.text = "▶ INICIAR CENÁRIO"
	start_button.custom_minimum_size = Vector2(260, 64)
	start_button.add_theme_font_size_override("font_size", 22)
	start_button.pressed.connect(_start_game)
	start_row.add_child(start_button)

	var quit_button = Button.new()
	quit_button.text = "SAIR"
	quit_button.custom_minimum_size = Vector2(130, 64)
	quit_button.add_theme_font_size_override("font_size", 18)
	quit_button.pressed.connect(func(): get_tree().quit())
	start_row.add_child(quit_button)

func _select_scenario(scenario_id: String) -> void:
	selected_scenario = scenario_id
	for id in scenario_buttons:
		var btn = scenario_buttons[id] as Button
		btn.modulate = Color(1.0, 0.86, 0.25) if id == selected_scenario else Color.WHITE

	var data = SCENARIOS[selected_scenario]
	description_label.text = data["name"] + "\n\n" + data["desc"] + "\n\n" + _scenario_effects(selected_scenario)

func _scenario_effects(scenario_id: String) -> String:
	match scenario_id:
		"fractured":
			return "Efeitos: -estabilidade, relações deterioradas, alianças iniciais removidas."
		"golden_age":
			return "Efeitos: +economia, +tecnologia, +estabilidade, mais pontos divinos iniciais."
		"powder_keg":
			return "Efeitos: +militarização, -relações, mais risco de guerras em cadeia."
	return "Efeitos: configuração equilibrada baseada nos dados iniciais."

func _start_game() -> void:
	ProjectSettings.set_setting("divinus/selected_scenario", selected_scenario)
	get_tree().change_scene_to_file("res://scenes/world_map.tscn")
