class_name EventSystem
extends Node

const EventDatabaseScript = preload("res://scripts/events/event_database.gd")
const EventRunnerScript = preload("res://scripts/events/event_runner.gd")
const ChainSystemScript = preload("res://scripts/events/chain_system.gd")

const INTERACTIVE_EVENTS: Array = [
	{
		"id": "choice_revolt", "title": "Revolta Popular", "weight": 0.8, "severity": "high",
		"conditions": {"max_stability": 40},
		"news": [
			"⚠️ Trabalhadores de {country} tomam as ruas. {leader} enfrenta a maior crise da sua gestão.",
			"⚠️ Revoltas explodem em {country}. {leader} está no olho do furacão — o povo exige mudança.",
		],
		"choices": [
			{"label": "🤝 Negociar", "desc": "+15 estab  −8 eco", "effects": {"stability": 15, "economy": -8},
			 "result": "✅ {leader} se senta à mesa com os manifestantes. A crise se acalma — mas {country} pagou um preço econômico."},
			{"label": "⚔️ Reprimir", "desc": "+8 mil  −10 estab", "effects": {"military": 8, "stability": -10},
			 "result": "🔴 {leader} ordena dispersão pela força. As ruas silenciam — mas o ódio cresce em {country}."},
			{"label": "🙈 Ignorar", "desc": "−20 estab", "effects": {"stability": -20},
			 "result": "💀 {leader} vira as costas ao povo. A revolta de {country} se aprofunda sem resposta."},
		]
	},
	{
		"id": "choice_discovery", "title": "Descoberta de Recursos", "weight": 0.7, "severity": "medium",
		"conditions": {"min_era": 1},
		"news": [
			"💎 Geólogos de {country} descobrem vastos depósitos de minerais raros. {leader} tem uma decisão histórica pela frente.",
			"💎 Recursos imensuráveis encontrados em {country}. {leader} decide o destino desta riqueza.",
		],
		"choices": [
			{"label": "⛏️ Explorar já", "desc": "+18 eco  −8 estab", "effects": {"economy": 18, "stability": -8},
			 "result": "⚡ {country} mobiliza mineração massiva. Riqueza jorra — mas o povo sente o preço da pressa."},
			{"label": "🔬 Pesquisar primeiro", "desc": "+10 eco  +8 tec", "effects": {"economy": 10, "technology": 8},
			 "result": "🔬 {leader} investe em pesquisa antes de explorar. {country} ganha tecnologia e riqueza sustentável."},
			{"label": "🌿 Preservar", "desc": "+12 estab  +8 fé", "effects": {"stability": 12, "faith": 8},
			 "result": "🌿 {leader} protege os recursos. {country} ganha respeito e coesão interna."},
		]
	},
	{
		"id": "choice_epidemic", "title": "Epidemia", "weight": 0.6, "severity": "high",
		"conditions": {"min_population": 15},
		"news": [
			"🦠 Uma doença misteriosa avança por {country}. {leader} precisa agir — rápido.",
			"🦠 Epidemia declarada em {country}. As ruas estão vazias. {leader} tem nas mãos o destino de milhões.",
		],
		"choices": [
			{"label": "🏥 Quarentena total", "desc": "−12 eco  salva população", "effects": {"economy": -12, "stability": -5},
			 "result": "🏥 {leader} fecha fronteiras. A economia sofre — mas {country} controla o surto."},
			{"label": "💊 Tratamento experimental", "desc": "+8 tec  −5% pop", "effects": {"technology": 8, "population_percent": -0.05},
			 "result": "⚗️ {country} aposta em tratamentos não testados. A ciência avança — mas há perdas."},
			{"label": "🙏 Rezar e esperar", "desc": "−15 estab  −10% pop", "effects": {"stability": -15, "population_percent": -0.10},
			 "result": "☠️ {leader} paralisa diante da crise. {country} paga o preço mais alto: vidas."},
		]
	},
	{
		"id": "choice_succession", "title": "Crise de Liderança", "weight": 0.5, "severity": "high",
		"conditions": {"max_stability": 55},
		"news": [
			"👑 {leader} enfrenta desafio à sua autoridade em {country}. A crise ameaça o Estado.",
			"👑 Facções rivais disputam poder em {country}. {leader} precisa consolidar seu governo — ou ceder.",
		],
		"choices": [
			{"label": "🗳️ Eleições abertas", "desc": "+20 estab  −5 mil", "effects": {"stability": 20, "military": -5},
			 "result": "🗳️ {country} surpreende o mundo com eleições livres. {leader} sai fortalecido pela legitimidade."},
			{"label": "⚔️ Mão de ferro", "desc": "+15 mil  −10 estab", "effects": {"military": 15, "stability": -10},
			 "result": "⚔️ {leader} esmaga a oposição. {country} obedece — por medo."},
			{"label": "🤝 Coalizão", "desc": "+10 estab  +5 eco", "effects": {"stability": 10, "economy": 5},
			 "result": "🤝 {leader} divide o poder. {country} encontra equilíbrio — por enquanto."},
		]
	},
]

