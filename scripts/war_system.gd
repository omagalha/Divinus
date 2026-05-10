class_name WarSystem
extends Node

func process_wars(countries: Array) -> Array:
	var events: Array = []
	events.append_array(_check_new_wars(countries))
	events.append_array(_process_alliance_calls(countries))
	events.append_array(_simulate_active_wars(countries))
	events.append_array(_check_peace(countries))
	return events

func _check_new_wars(countries: Array) -> Array:
	var events: Array = []

	for i in range(countries.size()):
		for j in range(i + 1, countries.size()):
			var a: Country = countries[i]
			var b: Country = countries[j]

			if b.id in a.at_war_with:
				continue

			var war_chance = _calculate_war_chance(a, b)
			if randf() < war_chance:
				a.at_war_with.append(b.id)
				b.at_war_with.append(a.id)

				var key_a = str(b.id)
				var key_b = str(a.id)
				a.relations[key_a] = max(-100, a.relations.get(key_a, 0) - 40)
				b.relations[key_b] = max(-100, b.relations.get(key_b, 0) - 40)

				var leader_a = _leader(a)
				var leader_b = _leader(b)
				var reason = _war_reason(a, b)
				events.append({
					"type": "war_declared",
					"countries": [a.id, b.id],
					"desc": _pick([
						"⚔️ " + leader_a.display_name() + " (" + leader_a.trait_label() + ") lança " + a.country_name + " em guerra total contra " + b.country_name + ". " + reason,
						"⚔️ Exércitos de " + a.country_name + " cruzam a fronteira ao amanhecer. " + leader_b.display_name() + " chama o ataque de 'ato de barbaridade'. " + reason,
						"⚔️ Guerra declarada: " + a.country_name + " x " + b.country_name + ". " + leader_a.display_name() + " promete vitória rápida — " + leader_b.display_name() + " jura resistir até o fim.",
						"⚔️ Tensão vira conflito: " + leader_a.display_name() + " assina declaração de guerra contra " + b.country_name + ". Mundo observa em choque. " + reason,
					]),
					"severity": "critical"
				})

	return events

func _calculate_war_chance(a: Country, b: Country) -> float:
	var chance = 0.0
	var relation = a.relations.get(str(b.id), 0)
	if relation < -50:
		chance += 0.08
	elif relation < -20:
		chance += 0.03
	if a.military > 70:
		chance += 0.03
	if a.stability < 25:
		chance += 0.04
	if a.ideology != b.ideology and randf() < 0.3:
		chance += 0.02
	if abs(a.era - b.era) >= 2:
		chance += 0.02
	var leader_a = _leader(a)
	var leader_b = _leader(b)
	if leader_a:
		chance += leader_a.war_modifier()
	if leader_b:
		chance += leader_b.aggression * 0.08 - leader_b.diplomacy * 0.04
	return clampf(chance, 0.0, 0.35)

func _simulate_active_wars(countries: Array) -> Array:
	var events: Array = []
	var processed: Array = []

	for country in countries:
		for enemy_id in country.at_war_with:
			var pair = [min(country.id, enemy_id), max(country.id, enemy_id)]
			if pair in processed:
				continue
			processed.append(pair)

			var enemy = _find_country(countries, enemy_id)
			if not enemy:
				continue

			var a_power = country.military + randf_range(-10, 10)
			var b_power = enemy.military   + randf_range(-10, 10)

			var a_damage = (b_power / 100.0) * randf_range(3.0, 8.0)
			var b_damage = (a_power / 100.0) * randf_range(3.0, 8.0)

			country.population = max(0.5, country.population - country.population * (a_damage / 100.0))
			enemy.population   = max(0.5, enemy.population   - enemy.population   * (b_damage / 100.0))
			country.economy = max(0, country.economy - a_damage * 0.8)
			enemy.economy   = max(0, enemy.economy   - b_damage * 0.8)
			country.stability = max(0, country.stability - 3)
			enemy.stability   = max(0, enemy.stability   - 3)

			var a_winning = a_power > b_power
			var leader_a = _leader(country)
			var leader_b = _leader(enemy)
			var winner = country.country_name if a_winning else enemy.country_name
			var loser  = enemy.country_name if a_winning else country.country_name

			events.append({
				"type": "war_ongoing",
				"countries": [country.id, enemy.id],
				"desc": _pick([
					"💥 Batalha brutal: " + winner + " avança sobre " + loser + ". Baixas sobem dos dois lados — o fim parece distante.",
					"💥 " + leader_a.display_name() + " ordena ofensiva total. Cidades em " + enemy.country_name + " são bombardeadas enquanto a resistência é esmagada.",
					"💥 Guerra de " + country.country_name + " x " + enemy.country_name + " entra em nova fase. " + loser + " recua — " + winner + " sente o cheiro da vitória.",
					"💥 " + leader_b.display_name() + " recusa rendição apesar das perdas devastadoras. " + enemy.country_name + " luta até o último homem.",
					"💥 Frente de batalha congela: " + country.country_name + " e " + enemy.country_name + " travam guerra de desgaste. Economias sangram.",
				]),
				"severity": "high"
			})

	return events

