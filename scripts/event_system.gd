class_name EventSystem
extends Node

const EventDatabaseScript = preload("res://scripts/events/event_database.gd")
const EventRunnerScript = preload("res://scripts/events/event_runner.gd")
const ChainSystemScript = preload("res://scripts/events/chain_system.gd")

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

	return triggered

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
