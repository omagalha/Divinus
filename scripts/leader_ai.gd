class_name LeaderAI
extends RefCounted

const MAX_DECISIONS_PER_TURN := 3
const MAX_OMENS_PER_TURN := 3
const DECISION_THRESHOLD := 58.0
const COOLDOWN_YEARS := 4

var _cooldowns: Dictionary = {}

func get_country_intel(country: Country, countries: Array, year: int) -> Dictionary:
	var options: Array = []
	options.append(_score_invest_technology(country, year))
	options.append(_score_militarize(country, year))
	options.append(_score_suppress_unrest(country, year))
	options.append(_score_seek_alliance(country, countries, year))
	options.append(_score_break_alliance(country, countries, year))
	options.append(_score_declare_war(country, countries, year))
	options = options.filter(func(item): return not item.is_empty())
	options.sort_custom(func(a, b): return float(a.get("score", 0.0)) > float(b.get("score", 0.0)))

	var top = options[0] if not options.is_empty() else {}
	var war = _score_declare_war(country, countries, year)
	var target = _find_country(countries, int(war.get("target_id", -1)))
	return {
		"priority": _decision_label(str(top.get("type", "wait"))),
		"priority_score": snappedf(float(top.get("score", 0.0)), 0.1),
		"war_risk": _risk_label(float(war.get("score", 0.0))),
		"likely_target_id": target.id if target else -1,
		"likely_target_name": target.country_name if target else "",
		"reason": _decision_reason(country, top, target),
	}

func generate_omens(countries: Array, year: int) -> Array:
	var candidates: Array = []
	for country in countries:
		var intel = get_country_intel(country, countries, year)
		var weight = _omen_weight(country, intel)
		if weight <= 0.0:
			continue
		candidates.append({
			"country": country,
			"intel": intel,
			"weight": weight,
		})

	candidates.sort_custom(func(a, b): return float(a.get("weight", 0.0)) > float(b.get("weight", 0.0)))

	var omens: Array = []
	var count = min(MAX_OMENS_PER_TURN, candidates.size())
	for i in range(count):
		var item = candidates[i]
		var country: Country = item["country"]
		var intel: Dictionary = item["intel"]
		omens.append({
			"type": "omen",
			"countries": [country.id],
			"severity": "omen",
			"desc": _omen_text(country, intel),
		})
	return omens

func process_decisions(countries: Array, year: int) -> Array:
	var candidates: Array = []
	for country in countries:
		var best = _best_decision_for(country, countries, year)
		if not best.is_empty():
			candidates.append(best)

	candidates.sort_custom(func(a, b): return float(a.get("score", 0.0)) > float(b.get("score", 0.0)))

	var events: Array = []
	var used_countries: Array = []
	for decision in candidates:
		if events.size() >= MAX_DECISIONS_PER_TURN:
			break
		var country_id = int(decision.get("country_id", -1))
		if country_id in used_countries:
			continue
		if float(decision.get("score", 0.0)) < DECISION_THRESHOLD:
			continue
		if randf() > _activation_chance(float(decision.get("score", 0.0))):
			continue
		var event = _execute_decision(decision, countries, year)
		if not event.is_empty():
			events.append(event)
			used_countries.append(country_id)
			_set_cooldown(country_id, str(decision.get("type", "")), year)

	return events

func _best_decision_for(country: Country, countries: Array, year: int) -> Dictionary:
	var options: Array = []
	options.append(_score_invest_technology(country, year))
	options.append(_score_militarize(country, year))
	options.append(_score_suppress_unrest(country, year))
	options.append(_score_seek_alliance(country, countries, year))
	options.append(_score_break_alliance(country, countries, year))
	options.append(_score_declare_war(country, countries, year))
	options = options.filter(func(item): return not item.is_empty())
	if options.is_empty():
		return {}
	options.sort_custom(func(a, b): return float(a.get("score", 0.0)) > float(b.get("score", 0.0)))
	return options[0]

