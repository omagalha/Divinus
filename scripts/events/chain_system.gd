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

		var steps: Array = chain["steps"]
		var step_index = int(chain["step_index"])
		if step_index >= steps.size():
			completed.append(chain)
			continue

		var step: Dictionary = steps[step_index]
		triggered.append(runner.run_event(step, country, year, countries))

		step_index += 1
		if step_index >= steps.size():
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

	active_chains.append({
		"id": chain_def.get("id", "chain"),
		"title": chain_def.get("title", "Cadeia"),
		"country_id": country.id,
		"steps": steps,
		"step_index": 1,
		"turns_left": int(steps[1].get("delay", 1)) if steps.size() > 1 else 0,
	})

	return first_event

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
