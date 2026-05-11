class_name WorldSimulator
extends Node

const LeaderAIScript        = preload("res://scripts/leader_ai.gd")
const DivineObjectivesScript = preload("res://scripts/divine_objectives.gd")
const WorldChronicleScript  = preload("res://scripts/world_chronicle.gd")

# ─────────────────────────────────────────────
#  Sinais (eventos que a UI pode escutar)
# ─────────────────────────────────────────────
signal turn_completed(year: int, news: Array)
signal game_over(ending: String)
signal choice_requested(event_data: Dictionary)

# ─────────────────────────────────────────────
#  Estado global
# ─────────────────────────────────────────────
var year: int = 1
var countries: Array = []        # Array de Country
var news_log: Array = []         # Histórico de notícias
var god_power_points: int = 5    # Pontos do jogador por turno
var divine_interference: int = 0 # Acumula com uso de poderes, decai por turno
var _pending_choices: Array = []
var _pending_news: Array = []
var scenario_id: String = "standard"
var scenario_name: String = "Mundo Padrão"
var scenario_summary: String = "Civilizações equilibradas, alianças iniciais e conflitos surgindo naturalmente."

var _event_system: EventSystem
var _war_system: WarSystem
var _leader_ai: LeaderAI
var _divine_objectives: DivineObjectives
var _chronicle: RefCounted  # WorldChronicle

# ─────────────────────────────────────────────
#  Inicialização
# ─────────────────────────────────────────────
func _ready() -> void:
	_event_system      = EventSystem.new()
	_war_system        = WarSystem.new()
	_leader_ai         = LeaderAIScript.new()
	_divine_objectives = DivineObjectivesScript.new()
	_chronicle         = WorldChronicleScript.new()
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
	_ensure_objective_intro()

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

	# 2. IA dos lideres: decisoes politicas, economicas e militares
	var leader_events = _leader_ai.process_decisions(countries, year)
	all_news.append_array(leader_events)

	# 3. Sistema de guerras
	var war_events = _war_system.process_wars(countries)
	all_news.append_array(war_events)

	# 3. Eventos globais aleatórios — separa interativos
	var global_events = _event_system.roll_events(countries, year)
	var interactive: Array = []
	for event in global_events:
		if event.get("interactive", false):
			interactive.append(event)
		else:
			all_news.append(event)

	# 4. Relações diplomáticas
	_update_relations()

	var omens = _leader_ai.generate_omens(countries, year)
	all_news.append_array(omens)

	var objective_events = _divine_objectives.evaluate(countries, year, all_news)
	for event in objective_events:
		var reward = int(event.get("reward_points", 0))
		if reward > 0:
			god_power_points += reward
	all_news.append_array(objective_events)
	all_news.append_array(_divine_objectives.ensure_objective(countries, year))

	# Consequências da interferência divina acumulada
	var divine_news = _process_divine_consequences()
	all_news.append_array(divine_news)
	divine_interference = max(0, divine_interference - 1)

	# 5. Registra no log (só eventos já resolvidos)
	for n in all_news:
		n["year"] = year
		news_log.append(n)
		_record_country_event(n)
		_chronicle.record_event(n, year)

	for country in countries:
		country.update_trends()

	# 6. Verifica condição de fim de jogo
	var ending = _check_game_over()
	if ending != "":
		emit_signal("game_over", ending)
		return

	# 7. Se há escolhas pendentes, pausa o turno
	if not interactive.is_empty():
		_pending_choices = interactive.duplicate()
		_pending_news = all_news.duplicate()
		emit_signal("choice_requested", _pending_choices[0])
		return

	emit_signal("turn_completed", year, all_news)

