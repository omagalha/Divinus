class_name DivineObjectives
extends RefCounted

const OBJECTIVE_INTERVAL := 10

var active_objective: Dictionary = {}
var _last_objective_year := -999
var _objective_index := 0

func ensure_objective(countries: Array, year: int) -> Array:
	if not active_objective.is_empty():
		return []
	if year - _last_objective_year < OBJECTIVE_INTERVAL and _last_objective_year > 0:
		return []
	active_objective = _create_objective(countries, year)
	_last_objective_year = year
	if active_objective.is_empty():
		return []
	return [_objective_event("divine_objective_started", active_objective.get("title", "Objetivo Divino"), active_objective.get("description", ""), "objective")]

func evaluate(countries: Array, year: int, turn_events: Array) -> Array:
	if active_objective.is_empty():
		return []

	var result: Dictionary = {}
	match str(active_objective.get("type", "")):
		"peace_watch":
			result = _evaluate_peace_watch(year, turn_events)
		"ascension":
			result = _evaluate_ascension(countries, year)
		"salvation":
			result = _evaluate_salvation(countries, year)
		"future_spark":
			result = _evaluate_future_spark(countries, year)

	if result.is_empty():
		return []

	var finished = active_objective.duplicate()
	active_objective = {}
	var event_type = "divine_objective_completed" if bool(result.get("completed", false)) else "divine_objective_failed"
	var severity = "objective" if bool(result.get("completed", false)) else "high"
	var reward = int(finished.get("reward", 0)) if bool(result.get("completed", false)) else 0
	var desc = str(result.get("desc", ""))
	if reward > 0:
		desc += " Recompensa: +" + str(reward) + " pontos divinos."

	return [{
		"type": event_type,
		"severity": severity,
		"reward_points": reward,
		"countries": result.get("countries", []),
		"desc": desc,
	}]

func get_active_text() -> String:
	if active_objective.is_empty():
		return "Objetivo Divino: aguardando novo chamado."
	return "Objetivo Divino: " + str(active_objective.get("title", "")) + " | " + str(active_objective.get("progress", active_objective.get("description", "")))

func _create_objective(countries: Array, year: int) -> Dictionary:
	var type_order = ["peace_watch", "salvation", "ascension", "future_spark"]
	for offset in range(type_order.size()):
		var type = type_order[(_objective_index + offset) % type_order.size()]
		var objective = _build_objective(type, countries, year)
		if not objective.is_empty():
			_objective_index += offset + 1
			return objective
	return {}

func _build_objective(type: String, countries: Array, year: int) -> Dictionary:
	match type:
		"peace_watch":
			return {
				"type": "peace_watch",
				"title": "Pacificador",
				"description": "Evite novas declaracoes de guerra por 10 anos.",
				"progress": "Nenhuma nova guerra ate o Ano " + str(year + 10) + ".",
				"deadline": year + 10,
				"reward": 8,
			}
		"ascension":
			return {
				"type": "ascension",
				"title": "Ascensao Guiada",
				"description": "Faca qualquer civilizacao avancar de era.",
				"progress": "Aguardando avancos de era ate o Ano " + str(year + 12) + ".",
				"deadline": year + 12,
				"baseline_era": _max_era(countries),
				"reward": 10,
			}
		"salvation":
			var target = _lowest_stability_country(countries)
			if not target or target.stability > 42.0:
				return {}
			return {
				"type": "salvation",
				"title": "Salvar " + target.country_name,
				"description": "Eleve a estabilidade de " + target.country_name + " para 55 antes do colapso.",
				"progress": target.country_name + " precisa chegar a 55 de estabilidade ate o Ano " + str(year + 8) + ".",
				"deadline": year + 8,
				"target_id": target.id,
				"reward": 7,
			}
		"future_spark":
			if _max_era(countries) >= 4:
				return {}
			return {
				"type": "future_spark",
				"title": "Centelha do Futuro",
				"description": "Guie uma nacao ate a Era Futura.",
				"progress": "Algum pais precisa atingir a Era Futura ate o Ano " + str(year + 18) + ".",
				"deadline": year + 18,
				"reward": 12,
			}
	return {}

func _evaluate_peace_watch(year: int, turn_events: Array) -> Dictionary:
	for event in turn_events:
		if str(event.get("type", "")) in ["war_declared", "leader_declares_war"]:
			return {
				"completed": false,
				"countries": event.get("countries", []),
				"desc": "[OBJETIVO FALHOU] A paz foi quebrada antes do prazo.",
			}
	if year >= int(active_objective.get("deadline", 0)):
		return {
			"completed": true,
			"desc": "[OBJETIVO CUMPRIDO] Voce segurou o mundo longe de novas guerras.",
		}
	return {}

func _evaluate_ascension(countries: Array, year: int) -> Dictionary:
	var baseline = int(active_objective.get("baseline_era", 0))
	for country in countries:
		if country.era > baseline:
			return {
				"completed": true,
				"countries": [country.id],
				"desc": "[OBJETIVO CUMPRIDO] " + country.country_name + " avancou de era sob sua influencia.",
			}
	if year >= int(active_objective.get("deadline", 0)):
		return {
			"completed": false,
			"desc": "[OBJETIVO FALHOU] Nenhuma civilizacao conseguiu romper para uma nova era.",
		}
	return {}

func _evaluate_salvation(countries: Array, year: int) -> Dictionary:
	var target = _find_country(countries, int(active_objective.get("target_id", -1)))
	if not target:
		return {
			"completed": false,
			"desc": "[OBJETIVO FALHOU] O pais alvo desapareceu da simulacao.",
		}
	if target.stability >= 55.0:
		return {
			"completed": true,
			"countries": [target.id],
			"desc": "[OBJETIVO CUMPRIDO] " + target.country_name + " saiu da beira do colapso.",
		}
	if target.stability <= 10.0 or year >= int(active_objective.get("deadline", 0)):
		return {
			"completed": false,
			"countries": [target.id],
			"desc": "[OBJETIVO FALHOU] " + target.country_name + " afundou antes de ser salvo.",
		}
	return {}

func _evaluate_future_spark(countries: Array, year: int) -> Dictionary:
	for country in countries:
		if country.era >= 4:
			return {
				"completed": true,
				"countries": [country.id],
				"desc": "[OBJETIVO CUMPRIDO] " + country.country_name + " acendeu a Era Futura.",
			}
	if year >= int(active_objective.get("deadline", 0)):
		return {
			"completed": false,
			"desc": "[OBJETIVO FALHOU] O futuro nao chegou a tempo.",
		}
	return {}

func _objective_event(type: String, title: String, desc: String, severity: String) -> Dictionary:
	return {
		"type": type,
		"severity": severity,
		"countries": [],
		"desc": "[OBJETIVO DIVINO] " + title + ": " + desc,
	}

func _max_era(countries: Array) -> int:
	var value := 0
	for country in countries:
		value = max(value, int(country.era))
	return value

func _lowest_stability_country(countries: Array) -> Country:
	var target: Country = null
	for country in countries:
		if not target or country.stability < target.stability:
			target = country
	return target

func _find_country(countries: Array, id: int) -> Country:
	for country in countries:
		if country.id == id:
			return country
	return null
