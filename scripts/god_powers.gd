class_name GodPowers
extends RefCounted

# ─────────────────────────────────────────────
#  Catálogo de poderes divinos
#  Cada poder tem: id, nome, descrição, custo, ícone
# ─────────────────────────────────────────────

const POWERS = [
	{
		"id": "bless",
		"name": "Abençoar",
		"desc": "Aumenta economia e estabilidade de um país.",
		"cost": 2,
		"icon": "✨",
		"category": "positive"
	},
	{
		"id": "economic_crisis",
		"name": "Crise Econômica",
		"desc": "Colapsa a economia de um país instantaneamente.",
		"cost": 2,
		"icon": "📉",
		"category": "negative"
	},
	{
		"id": "tech_boost",
		"name": "Iluminação",
		"desc": "Acelera tecnologia em 20 pontos.",
		"cost": 3,
		"icon": "🔬",
		"category": "positive"
	},
	{
		"id": "natural_disaster",
		"name": "Desastre Natural",
		"desc": "Terremoto/inundação devasta população e economia.",
		"cost": 2,
		"icon": "🌋",
		"category": "negative"
	},
	{
		"id": "force_peace",
		"name": "Paz Divina",
		"desc": "Encerra todos os conflitos de um país.",
		"cost": 3,
		"icon": "☮️",
		"category": "positive"
	},
	{
		"id": "spread_ideology",
		"name": "Nova Ideologia",
		"desc": "Muda aleatoriamente a ideologia de um país.",
		"cost": 2,
		"icon": "📣",
		"category": "neutral"
	},
	{
		"id": "regress",
		"name": "Regressão",
		"desc": "Faz o país regredir uma era civilizatória.",
		"cost": 4,
		"icon": "⏪",
		"category": "negative"
	},
	{
		"id": "prophecy",
		"name": "Profecia",
		"desc": "Revela as intenções secretas do líder com detalhes proféticos.",
		"cost": 2,
		"icon": "🔮",
		"category": "neutral"
	},
	{
		"id": "sacred_treaty",
		"name": "Tratado Sagrado",
		"desc": "Força reconciliação com o maior rival do país. Pode forjar aliança.",
		"cost": 4,
		"icon": "📜",
		"category": "positive"
	},
]

# ─────────────────────────────────────────────
#  Retorna o custo de um poder por ID
# ─────────────────────────────────────────────
static func get_cost(power_id: String) -> int:
	for power in POWERS:
		if power["id"] == power_id:
			return power["cost"]
	return 999  # poder inválido = caro demais

# ─────────────────────────────────────────────
#  Retorna todos os poderes disponíveis
# ─────────────────────────────────────────────
static func get_all() -> Array:
	return POWERS

# ─────────────────────────────────────────────
#  Retorna poderes por categoria
# ─────────────────────────────────────────────
static func get_by_category(category: String) -> Array:
	return POWERS.filter(func(p): return p["category"] == category)

static func get_by_id(power_id: String) -> Dictionary:
	for p in POWERS:
		if p["id"] == power_id:
			return p
	return {}

# Retorna os efeitos previstos sem aplicá-los
# Chaves: "economy", "stability", "technology", "military",
#         "population_pct" (%), "war_cleared", "ideology_change", "era_regress"
static func get_preview(power_id: String) -> Dictionary:
	match power_id:
		"bless":
			return {"economy": 15, "stability": 10}
		"economic_crisis":
			return {"economy": -25, "stability": -15, "military": -12,
					"relation_hint": "IA ficará menos agressiva (aggression −15)"}
		"tech_boost":
			return {"technology": 20}
		"natural_disaster":
			return {"population_pct": -15, "stability": -20, "economy": -15}
		"force_peace":
			return {"war_cleared": true, "stability": 20,
					"relation_hint": "Relações com ex-inimigos +25"}
		"spread_ideology":
			return {"ideology_change": true, "stability": -10,
					"relation_hint": "Alianças com ideologias diferentes serão quebradas"}
		"regress":
			return {"era_regress": true, "technology": -20,
					"relation_hint": "Países vizinhos ficarão hostis (relações −12 a −22)"}
		"prophecy":
			return {"relation_hint": "Revela intenções do líder em detalhes. Sem efeito nos stats."}
		"sacred_treaty":
			return {"relation_hint": "Reconcilia o maior rival ou inimigo (+45 a +62 relações). Pode forjar aliança."}
	return {}
