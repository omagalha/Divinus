class_name Country
extends RefCounted

const CountryLeaderScript = preload("res://scripts/leader.gd")

# ─────────────────────────────────────────────
#  Dados principais do país
# ─────────────────────────────────────────────
var id: int
var country_name: String
var population: float       # em milhões
var economy: float          # 0-100
var technology: float       # 0-100
var military: float         # 0-100
var stability: float        # 0-100
var faith: float            # 0-100
var aggression: float       # 0-100
var ideology: String        # "democracy", "autocracy", "theocracy", "anarchy"
var relations: Dictionary   # { country_id: valor -100..100 }
var at_war_with: Array      # [ country_id, ... ]
var allies: Array           # [ country_id, ... ]
var era: int                # 0=tribal, 1=ancient, 2=medieval, 3=modern, 4=future
var leader
var event_history: Array = []
var war_history: Array = []
var trend: Dictionary = {}
var visual_stage: int = 0
var city_level: int = 0
var pollution: float = 0.0
var energy_type: String = "organic"
var culture_style: String = "balanced"
var _previous_stats: Dictionary = {}

func get_leader():
	return leader

# ─────────────────────────────────────────────
#  Inicializa a partir de um dicionário JSON
# ─────────────────────────────────────────────
func setup(data: Dictionary) -> void:
	id           = data.get("id", 0)
	country_name = data.get("name", "Unknown")
	population   = data.get("population", 10.0)
	economy      = data.get("economy", 50.0)
	technology   = data.get("technology", 30.0)
	military     = data.get("military", 30.0)
	stability    = data.get("stability", 60.0)
	faith        = data.get("faith", 35.0)
	aggression   = data.get("aggression", 35.0)
	ideology     = data.get("ideology", "democracy")
	era          = data.get("era", 0)
	relations    = data.get("relations", {})
	at_war_with  = []
	allies       = data.get("allies", [])
	leader       = CountryLeaderScript.new()
	leader.setup_for_country(country_name, ideology, id)
	_store_previous_stats()
	trend = _empty_trend()
	update_visual_state()

func begin_turn_snapshot() -> void:
	_store_previous_stats()

func update_trends() -> void:
	trend = {
		"population": snappedf(population - _previous_stats.get("population", population), 0.1),
		"economy": snappedf(economy - _previous_stats.get("economy", economy), 0.1),
		"technology": snappedf(technology - _previous_stats.get("technology", technology), 0.1),
		"military": snappedf(military - _previous_stats.get("military", military), 0.1),
		"stability": snappedf(stability - _previous_stats.get("stability", stability), 0.1),
	}
	update_visual_state()

func update_visual_state() -> void:
	visual_stage = era
	city_level = clampi(int((population * 0.45 + economy * 0.35 + technology * 0.20) / 18.0), 0, 10)
	pollution = clampf((economy * 0.45 + technology * 0.35 + military * 0.20) - stability * 0.55, 0.0, 100.0)

	if era <= 1:
		energy_type = "organic"
	elif technology < 45:
		energy_type = "wood_coal"
	elif technology < 75:
		energy_type = "industrial"
	else:
		energy_type = "clean" if stability > 55 else "dirty_hightech"

	match ideology:
		"theocracy":
			culture_style = "sacred"
		"autocracy":
			culture_style = "monumental"
		"anarchy":
			culture_style = "chaotic"
		_:
			culture_style = "balanced"

func record_event(year: int, event: Dictionary) -> void:
	var entry = {
		"year": year,
		"type": event.get("type", "event"),
		"desc": event.get("desc", ""),
		"severity": event.get("severity", "low"),
	}
	event_history.push_front(entry)
	if event_history.size() > 10:
		event_history.pop_back()

	if str(entry["type"]).begins_with("war") or entry["type"] in ["peace", "alliance_call"]:
		war_history.push_front(entry)
		if war_history.size() > 8:
			war_history.pop_back()