# ─────────────────────────────────────────────
#  Aplica um poder divino a um país alvo
# ─────────────────────────────────────────────
func use_god_power(power_id: String, target_country_id: int) -> Array:
	var cost = GodPowers.get_cost(power_id)
	if god_power_points < cost:
		return [{"year": year, "type": "god_power", "desc": "⚠️ Pontos divinos insuficientes. (Custo: " + str(cost) + ")", "countries": [], "severity": "low"}]

	var target = _get_country(target_country_id)
	if not target:
		return [{"year": year, "type": "god_power", "desc": "⚠️ País não encontrado.", "countries": [], "severity": "low"}]

	god_power_points -= cost
	divine_interference += 1

	# Poderes tratados inteiramente no simulator, sem passar por country.apply_power
	if power_id == "prophecy":
		var news = _apply_prophecy(target)
		for n in news:
			if not n.has("year"): n["year"] = year
			news_log.append(n)
			target.record_event(year, n)
		return news
	if power_id == "sacred_treaty":
		var news = _apply_sacred_treaty(target)
		for n in news:
			if not n.has("year"): n["year"] = year
			news_log.append(n)
			target.record_event(year, n)
		return news

	# Salva ex-inimigos antes de apply_power limpar at_war_with
	var former_enemies: Array = target.at_war_with.duplicate()
	if power_id == "force_peace":
		_force_peace_for(target)

	var primary_msg = target.apply_power(power_id)
	var all_news: Array = [{
		"year": year,
		"type": "god_power",
		"desc": "[PODER DIVINO] " + primary_msg,
		"countries": [target_country_id],
		"severity": "low",
	}]

	var relation_news = _apply_power_relations(power_id, target, former_enemies)
	all_news.append_array(relation_news)

	var chain_news = _event_system.apply_divine_to_chains(power_id, target_country_id)
	all_news.append_array(chain_news)

	for n in all_news:
		if not n.has("year"):
			n["year"] = year
		news_log.append(n)
		target.record_event(year, n)
		_chronicle.record_event(n, year)

	return all_news

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
#  Resolve escolha do jogador em evento interativo
# ─────────────────────────────────────────────
func resolve_choice(event_data: Dictionary, choice_index: int) -> void:
	var choices = event_data.get("choices", [])
	if choice_index < 0 or choice_index >= choices.size():
		return
	var choice = choices[choice_index]
	var country = _get_country(event_data.get("country_id", -1))
	if country:
		_apply_choice_effects(country, choice.get("effects", {}))
	var result_text = choice.get("result", "Decisão tomada.")
	if country:
		result_text = result_text.replace("{country}", country.country_name)
		var leader = country.get("leader")
		result_text = result_text.replace("{leader}", leader.display_name() if leader else "o governo")
	var result_news = {
		"year": year,
		"type": "player_choice",
		"desc": result_text,
		"countries": [event_data.get("country_id", -1)],
		"severity": "medium",
	}
	_pending_news.append(result_news)
	news_log.append(result_news)
	if country:
		country.record_event(year, result_news)
	_pending_choices.erase(event_data)
	if _pending_choices.is_empty():
		emit_signal("turn_completed", year, _pending_news)
		_pending_news = []
	else:
		emit_signal("choice_requested", _pending_choices[0])

func _apply_choice_effects(country: Country, effects: Dictionary) -> void:
	for key in effects:
		match key:
			"economy":           country.economy    = clampf(country.economy    + float(effects[key]), 0, 100)
			"stability":         country.stability  = clampf(country.stability  + float(effects[key]), 0, 100)
			"technology":        country.technology = clampf(country.technology + float(effects[key]), 0, 100)
			"military":          country.military   = clampf(country.military   + float(effects[key]), 0, 100)
			"faith":             country.faith      = clampf(country.faith      + float(effects[key]), 0, 100)
			"population_percent": country.population = max(0.1, country.population + country.population * float(effects[key]))

# ─────────────────────────────────────────────
#  Utilitários
# ─────────────────────────────────────────────
func _get_country(id: int) -> Country:
	for c in countries:
		if c.id == id:
			return c
	return null

