class_name WorldSimulator
extends Node

# ─────────────────────────────────────────────
#  Sinais (eventos que a UI pode escutar)
# ─────────────────────────────────────────────
signal turn_completed(year: int, news: Array)
signal game_over(ending: String)

# ─────────────────────────────────────────────
#  Estado global
# ─────────────────────────────────────────────
var year: int = 1
var countries: Array = []        # Array de Country
var news_log: Array = []         # Histórico de notícias
var god_power_points: int = 5    # Pontos do jogador por turno
var scenario_id: String = "standard"
var scenario_name: String = "Mundo Padrão"
var scenario_summary: String = "Civilizações equilibradas, alianças iniciais e conflitos surgindo naturalmente."

var _event_system: EventSystem
var _war_system: WarSystem

# ─────────────────────────────────────────────
#  Inicialização
# ─────────────────────────────────────────────
func _ready() -> void:
	_event_system = EventSystem.new()
	_war_system   = WarSystem.new()
	add_child(_event_system)
	add_child(_war_system)
	_load_countries()

func _load_countries() -> void:
	var file = FileAccess.open("res://data/countries.json", FileAccess.READ)
	if not file:
		push_error("Não foi possível abrir countries.json")
		return
	var json = JSON.new()
	json.parse(file.get_as_text())
	var data = json.get_data()
	file.close()

	for entry in data:
		var c = Country.new()
		c.setup(entry)
		countries.append(c)
	_seed_initial_alliances()

func apply_scenario(id: String) -> void:
	scenario_id = id
	match scenario_id:
		"fractured":
			scenario_name = "Mundo Fragmentado"
			scenario_summary = "Confiança quebrada, alianças desfeitas e estabilidade menor."
			for country in countries:
				country.allies.clear()
				country.stability = max(0, country.stability - 12)
				for key in country.relations.keys():
					country.relations[key] = max(-100, country.relations[key] - randf_range(15, 32))
		"golden_age":
			scenario_name = "Era Dourada"
			scenario_summary = "Economias aquecidas, estabilidade alta e diplomacia favorável."
			god_power_points = 8
			for country in countries:
				country.economy = min(100, country.economy + 12)
				country.technology = min(100, country.technology + 6)
				country.stability = min(100, country.stability + 10)
				for key in country.relations.keys():
					country.relations[key] = min(100, country.relations[key] + randf_range(8, 18))
			_seed_initial_alliances()
		"powder_keg":
			scenario_name = "Barril de Pólvora"
			scenario_summary = "Militarização alta, rivalidades profundas e risco de guerra em cadeia."
			god_power_points = 6
			for country in countries:
				country.military = min(100, country.military + 18)
				country.stability = max(0, country.stability - 6)
				for key in country.relations.keys():
					country.relations[key] = max(-100, country.relations[key] - randf_range(18, 35))
			_seed_initial_alliances()
		_:
			scenario_id = "standard"
			scenario_name = "Mundo Padrão"
			scenario_summary = "Civilizações equilibradas, alianças iniciais e conflitos surgindo naturalmente."

	for country in countries:
		country.begin_turn_snapshot()
		country.update_trends()

func get_scenario_intro() -> Dictionary:
	return {
		"year": year,
		"type": "scenario",
		"severity": "low",
		"desc": "🌐 Cenário: " + scenario_name + ". " + scenario_summary,
	}

# ─────────────────────────────────────────────
#  Avança um turno (1 ano)
# ─────────────────────────────────────────────
func advance_turn() -> void:
	year += 1
	god_power_points += 3   # jogador ganha pontos a cada turno
	var all_news: Array = []

	for country in countries:
		country.begin_turn_snapshot()

	# 1. Cada país simula seu turno
	for country in countries:
		var country_events = country.simulate_turn()
		all_news.append_array(country_events)

	# 2. Sistema de guerras
	var war_events = _war_system.process_wars(countries)
	all_news.append_array(war_events)

	# 3. Eventos globais aleatórios
	var global_events = _event_system.roll_events(countries, year)
	all_news.append_array(global_events)

	# 4. Relações diplomáticas
	_update_relations()

	# 5. Registra no log
	for n in all_news:
		n["year"] = year
		news_log.append(n)
		_record_country_event(n)

	for country in countries:
		country.update_trends()

	# 6. Verifica condição de fim de jogo
	var ending = _check_game_over()
	if ending != "":
		emit_signal("game_over", ending)
		return

	emit_signal("turn_completed", year, all_news)

