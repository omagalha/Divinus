class_name CountryLeader
extends RefCounted

const TRAITS = ["aggressive", "diplomatic", "isolationist", "ambitious"]

const FIRST_NAMES = [
	"Kael", "Seren", "Varyn", "Liora", "Darian", "Nyra", "Orvik", "Maelis",
	"Thalen", "Asha", "Rovan", "Elyra", "Korin", "Selka", "Marek", "Ivara"
]

const TITLES = {
	"democracy": ["Presidente", "Chanceler", "Primeira-Ministra"],
	"autocracy": ["Ditador", "Soberano", "General"],
	"theocracy": ["Profeta", "Hierarca", "Oráculo"],
	"anarchy": ["Porta-voz", "Senhor de Guerra", "Agitador"]
}

var leader_name: String
var title: String
var primary_trait: String
var secondary_trait: String
var aggression: float
var diplomacy: float
var isolationism: float
var ambition: float

func setup_for_country(country_name: String, ideology: String, country_id: int) -> void:
	var name_index = abs((country_id * 7 + country_name.length()) % FIRST_NAMES.size())
	var title_options = TITLES.get(ideology, TITLES["democracy"])

	leader_name = FIRST_NAMES[name_index]
	title = title_options[abs((country_id * 3) % title_options.size())]
	primary_trait = TRAITS[abs((country_id + country_name.length()) % TRAITS.size())]
	secondary_trait = TRAITS[abs((country_id * 2 + country_name.length()) % TRAITS.size())]
	if secondary_trait == primary_trait:
		secondary_trait = TRAITS[(TRAITS.find(primary_trait) + 1) % TRAITS.size()]

	_recalculate_stats()

func _recalculate_stats() -> void:
	aggression = 0.0
	diplomacy = 0.0
	isolationism = 0.0
	ambition = 0.0
	_apply_trait(primary_trait, 1.0)
	_apply_trait(secondary_trait, 0.55)

func _apply_trait(trait_id: String, weight: float) -> void:
	match trait_id:
		"aggressive":
			aggression += 0.22 * weight
			diplomacy -= 0.08 * weight
		"diplomatic":
			diplomacy += 0.24 * weight
			aggression -= 0.06 * weight
		"isolationist":
			isolationism += 0.22 * weight
			diplomacy -= 0.05 * weight
		"ambitious":
			ambition += 0.22 * weight
			aggression += 0.07 * weight

func display_name() -> String:
	return title + " " + leader_name

func trait_label() -> String:
	return _trait_to_text(primary_trait) + ", " + _trait_to_text(secondary_trait)

func war_modifier() -> float:
	return aggression * 0.35 + ambition * 0.20 - diplomacy * 0.25 - isolationism * 0.20

func relation_modifier(other) -> float:
	var modifier = diplomacy * 0.9 - isolationism * 0.7 - aggression * 0.35
	if other:
		modifier += other.diplomacy * 0.45
		modifier -= other.aggression * 0.25
	return modifier

func peace_modifier(other) -> float:
	var modifier = diplomacy * 0.16 - aggression * 0.06
	if other:
		modifier += other.diplomacy * 0.10
		modifier -= other.ambition * 0.04
	return modifier

func _trait_to_text(trait_id: String) -> String:
	match trait_id:
		"aggressive": return "agressivo"
		"diplomatic": return "diplomático"
		"isolationist": return "isolacionista"
		"ambitious": return "ambicioso"
	return trait_id

func to_dict() -> Dictionary:
	return {
		"name": leader_name,
		"title": title,
		"display_name": display_name(),
		"primary_trait": primary_trait,
		"secondary_trait": secondary_trait,
		"trait_label": trait_label(),
		"aggression": snappedf(aggression, 0.01),
		"diplomacy": snappedf(diplomacy, 0.01),
		"isolationism": snappedf(isolationism, 0.01),
		"ambition": snappedf(ambition, 0.01),
	}