func _score_invest_technology(country: Country, year: int) -> Dictionary:
	if _on_cooldown(country.id, "invest_technology", year) or country.technology >= 96.0:
		return {}
	var leader = country.get_leader()
	var score = leader.ambition * 90.0 + country.economy * 0.35 + country.stability * 0.12 - country.technology * 0.25
	if country.era >= 3:
		score += 8.0
	return _decision(country, "invest_technology", score)

func _score_militarize(country: Country, year: int) -> Dictionary:
	if _on_cooldown(country.id, "militarize", year) or country.military >= 94.0:
		return {}
	var leader = country.get_leader()
	var score = leader.aggression * 100.0 + leader.ambition * 45.0 + (100.0 - country.military) * 0.28
	score += country.at_war_with.size() * 22.0
	score += max(0.0, 45.0 - country.stability) * 0.25
	score -= max(0.0, 28.0 - country.economy) * 0.35
	return _decision(country, "militarize", score)

func _score_suppress_unrest(country: Country, year: int) -> Dictionary:
	if _on_cooldown(country.id, "suppress_unrest", year) or country.stability >= 48.0:
		return {}
	var leader = country.get_leader()
	var score = (52.0 - country.stability) * 1.25 + leader.aggression * 70.0 + leader.isolationism * 35.0 - leader.diplomacy * 25.0
	return _decision(country, "suppress_unrest", score)

func _score_seek_alliance(country: Country, countries: Array, year: int) -> Dictionary:
	if _on_cooldown(country.id, "seek_alliance", year):
		return {}
	var leader = country.get_leader()
	var best_target: Country = null
	var best_score := -999.0
	for other in countries:
		if other.id == country.id:
			continue
		if other.id in country.allies or other.id in country.at_war_with:
			continue
		var relation = float(country.relations.get(str(other.id), 0.0))
		var score = leader.diplomacy * 115.0 - leader.isolationism * 75.0 + relation * 0.55
		score += _shared_enemy_bonus(country, other) * 14.0
		score += other.get_leader().diplomacy * 25.0
		if score > best_score:
			best_score = score
			best_target = other
	if not best_target:
		return {}
	return _decision(country, "seek_alliance", best_score, best_target)

func _score_break_alliance(country: Country, countries: Array, year: int) -> Dictionary:
	if _on_cooldown(country.id, "break_alliance", year) or country.allies.is_empty():
		return {}
	var leader = country.get_leader()
	var worst_target: Country = null
	var worst_relation := 999.0
	for ally_id in country.allies:
		var ally = _find_country(countries, int(ally_id))
		if not ally:
			continue
		var relation = float(country.relations.get(str(ally.id), 0.0))
		if relation < worst_relation:
			worst_relation = relation
			worst_target = ally
	if not worst_target:
		return {}
	var score = leader.isolationism * 120.0 + leader.aggression * 35.0 - leader.diplomacy * 85.0 + max(0.0, 70.0 - worst_relation) * 0.55
	return _decision(country, "break_alliance", score, worst_target)

func _score_declare_war(country: Country, countries: Array, year: int) -> Dictionary:
	if _on_cooldown(country.id, "declare_war", year) or country.at_war_with.size() >= 2:
		return {}
	if country.military < 35.0 or country.stability < 18.0:
		return {}
	var leader = country.get_leader()
	var best_target: Country = null
	var best_score := -999.0
	for other in countries:
		if other.id == country.id:
			continue
		if other.id in country.at_war_with or other.id in country.allies:
			continue
		var relation = float(country.relations.get(str(other.id), 0.0))
		var power_gap = country.military - other.military
		var score = leader.aggression * 140.0 + leader.ambition * 75.0 - leader.diplomacy * 90.0 - leader.isolationism * 35.0
		score += max(0.0, -relation) * 0.62
		score += power_gap * 0.35
		score += (1.0 if country.ideology != other.ideology else 0.0) * 8.0
		score -= country.at_war_with.size() * 35.0
		if score > best_score:
			best_score = score
			best_target = other
	if not best_target:
		return {}
	return _decision(country, "declare_war", best_score, best_target)