func _apply_power_relations(power_id: String, target: Country, former_enemies: Array) -> Array:
	var news: Array = []
	match power_id:
		"force_peace":
			for enemy_id in former_enemies:
				var enemy = _get_country(int(enemy_id))
				if not enemy:
					continue
				var key_a = str(enemy.id)
				var key_b = str(target.id)
				var rel = clampf(target.relations.get(key_a, 0.0) + 25.0, -100.0, 100.0)
				target.relations[key_a] = rel
				enemy.relations[key_b] = rel
				news.append({
					"type": "diplomacy",
					"severity": "medium",
					"countries": [target.id, enemy.id],
					"desc": "☮️ A paz divina aproxima " + target.country_name + " e " + enemy.country_name + ". Relações melhoram.",
				})

		"spread_ideology":
			for other in countries:
				if other.id == target.id:
					continue
				var key_a = str(other.id)
				var key_b = str(target.id)
				if other.ideology != target.ideology:
					var was_ally = target.id in other.allies
					target.allies.erase(other.id)
					other.allies.erase(target.id)
					var rel = clampf(target.relations.get(key_a, 0.0) - randf_range(18.0, 28.0), -100.0, 100.0)
					target.relations[key_a] = rel
					other.relations[key_b] = rel
					if was_ally:
						news.append({
							"type": "diplomacy",
							"severity": "medium",
							"countries": [target.id, other.id],
							"desc": "📣 A nova ideologia de " + target.country_name + " rompe aliança com " + other.country_name + ".",
						})
				else:
					var rel = clampf(target.relations.get(key_a, 0.0) + randf_range(10.0, 18.0), -100.0, 100.0)
					target.relations[key_a] = rel
					other.relations[key_b] = rel

		"regress":
			for other in countries:
				if other.id == target.id:
					continue
				var key_a = str(other.id)
				var key_b = str(target.id)
				var rel = clampf(target.relations.get(key_a, 0.0) - randf_range(12.0, 22.0), -100.0, 100.0)
				target.relations[key_a] = rel
				other.relations[key_b] = rel
				var was_ally = target.id in other.allies
				if was_ally and rel < -10.0:
					target.allies.erase(other.id)
					other.allies.erase(target.id)
					news.append({
						"type": "diplomacy",
						"severity": "high",
						"countries": [target.id, other.id],
						"desc": "⏪ A regressão de " + target.country_name + " afasta " + other.country_name + ". Aliança desfeita.",
					})
	return news

func _apply_prophecy(target: Country) -> Array:
	if not _leader_ai:
		return [{"type": "prophecy", "severity": "omen", "countries": [target.id],
				"desc": "🔮 PROFECIA — " + target.country_name + ": os deuses não conseguem ler o destino deste povo."}]

	var intel = _leader_ai.get_country_intel(target, countries, year)
	var priority  = str(intel.get("priority", "Observar"))
	var war_risk  = str(intel.get("war_risk", "baixo"))
	var rival     = str(intel.get("likely_target_name", ""))
	var leader_name = target.leader.display_name() if target.leader else "o governante"

	var parts: Array = ["🔮 PROFECIA — " + target.country_name + ":"]
	match priority:
		"Investir em tecnologia":
			parts.append(leader_name + " está obcecado com o progresso. Laboratórios receberão recursos — " + target.country_name + " busca um salto de era.")
		"Militarizar":
			parts.append("Uma sombra militar cresce sobre " + target.country_name + ". " + leader_name + " arma seu povo. As forjas trabalham dia e noite.")
		"Reprimir instabilidade":
			parts.append("A visão mostra tensão nas ruas de " + target.country_name + ". " + leader_name + " enfrenta rebelião interna — a repressão parece inevitável.")
		"Buscar alianca":
			var suffix = " Os deuses veem " + rival + " como o parceiro almejado." if rival != "" else " O destino dos tratados ainda é nebuloso."
			parts.append(leader_name + " estende a mão ao horizonte, buscando aliados." + suffix)
		"Romper alianca":
			parts.append("A lealdade de " + target.country_name + " está se desfazendo. " + leader_name + " planeja romper com aliados. Isolamento se aproxima.")
		"Preparar guerra":
			if rival != "":
				parts.append("⚔️ Os deuses veem conflito. " + leader_name + " prepara guerra contra " + rival + ". A questão não é 'se' — é 'quando'.")
			else:
				parts.append("⚔️ " + leader_name + " anseia por conquistas. O alvo ainda está nas sombras.")
		_:
			parts.append(leader_name + " observa e espera. " + target.country_name + " está em compasso de espera.")

	match war_risk:
		"alto":  parts.append("⚠️ Risco de guerra: ALTO — conflito pode eclodir em breve.")
		"medio": parts.append("⚠️ Risco de guerra: moderado — tensões existem, mas controláveis.")

	return [{"type": "prophecy", "severity": "omen", "countries": [target.id],
			"desc": " ".join(parts)}]

