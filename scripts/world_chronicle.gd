class_name WorldChronicle
extends RefCounted

# { decade_start: [{ year, type, severity, desc, countries }] }
var _decades: Dictionary = {}

# { "minId:maxId": { wars, alliances, id_a, id_b } }
var _pairs: Dictionary = {}

# { country_id: { wars, alliances, eras, crises } }
var _stats: Dictionary = {}

# { decade_start: String }
var _decade_names: Dictionary = {}

const TRACKED_TYPES = [
	"leader_declares_war", "war_declared", "era_advance",
	"divine_objective_completed", "divine_objective_failed",
	"leader_alliance", "leader_break_alliance",
	"divine_consequence", "sacred_treaty",
]

func record_event(event: Dictionary, year: int) -> void:
	var tp  = str(event.get("type", ""))
	var sev = str(event.get("severity", "low"))
	if not (tp in TRACKED_TYPES or sev in ["critical", "high"]):
		return

	var decade = int(year / 10) * 10
	if not _decades.has(decade):
		_decades[decade] = []
	_decades[decade].append({
		"year": year, "type": tp, "severity": sev,
		"desc": str(event.get("desc", "")),
		"countries": event.get("countries", []).duplicate(),
	})

	var countries: Array = event.get("countries", [])

	if countries.size() >= 2:
		var id_a = int(countries[0])
		var id_b = int(countries[1])
		var key = str(mini(id_a, id_b)) + ":" + str(maxi(id_a, id_b))
		if not _pairs.has(key):
			_pairs[key] = {"wars": 0, "alliances": 0, "id_a": id_a, "id_b": id_b}
		if tp in ["leader_declares_war", "war_declared"]:
			_pairs[key]["wars"] = int(_pairs[key]["wars"]) + 1
		elif tp in ["leader_alliance", "sacred_treaty"]:
			_pairs[key]["alliances"] = int(_pairs[key]["alliances"]) + 1

	for cid_raw in countries:
		var cid = int(cid_raw)
		if cid < 0:
			continue
		if not _stats.has(cid):
			_stats[cid] = {"wars": 0, "alliances": 0, "eras": 0, "crises": 0}
		match tp:
			"leader_declares_war", "war_declared":
				_stats[cid]["wars"] = int(_stats[cid]["wars"]) + 1
			"leader_alliance", "sacred_treaty":
				_stats[cid]["alliances"] = int(_stats[cid]["alliances"]) + 1
			"era_advance":
				_stats[cid]["eras"] = int(_stats[cid]["eras"]) + 1
		if sev in ["high", "critical"] and tp not in ["era_advance", "leader_alliance", "divine_objective_completed"]:
			_stats[cid]["crises"] = int(_stats[cid]["crises"]) + 1

# Pares com >= 2 guerras
func get_rivalries() -> Array:
	var result: Array = []
	for key in _pairs:
		var pair = _pairs[key]
		if int(pair.get("wars", 0)) >= 2:
			result.append({
				"id_a": pair["id_a"], "id_b": pair["id_b"],
				"wars": pair["wars"], "alliances": pair.get("alliances", 0),
			})
	result.sort_custom(func(a, b): return int(a["wars"]) > int(b["wars"]))
	return result

# Pares com >= 2 alianças e zero guerras
func get_pacts() -> Array:
	var result: Array = []
	for key in _pairs:
		var pair = _pairs[key]
		if int(pair.get("alliances", 0)) >= 2 and int(pair.get("wars", 0)) == 0:
			result.append({
				"id_a": pair["id_a"], "id_b": pair["id_b"],
				"alliances": pair["alliances"],
			})
	result.sort_custom(func(a, b): return int(a["alliances"]) > int(b["alliances"]))
	return result

func get_reputation(country_id: int) -> String:
	var s = _stats.get(country_id, {})
	var wars      = int(s.get("wars", 0))
	var alliances = int(s.get("alliances", 0))
	var eras      = int(s.get("eras", 0))
	var crises    = int(s.get("crises", 0))
	if wars >= 4:                        return "Nação expansionista"
	if wars >= 2 and alliances == 0:     return "Estado belicoso"
	if alliances >= 3 and wars == 0:     return "Bastião diplomático"
	if alliances >= 2 and wars <= 1:     return "Potência pacífica"
	if eras >= 2:                        return "Potência tecnológica"
	if crises >= 3 and wars == 0:        return "Estado instável"
	if wars >= 2 and alliances >= 2:     return "Força regional"
	return ""

func get_decade_name(decade: int) -> String:
	if _decade_names.has(decade):
		return _decade_names[decade]
	if not _decades.has(decade):
		return ""
	var events = _decades[decade] as Array
	var wars      = events.filter(func(e): return str(e.get("type","")) in ["leader_declares_war","war_declared"]).size()
	var eras      = events.filter(func(e): return str(e.get("type","")) == "era_advance").size()
	var alliances = events.filter(func(e): return str(e.get("type","")) in ["leader_alliance","sacred_treaty"]).size()
	var divine    = events.filter(func(e): return str(e.get("type","")) == "divine_consequence").size()
	var collapses = events.filter(func(e): return str(e.get("severity","")) == "critical" and str(e.get("type","")) not in ["era_advance","leader_declares_war"]).size()

	var name: String
	if wars >= 4:                       name = "A Década das Guerras"
	elif wars >= 2 and collapses >= 1:  name = "A Década das Cinzas"
	elif eras >= 2:                     name = "A Década do Progresso"
	elif eras >= 1 and wars == 0:       name = "A Era da Prosperidade"
	elif alliances >= 3:                name = "A Era dos Tratados"
	elif divine >= 2:                   name = "A Era dos Milagres"
	elif wars == 0:                     name = "Uma Época de Paz"
	else:                               name = "A Época do Silêncio"

	_decade_names[decade] = name
	return name

# Décadas com eventos, ordenadas do mais recente ao mais antigo
func get_decades() -> Array:
	var keys = _decades.keys()
	keys.sort()
	keys.reverse()
	return keys

# Bullets resumidos da década para exibição
func get_decade_bullets(decade: int) -> Array:
	if not _decades.has(decade):
		return []
	var events = _decades[decade] as Array
	var wars      = events.filter(func(e): return str(e.get("type","")) in ["leader_declares_war","war_declared"]).size()
	var eras      = events.filter(func(e): return str(e.get("type","")) == "era_advance").size()
	var alliances = events.filter(func(e): return str(e.get("type","")) in ["leader_alliance","sacred_treaty"]).size()
	var obj       = events.filter(func(e): return str(e.get("type","")) in ["divine_objective_completed","divine_objective_failed"]).size()

	var lines: Array = []
	if wars > 0:      lines.append(str(wars) + " guerra(s) declarada(s)")
	if eras > 0:      lines.append(str(eras) + " avanço(s) de era")
	if alliances > 0: lines.append(str(alliances) + " aliança(s) formada(s)")
	if obj > 0:       lines.append(str(obj) + " objetivo(s) divino(s)")
	if lines.is_empty():
		lines.append("Uma época tranquila.")
	return lines
