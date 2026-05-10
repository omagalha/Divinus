class_name EventRunner
extends RefCounted

func can_run(definition: Dictionary, country: Country) -> bool:
	return _conditions_match(definition.get("conditions", definition.get("start_conditions", {})), country)

func run_event(definition: Dictionary, country: Country, year: int, countries: Array = []) -> Dictionary:
	_apply_effects(country, definition.get("effects", {}), countries)
	return {
		"year": year,
		"type": definition.get("id", "event"),
		"title": definition.get("title", "Evento"),
		"countries": [country.id],
		"severity": definition.get("severity", "low"),
		"desc": _render_news(_pick_news(definition), country),
	}

func _conditions_match(conditions: Dictionary, country: Country) -> bool:
	if conditions.has("ideology") and country.ideology != conditions["ideology"]:
		return false
	if conditions.has("min_stability") and country.stability < float(conditions["min_stability"]):
		return false
	if conditions.has("max_stability") and country.stability > float(conditions["max_stability"]):
		return false
	if conditions.has("min_economy") and country.economy < float(conditions["min_economy"]):
		return false
	if conditions.has("max_economy") and country.economy > float(conditions["max_economy"]):
		return false
	if conditions.has("min_technology") and country.technology < float(conditions["min_technology"]):
		return false
	if conditions.has("min_military") and country.military < float(conditions["min_military"]):
		return false
	if conditions.has("min_population") and country.population < float(conditions["min_population"]):
		return false
	if conditions.has("min_faith") and country.faith < float(conditions["min_faith"]):
		return false
	if conditions.has("max_faith") and country.faith > float(conditions["max_faith"]):
		return false
	if conditions.has("min_aggression") and country.aggression < float(conditions["min_aggression"]):
		return false
	if conditions.has("max_aggression") and country.aggression > float(conditions["max_aggression"]):
		return false
	if conditions.has("era") and country.era != int(conditions["era"]):
		return false
	if conditions.has("min_era") and country.era < int(conditions["min_era"]):
		return false
	if conditions.has("max_era") and country.era > int(conditions["max_era"]):
		return false
	return true

func _apply_effects(country: Country, effects: Dictionary, countries: Array) -> void:
	for key in effects.keys():
		match key:
			"population":
				var value = float(effects[key])
				country.population = max(0.1, country.population + value)
			"population_percent":
				var value = float(effects[key])
				country.population = max(0.1, country.population + country.population * value)
			"economy":
				var value = float(effects[key])
				country.economy = clampf(country.economy + value, 0.0, 100.0)
			"technology":
				var value = float(effects[key])
				country.technology = clampf(country.technology + value, 0.0, 100.0)
			"military":
				var value = float(effects[key])
				country.military = clampf(country.military + value, 0.0, 100.0)
			"stability":
				var value = float(effects[key])
				country.stability = clampf(country.stability + value, 0.0, 100.0)
			"faith":
				var value = float(effects[key])
				country.faith = clampf(country.faith + value, 0.0, 100.0)
			"aggression":
				var value = float(effects[key])
				country.aggression = clampf(country.aggression + value, 0.0, 100.0)
			"ideology":
				country.ideology = str(effects[key])
			"era_regress":
				if bool(effects[key]):
					country.era = max(0, country.era - 1)
			"declare_war_random", "declare_war_neighbor":
				if bool(effects[key]):
					_declare_war(country, countries)

func _declare_war(country: Country, countries: Array) -> void:
	var candidates: Array = []
	for other in countries:
		if other.id != country.id and not other.id in country.at_war_with:
			candidates.append(other)
	if candidates.is_empty():
		return
	var target: Country = candidates[randi() % candidates.size()]
	country.at_war_with.append(target.id)
	target.at_war_with.append(country.id)

func _pick_news(definition: Dictionary) -> String:
	var news = definition.get("news", "")
	if news is Array and not news.is_empty():
		return news[randi() % news.size()]
	return str(news)

func _render_news(template: String, country: Country) -> String:
	var leader = country.get("leader")
	var leader_name = leader.display_name() if leader else "o governo"
	return template.replace("{country}", country.country_name).replace("{leader}", leader_name)