func _store_previous_stats() -> void:
	_previous_stats = {
		"population": population,
		"economy": economy,
		"technology": technology,
		"military": military,
		"stability": stability,
		"faith": faith,
		"aggression": aggression,
	}

func _empty_trend() -> Dictionary:
	return {
		"population": 0.0,
		"economy": 0.0,
		"technology": 0.0,
		"military": 0.0,
		"stability": 0.0,
	}

# ─────────────────────────────────────────────
#  Simula um turno (1 ano) para este país
# ─────────────────────────────────────────────
func simulate_turn() -> Array:
	var events_triggered: Array = []

	# Crescimento populacional (base + bônus de economia)
	var growth_rate = 0.01 + (economy / 100.0) * 0.02
	if stability < 30:
		growth_rate -= 0.015   # instabilidade reduz crescimento
	population = max(0.1, population + population * growth_rate)

	# Economia influencia tecnologia
	if economy > 70:
		technology = min(100, technology + randf_range(0.5, 1.5) + leader.ambition * 1.2)

	# Líderes puxam a sociedade em direções próprias.
	if leader.aggression > 0.12:
		military = min(100, military + leader.aggression * 1.5)
		stability = max(0, stability - leader.aggression * 0.7)
	if leader.diplomacy > 0.12:
		stability = min(100, stability + leader.diplomacy * 0.8)
	if leader.isolationism > 0.12 and economy > 35:
		economy = max(0, economy - leader.isolationism * 0.4)

	# Tecnologia alta pode criar instabilidade (desemprego, revoltas)
	if technology > 80 and stability > 40:
		stability -= randf_range(0.0, 2.0)
		if stability < 40:
			var revolts = [
				"🔥 Máquinas tomam os empregos — trabalhadores de " + country_name + " incendeiam fábricas. " + leader.display_name() + " chama o exército.",
				"🔥 Avanço tecnológico em " + country_name + " devasta classes trabalhadoras. Revoltas explodem — " + leader.display_name() + " perde o controle das ruas.",
				"🔥 Desemprego em massa após automação total em " + country_name + ". O povo exige resposta — " + leader.display_name() + " não tem uma.",
			]
			events_triggered.append({
				"type": "revolt",
				"country": country_name,
				"countries": [id],
				"desc": revolts[randi() % revolts.size()],
				"severity": "high"
			})

	# Economia decai se instabilidade for alta
	if stability < 40:
		economy = max(0, economy - randf_range(1.0, 3.0))

	# Estabilidade se recupera lentamente se economia for boa
	if economy > 60 and stability < 80:
		stability = min(100, stability + randf_range(0.2, 0.8))

	# Militar consome economia
	economy = max(0, economy - (military / 100.0) * 0.5)

	# Clamp de todos os valores
	economy    = clampf(economy, 0.0, 100.0)
	technology = clampf(technology, 0.0, 100.0)
	military   = clampf(military, 0.0, 100.0)
	stability  = clampf(stability, 0.0, 100.0)

	# Verifica avanço de era
	var new_era = _calculate_era()
	if new_era > era:
		era = new_era
		var era_messages = {
			1: [
				"🌅 " + country_name + " desperta da barbárie: primeiras cidades surgem, escrita é inventada. A " + get_era_name() + " começa.",
				"🌅 O povo de " + country_name + " ergue monumentos e codifica leis. O mundo nunca mais será o mesmo — a " + get_era_name() + " chegou.",
			],
			2: [
				"🏰 Reinos se formam em " + country_name + ". Castelos, cavaleiros e cruzadas definem a " + get_era_name() + " que se inicia.",
				"🏰 " + country_name + " entra na " + get_era_name() + ": feudos, religiões e espadas moldam o destino da nação.",
			],
			3: [
				"🏭 A revolução industrial transforma " + country_name + " para sempre. Fábricas, ferrovias, armas modernas — a " + get_era_name() + " chegou.",
				"🏭 " + country_name + " abraça a modernidade: democracia, indústria, ciência. " + leader.display_name() + " lidera a nação para a " + get_era_name() + ".",
			],
			4: [
				"🚀 " + country_name + " atinge o futuro antes de todos. Inteligência artificial, colonização espacial — a " + get_era_name() + " é agora.",
				"🚀 Singularidade em " + country_name + ": humanos e máquinas se fundem. " + leader.display_name() + " anuncia a chegada da " + get_era_name() + ".",
			],
		}
		var msgs = era_messages.get(new_era, ["✨ " + country_name + " avança para a " + get_era_name() + "."])
		events_triggered.append({
			"type": "era_advance",
			"country": country_name,
			"countries": [id],
			"desc": msgs[randi() % msgs.size()],
			"severity": "critical"
		})

	return events_triggered