# ─────────────────────────────────────────────
#  Aplica um poder divino a um país alvo
# ─────────────────────────────────────────────
func use_god_power(power_id: String, target_country_id: int) -> String:
	var cost = GodPowers.get_cost(power_id)
	if god_power_points < cost:
		return "⚠️ Pontos divinos insuficientes. (Custo: " + str(cost) + ")"

	var target = _get_country(target_country_id)
	if not target:
		return "⚠️ País não encontrado."

	god_power_points -= cost
	if power_id == "force_peace":
		_force_peace_for(target)
	var result = target.apply_power(power_id)
	news_log.append({
		"year": year,
		"type": "god_power",
		"desc": "[PODER DIVINO] " + result,
		"countries": [target_country_id],
		"severity": "low",
	})
	target.record_event(year, news_log.back())
	return result

# ─────────────────────────────────────────────
#  Relações diplomáticas automáticas
# ─────────────────────────────────────────────
func _update_relations() -> void:
	for i in range(countries.size()):
		for j in range(i + 1, countries.size()):
			var a: Country = countries[i]
			var b: Country = countries[j]
			var key_a = str(b.id)
			var key_b = str(a.id)

			var current = a.relations.get(key_a, 0)

			# Ideologias iguais = amizade natural
			if a.ideology == b.ideology:
				current = min(100, current + randf_range(0.5, 1.5))
			else:
				current = max(-100, current - randf_range(0.0, 1.0))

			var leader_a = a.get("leader")
			var leader_b = b.get("leader")
			if leader_a:
				current += leader_a.relation_modifier(leader_b)

			# Em guerra = relação despenca
			if a.id in b.at_war_with:
				current = max(-100, current - 5)

			a.relations[key_a] = current
			b.relations[key_b] = current

			if current > 75 and not b.id in a.allies and not a.id in b.allies:
				a.allies.append(b.id)
				b.allies.append(a.id)

# ─────────────────────────────────────────────
#  Verifica condições de fim de jogo
# ─────────────────────────────────────────────
func _check_game_over() -> String:
	# Utopia: todos com tecnologia > 85 e estabilidade > 75
	var utopia = countries.all(func(c): return c.technology > 85 and c.stability > 75)
	if utopia:
		return "🌟 UTOPIA TECNOLÓGICA\nA humanidade alcançou harmonia e prosperidade. Você guiou o mundo para sua melhor versão."

	# Colapso: todos com estabilidade < 15
	var collapse = countries.all(func(c): return c.stability < 15)
	if collapse:
		return "💀 COLAPSO CIVILIZACIONAL\nO mundo afundou no caos. Civilização acabou."

	# Guerra mundial: mais de 60% dos países em guerra
	var at_war_count = countries.filter(func(c): return c.at_war_with.size() > 0).size()
	if at_war_count >= int(countries.size() * 0.6):
		return "⚔️ GUERRA MUNDIAL\nO planeta entrou em conflito total. Milhões morreram."

	# Fim de prazo: ano 2200
	if year >= 2200:
		return "⏳ FIM DA ERA\nO mundo sobreviveu. Mas que tipo de mundo você criou?"

	return ""

# ─────────────────────────────────────────────
#  Utilitários
# ─────────────────────────────────────────────
func _get_country(id: int) -> Country:
	for c in countries:
		if c.id == id:
			return c
	return null

func _force_peace_for(target: Country) -> void:
	for enemy_id in target.at_war_with.duplicate():
		var enemy = _get_country(enemy_id)
		if enemy:
			enemy.at_war_with.erase(target.id)

func _record_country_event(event: Dictionary) -> void:
	for country_id in event.get("countries", []):
		var country = _get_country(int(country_id))
		if country:
			country.record_event(year, event)

func _seed_initial_alliances() -> void:
	for i in range(countries.size()):
		for j in range(i + 1, countries.size()):
			var a: Country = countries[i]
			var b: Country = countries[j]
			var relation = a.relations.get(str(b.id), 0)
			if relation >= 70:
				if not b.id in a.allies:
					a.allies.append(b.id)
				if not a.id in b.allies:
					b.allies.append(a.id)

func get_world_snapshot() -> Array:
	return countries.map(func(c): return c.to_dict())