func _execute_decision(decision: Dictionary, countries: Array, year: int) -> Dictionary:
	var country = _find_country(countries, int(decision.get("country_id", -1)))
	var target = _find_country(countries, int(decision.get("target_id", -1)))
	if not country:
		return {}
	var leader = country.get_leader()
	match str(decision.get("type", "")):
		"invest_technology":
			country.economy = clampf(country.economy - 3.0, 0.0, 100.0)
			country.technology = clampf(country.technology + randf_range(2.0, 5.0) + leader.ambition * 4.0, 0.0, 100.0)
			return _event("leader_invest_technology", [country.id], leader.display_name() + " inicia um plano nacional de pesquisa em " + country.country_name + ". Laboratorios recebem verba, mas a economia sente o custo.", "medium")
		"militarize":
			country.economy = clampf(country.economy - randf_range(2.5, 5.0), 0.0, 100.0)
			country.military = clampf(country.military + randf_range(4.0, 8.0) + leader.aggression * 5.0, 0.0, 100.0)
			country.stability = clampf(country.stability - randf_range(0.5, 2.0), 0.0, 100.0)
			return _event("leader_militarize", [country.id], leader.display_name() + " militariza " + country.country_name + ". Fabricas mudam para producao de armas e a populacao teme o proximo passo.", "medium")
		"suppress_unrest":
			country.stability = clampf(country.stability + randf_range(5.0, 10.0), 0.0, 100.0)
			country.economy = clampf(country.economy - randf_range(1.0, 4.0), 0.0, 100.0)
			return _event("leader_suppress_unrest", [country.id], leader.display_name() + " reprime revoltas em " + country.country_name + ". A ordem volta as ruas, mas o medo tambem.", "high")
		"seek_alliance":
			if not target:
				return {}
			_add_alliance(country, target)
			return _event("leader_alliance", [country.id, target.id], leader.display_name() + " firma alianca com " + target.country_name + ". O bloco ganha peso e muda o equilibrio diplomatico.", "medium")
		"break_alliance":
			if not target:
				return {}
			country.allies.erase(target.id)
			target.allies.erase(country.id)
			country.relations[str(target.id)] = max(-100.0, float(country.relations.get(str(target.id), 0.0)) - 18.0)
			target.relations[str(country.id)] = max(-100.0, float(target.relations.get(str(country.id), 0.0)) - 18.0)
			return _event("leader_break_alliance", [country.id, target.id], leader.display_name() + " rompe tratados com " + target.country_name + ". As fronteiras esfriam e antigos aliados viram incerteza.", "medium")
		"declare_war":
			if not target:
				return {}
			if not target.id in country.at_war_with:
				country.at_war_with.append(target.id)
			if not country.id in target.at_war_with:
				target.at_war_with.append(country.id)
			country.relations[str(target.id)] = -100
			target.relations[str(country.id)] = -100
			return _event("leader_declares_war", [country.id, target.id], leader.display_name() + " decide atacar " + target.country_name + ". A personalidade do lider virou geopolitica: tropas cruzam a fronteira.", "critical")
	return {}

func _decision(country: Country, type: String, score: float, target: Country = null) -> Dictionary:
	var result = {
		"type": type,
		"country_id": country.id,
		"score": score,
	}
	if target:
		result["target_id"] = target.id
	return result

func _event(type: String, country_ids: Array, desc: String, severity: String) -> Dictionary:
	return {
		"type": type,
		"countries": country_ids,
		"desc": desc,
		"severity": severity,
	}

func _activation_chance(score: float) -> float:
	return clampf((score - DECISION_THRESHOLD) / 42.0, 0.18, 0.78)

func _omen_weight(country: Country, intel: Dictionary) -> float:
	var priority_score = float(intel.get("priority_score", 0.0))
	var weight = priority_score
	match str(intel.get("war_risk", "baixo")):
		"alto":
			weight += 34.0
		"medio":
			weight += 16.0
	if country.stability < 28.0:
		weight += 20.0
	if country.technology > 78.0 and country.stability > 55.0:
		weight += 12.0
	if priority_score < 52.0 and country.stability >= 28.0:
		return 0.0
	return weight