var database
var runner
var chain_system

func _ready() -> void:
	database = EventDatabaseScript.new()
	database.load_all()

	runner = EventRunnerScript.new()
	chain_system = ChainSystemScript.new()
	chain_system.setup(runner)

func roll_events(countries: Array, year: int) -> Array:
	var triggered: Array = []
	if countries.is_empty():
		return triggered

	triggered.append_array(chain_system.process_active(year, countries))

	for _i in range(2):
		if randf() < 0.30:
			var chain_event = _try_start_random_chain(countries, year)
			if not chain_event.is_empty():
				triggered.append(chain_event)

		if randf() < 0.55:
			var event = _roll_standalone(countries, year)
			if not event.is_empty():
				triggered.append(event)

	# Rola um evento interativo por turno (40% de chance)
	if randf() < 0.40:
		var event = _roll_interactive(countries, year)
		if not event.is_empty():
			triggered.append(event)

	return triggered

func _roll_interactive(countries: Array, year: int) -> Dictionary:
	var country: Country = countries[randi() % countries.size()]
	var candidates = _valid_definitions(INTERACTIVE_EVENTS, country)
	if candidates.is_empty():
		return {}
	var definition = _weighted_pick(candidates)
	return runner.run_event(definition, country, year, countries)

func _roll_standalone(countries: Array, year: int) -> Dictionary:
	var country: Country = countries[randi() % countries.size()]
	var candidates = _valid_definitions(database.standalone_events, country)
	if candidates.is_empty():
		return {}

	var definition = _weighted_pick(candidates)
	return runner.run_event(definition, country, year, countries)

func _try_start_random_chain(countries: Array, year: int) -> Dictionary:
	var country: Country = countries[randi() % countries.size()]
	var candidates = _valid_definitions(database.all_chains(), country)
	if candidates.is_empty():
		return {}

	var chain_def = _weighted_pick(candidates)
	return chain_system.try_start_chain(chain_def, country, year, countries)

func apply_divine_to_chains(power_id: String, country_id: int) -> Array:
	return chain_system.apply_divine_to_chains(power_id, country_id)

func _valid_definitions(definitions: Array, country: Country) -> Array:
	var valid: Array = []
	for definition in definitions:
		if runner.can_run(definition, country):
			valid.append(definition)
	return valid

func _weighted_pick(definitions: Array) -> Dictionary:
	var total = 0.0
	for definition in definitions:
		total += float(definition.get("weight", 1.0))

	var roll = randf() * max(0.001, total)
	var cursor = 0.0
	for definition in definitions:
		cursor += float(definition.get("weight", 1.0))
		if roll <= cursor:
			return definition

	return definitions.back()
