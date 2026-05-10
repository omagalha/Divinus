class_name EventSystem
extends Node

func roll_events(countries: Array, year: int) -> Array:
	var triggered: Array = []
	for _i in range(2):
		if randf() < 0.65:
			var event = _pick_event(countries, year)
			if event != {}:
				triggered.append(event)
	return triggered

func _pick_event(countries: Array, year: int) -> Dictionary:
	if countries.is_empty():
		return {}

	var country: Country = countries[randi() % countries.size()]
	var leader = country.get("leader")
	var roll = randf()

	# ── Pandemia ──────────────────────────────
	if roll < 0.10:
		var deaths = snappedf(country.population * 0.08, 0.1)
		country.population = max(0.5, country.population - deaths)
		country.economy    = max(0, country.economy - 12)
		country.stability  = max(0, country.stability - 15)
		return {
			"type": "pandemic",
			"countries": [country.id],
			"desc": _pick([
				"🦠 A Grande Praga de " + str(year) + " assola " + country.country_name + " — " + str(snappedf(deaths, 0.1)) + "M mortos. " + leader.display_name() + " declara emergência nacional.",
				"🦠 Vírus desconhecido paralisa " + country.country_name + ". Hospitais em colapso, fronteiras fechadas. " + leader.display_name() + " implora por ajuda internacional.",
				"🦠 Pandemia devasta " + country.country_name + ": economia despenca, ruas desertas. O governo de " + leader.display_name() + " perde o controle da situação.",
			]),
			"severity": "high"
		}

	# ── Descoberta tecnológica ─────────────────
	elif roll < 0.22:
		var boost = randf_range(8, 18)
		country.technology = min(100, country.technology + boost)
		country.economy    = min(100, country.economy + randf_range(3, 8))
		var discoveries = ["energia de fusão", "computação quântica", "nanomedicina", "propulsão avançada", "engenharia genética"]
		var discovery = discoveries[randi() % discoveries.size()]
		return {
			"type": "tech_discovery",
			"countries": [country.id],
			"desc": _pick([
				"🔬 Cientistas de " + country.country_name + " dominam " + discovery + ". O mundo observa com admiração e temor.",
				"🔬 Avanço histórico em " + country.country_name + ": pesquisadores anunciam descoberta de " + discovery + " — " + leader.display_name() + " celebra em rede nacional.",
				"🔬 " + country.country_name + " dá salto tecnológico decisivo com " + discovery + ". Rivais correm para não ficar para trás.",
			]),
			"severity": "low"
		}

	# ── Crise econômica ───────────────────────
	elif roll < 0.33:
		var drop = randf_range(10, 22)
		country.economy   = max(0, country.economy - drop)
		country.stability = max(0, country.stability - 10)
		return {
			"type": "economic_crisis",
			"countries": [country.id],
			"desc": _pick([
				"📉 Colapso financeiro em " + country.country_name + ": bolsa despenca, desemprego explode. " + leader.display_name() + " enfrenta protestos nas ruas.",
				"📉 " + country.country_name + " mergulha em recessão profunda. " + leader.display_name() + " anuncia cortes de emergência — população vai às ruas.",
				"📉 Crise econômica sem precedentes paralisa " + country.country_name + ". Inflação galopante, reservas zeradas. O governo de " + leader.display_name() + " é questionado.",
			]),
			"severity": "high"
		}

	# ── Revolução ─────────────────────────────
	elif roll < 0.42:
		var old_ideology = country.ideology
		var options = ["democracy", "autocracy", "theocracy", "anarchy"]
		options.erase(country.ideology)
		country.ideology  = options[randi() % options.size()]
		country.stability = max(0, country.stability - 20)
		country.military  = min(100, country.military + 10)
		return {
			"type": "revolution",
			"countries": [country.id],
			"desc": _pick([
				"✊ O regime de " + leader.display_name() + " cai em chamas. " + country.country_name + " abandona a " + _ideology_pt(old_ideology) + " e abraça a " + _ideology_pt(country.ideology) + " em revolução sangrenta.",
				"✊ Insurreição popular derruba o governo de " + country.country_name + ". " + leader.display_name() + " foge enquanto multidões tomam a capital. Nova ordem: " + _ideology_pt(country.ideology) + ".",
				"✊ Golpe de estado sacude " + country.country_name + ". " + leader.display_name() + " é deposto — o país muda de " + _ideology_pt(old_ideology) + " para " + _ideology_pt(country.ideology) + " da noite para o dia.",
			]),
			"severity": "high"
		}

	# ── Desastre natural ──────────────────────
	elif roll < 0.52:
		var deaths = snappedf(country.population * 0.05, 0.1)
		country.population = max(0.5, country.population - deaths)
		country.economy    = max(0, country.economy - 10)
		var disasters = ["terremoto devastador", "inundação catastrófica", "erupção vulcânica", "furacão de categoria 5", "tsunami destruidor"]
		var disaster = disasters[randi() % disasters.size()]
		return {
			"type": "natural_disaster",
			"countries": [country.id],
			"desc": _pick([
				"🌋 " + disaster.capitalize() + " varre regiões inteiras de " + country.country_name + ". " + str(snappedf(deaths, 0.1)) + "M mortos — " + leader.display_name() + " pede ajuda ao mundo.",
				"🌋 Tragédia em " + country.country_name + ": " + disaster + " destrói cidades inteiras. Reconstrução levará décadas.",
				"🌋 " + country.country_name + " é atingida por " + disaster + ". Infraestrutura em colapso, população deslocada em massa.",
			]),
			"severity": "medium"
		}

	# ── Boom econômico ────────────────────────
	elif roll < 0.62:
		var gain = randf_range(8, 18)
		country.economy    = min(100, country.economy + gain)
		country.population = min(9999, country.population + country.population * 0.03)
		var sectors = ["petróleo", "tecnologia", "comércio marítimo", "mineração", "agricultura", "turismo"]
		var sector = sectors[randi() % sectors.size()]
		return {
			"type": "economic_boom",
			"countries": [country.id],
			"desc": _pick([
				"📈 Era de ouro em " + country.country_name + ": boom de " + sector + " transforma o país em potência regional. " + leader.display_name() + " celebra crescimento recorde.",
				"📈 " + country.country_name + " atinge crescimento de dois dígitos pelo terceiro ano seguido. Investidores de todo o mundo chegam.",
				"📈 " + leader.display_name() + " anuncia o maior crescimento da história de " + country.country_name + ". Setor de " + sector + " lidera a expansão.",
			]),
			"severity": "low"
		}

	# ── Descoberta de recursos ────────────────
	elif roll < 0.72:
		var gain = randf_range(12, 25)
		country.economy = min(100, country.economy + gain)
		var resources = ["petróleo", "lítio", "diamantes", "urânio", "minerais raros", "gás natural", "ouro"]
		var resource = resources[randi() % resources.size()]
		return {
			"type": "resource_discovery",
			"countries": [country.id],
			"desc": _pick([
				"⛏️ Reservas imensas de " + resource + " descobertas em " + country.country_name + ". " + leader.display_name() + " anuncia nova era de prosperidade.",
				"⛏️ Geólogos de " + country.country_name + " encontram o maior depósito de " + resource + " já registrado. Potências estrangeiras negociam acesso.",
				"⛏️ " + country.country_name + " vira alvo de interesse global após descoberta de vastas reservas de " + resource + ". " + leader.display_name() + " negocia contratos bilionários.",
			]),
			"severity": "low"
		}

	# ── Fome ──────────────────────────────────
	elif roll < 0.80:
		var deaths = snappedf(country.population * 0.04, 0.1)
		country.population = max(0.5, country.population - deaths)
		country.stability  = max(0, country.stability - 12)
		return {
			"type": "famine",
			"countries": [country.id],
			"desc": _pick([
				"🍂 Colheitas destruídas, estoques zerados: fome generalizada mata " + str(snappedf(deaths, 0.1)) + "M em " + country.country_name + ". " + leader.display_name() + " pede socorro.",
				"🍂 Seca prolongada devasta a produção agrícola de " + country.country_name + ". Filas para comida crescem enquanto o governo de " + leader.display_name() + " falha em responder.",
				"🍂 " + country.country_name + " enfrenta a pior fome em gerações. Distúrbios explodem nas cidades — " + leader.display_name() + " declara estado de calamidade.",
			]),
			"severity": "medium"
		}

	# ── Aliança ────────────────────────────────
	elif roll < 0.90 and countries.size() >= 2:
		var other: Country = countries[randi() % countries.size()]
		if other.id != country.id:
			var key_a = str(other.id)
			var key_b = str(country.id)
			country.relations[key_a] = min(100, country.relations.get(key_a, 0) + 25)
			other.relations[key_b]   = min(100, other.relations.get(key_b, 0) + 25)
			if not other.id in country.allies:
				country.allies.append(other.id)
			if not country.id in other.allies:
				other.allies.append(country.id)
			var other_leader = other.get("leader")
			return {
				"type": "alliance",
				"countries": [country.id, other.id],
				"desc": _pick([
					"🤝 " + leader.display_name() + " e " + other_leader.display_name() + " firmam pacto histórico. " + country.country_name + " e " + other.country_name + " unem forças — vizinhos preocupados.",
					"🤝 Aliança surpresa: " + country.country_name + " e " + other.country_name + " anunciam tratado de cooperação. " + leader.display_name() + " e " + other_leader.display_name() + " selam o acordo.",
					"🤝 Aproximação diplomática entre " + country.country_name + " e " + other.country_name + ". " + leader.display_name() + " visita a capital de " + other.country_name + " — pacto assinado.",
				]),
				"severity": "low"
			}

	# ── IA / Evento futurista ──────────────────
	elif country.era >= 3:
		country.technology = min(100, country.technology + 5)
		country.stability  = max(0, country.stability - 8)
		return {
			"type": "ai_event",
			"countries": [country.id],
			"desc": _pick([
				"🤖 IAs de " + country.country_name + " começam a tomar decisões políticas autônomas. " + leader.display_name() + " perde o controle — a população entra em pânico.",
				"🤖 Singularidade tecnológica em " + country.country_name + ": algoritmos substituem ministros. " + leader.display_name() + " é aconselhado por máquinas.",
				"🤖 " + country.country_name + " lança IA soberana que controla defesa e economia. O mundo observa — o futuro chegou cedo demais.",
			]),
			"severity": "medium"
		}

	return {}

func _pick(options: Array) -> String:
	return options[randi() % options.size()]

func _ideology_pt(ideology: String) -> String:
	match ideology:
		"democracy":  return "democracia"
		"autocracy":  return "autocracia"
		"theocracy":  return "teocracia"
		"anarchy":    return "anarquia"
	return ideology