# ─────────────────────────────────────────────
#  Calcula a era com base nos atributos
# ─────────────────────────────────────────────
func _calculate_era() -> int:
	var score = (technology * 0.5) + (economy * 0.3) + (population * 0.2)
	if score >= 85:   return 4  # Futuro
	if score >= 65:   return 3  # Moderno
	if score >= 40:   return 2  # Medieval
	if score >= 20:   return 1  # Antigo
	return 0                    # Tribal

func get_era_name() -> String:
	match era:
		0: return "Era Tribal"
		1: return "Era Antiga"
		2: return "Era Medieval"
		3: return "Era Moderna"
		4: return "Era Futura"
	return "Desconhecida"

# ─────────────────────────────────────────────
#  Aplica um poder divino diretamente ao país
# ─────────────────────────────────────────────
func apply_power(power_id: String) -> String:
	match power_id:
		"bless":
			economy   = min(100, economy + 15)
			stability = min(100, stability + 10)
			return "✨ " + country_name + " foi abençoado. Economia e estabilidade crescem."
		"economic_crisis":
			economy    = max(0, economy - 25)
			stability  = max(0, stability - 15)
			military   = max(0, military - 12)
			aggression = max(0, aggression - 15)
			return "📉 Crise econômica instalada em " + country_name + ". Exército perde financiamento."
		"tech_boost":
			technology = min(100, technology + 20)
			return "🔬 Iluminação tecnológica em " + country_name + "."
		"natural_disaster":
			population = max(0.1, population - population * 0.15)
			stability  = max(0, stability - 20)
			economy    = max(0, economy - 15)
			return "🌋 Desastre natural atinge " + country_name + ". Caos se instala."
		"force_peace":
			at_war_with.clear()
			stability = min(100, stability + 20)
			return "☮️ Paz divina forçada em " + country_name + "."
		"spread_ideology":
			var ideologies = ["democracy", "autocracy", "theocracy"]
			ideology = ideologies[randi() % ideologies.size()]
			stability = max(0, stability - 10)
			return "📣 Nova ideologia se espalha em " + country_name + ": " + ideology + "."
		"regress":
			era        = max(0, era - 1)
			technology = max(0, technology - 20)
			return "⏪ " + country_name + " regrediu uma era."
	return "Poder desconhecido."

# ─────────────────────────────────────────────
#  Retorna snapshot para salvar/exibir
# ─────────────────────────────────────────────
func to_dict() -> Dictionary:
	return {
		"id": id,
		"name": country_name,
		"population": snappedf(population, 0.1),
		"economy": snappedf(economy, 0.1),
		"technology": snappedf(technology, 0.1),
		"military": snappedf(military, 0.1),
		"stability": snappedf(stability, 0.1),
		"faith": snappedf(faith, 0.1),
		"aggression": snappedf(aggression, 0.1),
		"ideology": ideology,
		"era": era,
		"era_name": get_era_name(),
		"at_war_with": at_war_with,
		"allies": allies,
		"relations": relations,
		"leader": leader.to_dict(),
		"trend": trend,
		"event_history": event_history,
		"war_history": war_history,
		"visual": {
			"stage": visual_stage,
			"city_level": city_level,
			"pollution": snappedf(pollution, 0.1),
			"energy_type": energy_type,
			"culture_style": culture_style,
		},
	}
