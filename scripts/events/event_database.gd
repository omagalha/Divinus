class_name EventDatabase
extends RefCounted

const STANDALONE_PATH = "res://data/events/standalone_events.json"
const GENERAL_CHAINS_PATH = "res://data/events/general_chains.json"
const POLITICAL_CHAINS_PATH = "res://data/events/political_chains.json"

var standalone_events: Array = []
var general_chains: Array = []
var political_chains: Array = []

func load_all() -> void:
	standalone_events = _load_json_array(STANDALONE_PATH)
	general_chains = _load_json_array(GENERAL_CHAINS_PATH)
	political_chains = _load_json_array(POLITICAL_CHAINS_PATH)

func all_chains() -> Array:
	var chains: Array = []
	chains.append_array(general_chains)
	chains.append_array(political_chains)
	return chains

func _load_json_array(path: String) -> Array:
	if not FileAccess.file_exists(path):
		push_warning("Event data not found: " + path)
		return []

	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_warning("Could not open event data: " + path)
		return []

	var text = file.get_as_text()
	file.close()

	var json = JSON.new()
	var error = json.parse(text)
	if error != OK:
		push_warning("Invalid JSON in " + path + ": " + json.get_error_message())
		return []

	var data = json.get_data()
	if data is Array:
		return data

	push_warning("Event data must be an array: " + path)
	return []