func _omen_text(country: Country, intel: Dictionary) -> String:
	var priority = str(intel.get("priority", "Observar"))
	var risk = str(intel.get("war_risk", "baixo"))
	var target = str(intel.get("likely_target_name", ""))
	if risk == "alto" and target != "":
		return "[PRESSAGIO] " + country.country_name + " esta perto de guerra contra " + target + ". " + str(intel.get("reason", ""))
	if country.stability < 28.0:
		return "[PRESSAGIO] " + country.country_name + " mostra sinais de colapso interno. Estabilidade baixa pode forcar repressao ou revolta."
	if priority == "Buscar alianca":
		return "[PRESSAGIO] " + country.country_name + " tenta formar um bloco diplomatico. Uma nova alianca pode mudar o equilibrio regional."
	if priority == "Investir em tecnologia":
		return "[PRESSAGIO] " + country.country_name + " prepara salto tecnologico. Se nada impedir, pode acelerar rumo a uma nova era."
	if priority == "Militarizar":
		return "[PRESSAGIO] " + country.country_name + " aumenta pressao militar. O exercito pode virar a politica do pais."
	return "[PRESSAGIO] " + country.country_name + " entrou em fase decisiva: " + priority + "."

func _decision_label(type: String) -> String:
	match type:
		"invest_technology":
			return "Investir em tecnologia"
		"militarize":
			return "Militarizar"
		"suppress_unrest":
			return "Reprimir instabilidade"
		"seek_alliance":
			return "Buscar alianca"
		"break_alliance":
			return "Romper alianca"
		"declare_war":
			return "Preparar guerra"
	return "Observar"

func _risk_label(score: float) -> String:
	if score >= 82.0:
		return "alto"
	if score >= 58.0:
		return "medio"
	return "baixo"

func _decision_reason(country: Country, decision: Dictionary, war_target: Country) -> String:
	var leader = country.get_leader()
	match str(decision.get("type", "wait")):
		"invest_technology":
			return "Ambicao do lider, economia disponivel e busca por avanco de era."
		"militarize":
			return "Perfil agressivo, pressao militar e medo de rivais."
		"suppress_unrest":
			return "Estabilidade baixa; o lider prefere ordem antes de reformas."
		"seek_alliance":
			return "Diplomacia alta e relacoes favoraveis com possiveis parceiros."
		"break_alliance":
			return "Isolacionismo e desgaste diplomatico com aliados."
		"declare_war":
			if war_target:
				return "Rival provavel: " + war_target.country_name + ". Relacao ruim, ambicao e calculo militar elevam o risco."
			return "Agressividade e ambicao deixam o pais propenso a conflito."
	if leader:
		return "Traços atuais: " + leader.trait_label() + ". Sem pressao forte no momento."
	return "Sem leitura politica suficiente."

func _on_cooldown(country_id: int, type: String, year: int) -> bool:
	var key = str(country_id) + ":" + type
	return year - int(_cooldowns.get(key, -999)) < COOLDOWN_YEARS

func _set_cooldown(country_id: int, type: String, year: int) -> void:
	_cooldowns[str(country_id) + ":" + type] = year

func _shared_enemy_bonus(a: Country, b: Country) -> float:
	var count := 0.0
	for enemy_id in a.at_war_with:
		if enemy_id in b.at_war_with:
			count += 1.0
	return count

func _add_alliance(a: Country, b: Country) -> void:
	if not b.id in a.allies:
		a.allies.append(b.id)
	if not a.id in b.allies:
		b.allies.append(a.id)
	a.relations[str(b.id)] = min(100.0, float(a.relations.get(str(b.id), 0.0)) + 18.0)
	b.relations[str(a.id)] = min(100.0, float(b.relations.get(str(a.id), 0.0)) + 18.0)

func _find_country(countries: Array, id: int) -> Country:
	for country in countries:
		if country.id == id:
			return country
	return null