func _check_peace(countries: Array) -> Array:
	var events: Array = []

	for country in countries:
		var to_remove: Array = []
		for enemy_id in country.at_war_with:
			var enemy = _find_country(countries, enemy_id)
			if not enemy:
				to_remove.append(enemy_id)
				continue

			var both_exhausted = country.economy < 20 and enemy.economy < 20
			var leader_country = _leader(country)
			var leader_enemy   = _leader(enemy)
			var peace_chance = 0.08 + leader_country.peace_modifier(leader_enemy)
			var random_peace = randf() < clampf(peace_chance, 0.01, 0.28)

			if both_exhausted or random_peace:
				to_remove.append(enemy_id)
				enemy.at_war_with.erase(country.id)

				var stronger = country if country.military > enemy.military else enemy
				var weaker   = enemy if country.military > enemy.military else country

				events.append({
					"type": "peace",
					"countries": [country.id, enemy.id],
					"desc": _pick([
						"🕊️ " + leader_country.display_name() + " e " + leader_enemy.display_name() + " assinam cessar-fogo. " + weaker.country_name + " cede territórios — " + stronger.country_name + " dita os termos.",
						"🕊️ A guerra acabou. " + country.country_name + " e " + enemy.country_name + " saem exaustos — nenhum lado pode comemorar. Reconstrução levará décadas.",
						"🕊️ Tratado de paz entre " + country.country_name + " e " + enemy.country_name + ". " + leader_country.display_name() + " e " + leader_enemy.display_name() + " se olham com ódio ao assinar.",
						"🕊️ Fim do conflito: " + stronger.country_name + " vence a guerra mas perde a paz — " + weaker.country_name + " guarda rancor por gerações.",
					]),
					"severity": "low"
				})

		for id in to_remove:
			country.at_war_with.erase(id)

	return events

func _process_alliance_calls(countries: Array) -> Array:
	var events: Array = []
	var processed: Array = []

	for country in countries:
		for enemy_id in country.at_war_with.duplicate():
			var enemy = _find_country(countries, enemy_id)
			if not enemy:
				continue

			var pair_key = str(min(country.id, enemy_id)) + ":" + str(max(country.id, enemy_id))
			if pair_key in processed:
				continue
			processed.append(pair_key)

			events.append_array(_call_allies(country, enemy, countries))
			events.append_array(_call_allies(enemy, country, countries))

	return events

func _call_allies(defended: Country, enemy: Country, countries: Array) -> Array:
	var events: Array = []

	for ally_id in defended.allies.duplicate():
		var ally = _find_country(countries, ally_id)
		if not ally:
			continue
		if ally.id == enemy.id:
			continue
		if enemy.id in ally.at_war_with:
			continue
		if ally.id in enemy.at_war_with:
			continue

		var relation_to_defended = ally.relations.get(str(defended.id), 0)
		var relation_to_enemy = ally.relations.get(str(enemy.id), 0)
		var leader_ally = _leader(ally)
		var call_chance = 0.22 + max(0.0, relation_to_defended / 180.0) - max(0.0, relation_to_enemy / 250.0)
		if leader_ally:
			call_chance += leader_ally.aggression * 0.18
			call_chance += leader_ally.diplomacy * 0.12
			call_chance -= leader_ally.isolationism * 0.35

		if randf() > clampf(call_chance, 0.05, 0.80):
			continue

		ally.at_war_with.append(enemy.id)
		enemy.at_war_with.append(ally.id)
		ally.relations[str(enemy.id)] = max(-100, ally.relations.get(str(enemy.id), 0) - 35)
		enemy.relations[str(ally.id)] = max(-100, enemy.relations.get(str(ally.id), 0) - 35)

		events.append({
			"type": "alliance_call",
			"countries": [ally.id, defended.id, enemy.id],
			"desc": _pick([
				"🛡️ EFEITO DOMINÓ: " + ally.country_name + " honra aliança com " + defended.country_name + " e declara guerra contra " + enemy.country_name + ". A crise regional se espalha.",
				"🛡️ " + leader_ally.display_name() + " aciona tratado militar: " + ally.country_name + " entra na guerra ao lado de " + defended.country_name + ".",
				"🛡️ Bloco em movimento: " + ally.country_name + " mobiliza tropas contra " + enemy.country_name + " após ataque a seu aliado " + defended.country_name + ".",
			]),
			"severity": "critical"
		})

	return events

func _war_reason(a: Country, b: Country) -> String:
	var relation = a.relations.get(str(b.id), 0)
	var leader_a = _leader(a)
	if relation < -60:
		return "Anos de ódio acumulado finalmente explodem."
	if a.ideology != b.ideology:
		return "Conflito ideológico: " + a.ideology + " vs " + b.ideology + "."
	if leader_a and leader_a.aggression > 0.7:
		return "A ambição de " + leader_a.display_name() + " não conhece limites."
	if a.military > 75:
		return "O exército de " + a.country_name + " é o maior da região — e quer provar."
	return "As razões são antigas e profundas."

func _pick(options: Array) -> String:
	return options[randi() % options.size()]

func _find_country(countries: Array, id: int) -> Country:
	for c in countries:
		if c.id == id:
			return c
	return null

func _leader(country: Country):
	return country.get("leader")