func _apply_sacred_treaty(target: Country) -> Array:
	# Prioriza inimigos ativos; caso contrário, pega o pior relacionamento
	var partner: Country = null
	for enemy_id in target.at_war_with:
		var c = _get_country(int(enemy_id))
		if c:
			partner = c
			break

	if not partner:
		var worst_rel = 200.0
		for other in countries:
			if other.id == target.id:
				continue
			var rel = float(target.relations.get(str(other.id), 0.0))
			if rel < worst_rel:
				worst_rel = rel
				partner = other

	if not partner:
		return [{"type": "sacred_treaty", "severity": "low", "countries": [target.id],
				"desc": "📜 Tratado Sagrado em " + target.country_name + ": nenhum rival encontrado para reconciliar."}]

	var key_a   = str(partner.id)
	var key_b   = str(target.id)
	var old_rel = float(target.relations.get(key_a, 0.0))
	var boost   = randf_range(45.0, 62.0)
	var new_rel = clampf(old_rel + boost, -100.0, 100.0)
	target.relations[key_a]  = new_rel
	partner.relations[key_b] = new_rel

	var was_at_war = partner.id in target.at_war_with
	if was_at_war:
		target.at_war_with.erase(partner.id)
		partner.at_war_with.erase(target.id)

	var alliance_formed = false
	if new_rel >= 60.0:
		if not partner.id in target.allies:
			target.allies.append(partner.id)
		if not target.id in partner.allies:
			partner.allies.append(target.id)
		alliance_formed = true

	var desc = "📜 TRATADO SAGRADO — " + target.country_name + " e " + partner.country_name + ". "
	if was_at_war:
		desc += "A guerra cessa pelo poder divino. "
	desc += "Relações: " + str(int(old_rel)) + " → " + str(int(new_rel)) + ". "
	desc += "Uma aliança histórica nasce sob bênção divina." if alliance_formed else "A reconciliação avança — aliança pode surgir em breve."

	return [{"type": "sacred_treaty", "severity": "medium", "countries": [target.id, partner.id], "desc": desc}]

func _process_divine_consequences() -> Array:
	if divine_interference < 3:
		return []
	var news: Array = []
	if divine_interference >= 10:
		for country in countries:
			if country.ideology == "theocracy":
				country.faith     = minf(100, country.faith + 10)
				country.stability = minf(100, country.stability + 6)
				country.military  = minf(100, country.military + 5)
			elif country.era >= 3:
				country.stability = maxf(0, country.stability - 5)
		var modern = countries.filter(func(c): return c.era >= 3 and c.ideology != "theocracy")
		var revolt_suffix = ""
		if not modern.is_empty():
			var victim: Country = modern[randi() % modern.size()]
			revolt_suffix = " " + victim.country_name + " lidera a resistência contra os milagres."
		news.append({
			"type": "divine_consequence", "severity": "critical", "countries": [],
			"desc": "🌩️ INTERFERÊNCIA DIVINA CRÍTICA — O mundo se ergue contra os deuses. Nações modernas instabilizam." + revolt_suffix,
		})
	elif divine_interference >= 6:
		for country in countries:
			if country.ideology == "theocracy":
				country.faith     = minf(100, country.faith + 6)
				country.stability = minf(100, country.stability + 4)
			elif country.ideology == "democracy" and country.era >= 3:
				country.stability = maxf(0, country.stability - 2)
		news.append({
			"type": "divine_consequence", "severity": "high", "countries": [],
			"desc": "⚡ Interferência divina alta. O mundo teme os deuses. Teocracias florescem — democracias modernas se agitam.",
		})
	else:
		for country in countries:
			if country.ideology == "theocracy":
				country.faith     = minf(100, country.faith + 3)
				country.stability = minf(100, country.stability + 2)
		news.append({
			"type": "divine_consequence", "severity": "medium", "countries": [],
			"desc": "✨ Sinais divinos perturbam o mundo. Teocracias ganham fervor e influência.",
		})
	return news

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

func get_country_intel(country_id: int) -> Dictionary:
	var country = _get_country(country_id)
	if not country or not _leader_ai:
		return {}
	return _leader_ai.get_country_intel(country, countries, year)

func get_active_objective_text() -> String:
	if not _divine_objectives:
		return "Objetivo Divino: aguardando."
	return _divine_objectives.get_active_text()

func get_chronicle() -> RefCounted:
	return _chronicle

func get_country_reputation(country_id: int) -> String:
	return _chronicle.get_reputation(country_id)

func _ensure_objective_intro() -> void:
	if not _divine_objectives:
		return
	var objective_news = _divine_objectives.ensure_objective(countries, year)
	for event in objective_news:
		event["year"] = year
		news_log.append(event)
