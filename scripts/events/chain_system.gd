class_name ChainSystem
extends RefCounted

var active_chains: Array = []
var runner: EventRunner

func setup(event_runner: EventRunner) -> void:
	runner = event_runner

func process_active(year: int, countries: Array) -> Array:
	var triggered: Array = []
	var completed: Array = []

	for chain in active_chains:
		chain["turns_left"] = int(chain.get("turns_left", 0)) - 1
		if int(chain["turns_left"]) > 0:
			continue

		var country = _find_country(countries, int(chain["country_id"]))
		if not country:
			completed.append(chain)
			continue

		# Resolve ending phase — fires 1 turn after last base step
		if chain.get("_resolve_ending", false):
			var ending = _pick_ending(chain.get("endings", []), country, int(chain.get("pressure", 0)))
			if not ending.is_empty():
				triggered.append(runner.run_event(ending, country, year, countries))
			completed.append(chain)
			continue

		var steps: Array = chain["steps"]
		var step_index = int(chain["step_index"])
		if step_index >= steps.size():
			completed.append(chain)
			continue

		var step: Dictionary = steps[step_index]
		triggered.append(runner.run_event(step, country, year, countries))

		chain["pressure"] = clampi(int(chain.get("pressure", 0)) + int(step.get("pressure_delta", 0)), 0, 100)

		step_index += 1
		if step_index >= steps.size():
			if chain.has("endings"):
				chain["step_index"] = step_index
				chain["turns_left"] = 1
				chain["_resolve_ending"] = true
			else:
				completed.append(chain)
		else:
			chain["step_index"] = step_index
			chain["turns_left"] = int(steps[step_index].get("delay", 1))

	for chain in completed:
		active_chains.erase(chain)

	return triggered

func try_start_chain(chain_def: Dictionary, country: Country, year: int, countries: Array = []) -> Dictionary:
	if _is_chain_active(chain_def.get("id", ""), country.id):
		return {}
	if not runner.can_run(chain_def, country):
		return {}

	var steps: Array = chain_def.get("steps", [])
	if steps.is_empty():
		return {}

	var first_event = runner.run_event(steps[0], country, year, countries)
	if steps.size() == 1:
		return first_event

	var chain_entry: Dictionary = {
		"id": chain_def.get("id", "chain"),
		"title": chain_def.get("title", "Cadeia"),
		"country_id": country.id,
		"steps": steps,
		"step_index": 1,
		"turns_left": int(steps[1].get("delay", 1)) if steps.size() > 1 else 0,
		"pressure": int(steps[0].get("pressure_delta", 0)),
	}
	if chain_def.has("endings"):
		chain_entry["endings"] = chain_def["endings"]
	active_chains.append(chain_entry)

	return first_event

# Applies a divine power's pressure effect to any active chains for the given country
func apply_divine_to_chains(power_id: String, country_id: int) -> Array:
	var news: Array = []
	for chain in active_chains:
		if int(chain.get("country_id", -1)) != country_id:
			continue
		if chain.get("_resolve_ending", false):
			continue
		var delta = 0
		match power_id:
			"bless":           delta = -15
			"force_peace":     delta = -20
			"economic_crisis": delta = 20
			"natural_disaster": delta = 10
		if delta == 0:
			continue
		var old_p = int(chain.get("pressure", 0))
		chain["pressure"] = clampi(old_p + delta, 0, 100)
		var new_p = int(chain["pressure"])
		var title = str(chain.get("title", "Cadeia"))
		if delta < 0:
			news.append({
				"type": "divine_consequence", "severity": "medium",
				"desc": "🌟 Intervenção divina alivia a tensão em \"" + title + "\". Pressão: " + str(new_p) + ".",
			})
		else:
			news.append({
				"type": "divine_consequence", "severity": "medium",
				"desc": "⚡ Intervenção divina intensifica a tensão em \"" + title + "\". Pressão: " + str(new_p) + ".",
			})
	return news

func _pick_ending(endings: Array, country: Country, pressure: int) -> Dictionary:
	var leader = country.get_leader()
	var dominant_trait = leader.primary_trait if leader else ""

	# First pass: match both pressure condition and leader trait
	for ending in endings:
		var cond: Dictionary = ending.get("condition", {})
		if cond.has("leader_trait") and str(cond["leader_trait"]) != dominant_trait:
			continue
		if cond.has("min_pressure") and pressure < int(cond["min_pressure"]):
			continue
		if cond.has("max_pressure") and pressure > int(cond["max_pressure"]):
			continue
		return ending

	# Second pass: only pressure conditions (trait-agnostic endings)
	for ending in endings:
		var cond: Dictionary = ending.get("condition", {})
		if cond.has("leader_trait"):
			continue
		if cond.has("min_pressure") and pressure < int(cond["min_pressure"]):
			continue
		if cond.has("max_pressure") and pressure > int(cond["max_pressure"]):
			continue
		return ending

	return endings.back() if not endings.is_empty() else {}

func _is_chain_active(chain_id: String, country_id: int) -> bool:
	for chain in active_chains:
		if chain.get("id", "") == chain_id and int(chain.get("country_id", -1)) == country_id:
			return true
	return false

func _find_country(countries: Array, country_id: int) -> Country:
	for country in countries:
		if country.id == country_id:
			return country
	return null
