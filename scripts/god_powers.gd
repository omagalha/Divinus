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
