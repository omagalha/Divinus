
# 🌍 DIVINUS — Guia de Início Rápido

Você é uma entidade acima da humanidade. Cada decisão sua altera civilizações.

---

## 📦 Estrutura do Projeto

```
Divinus/
├── scenes/
│   ├── MainMenu.tscn       ← crie manualmente no Godot
│   ├── WorldMap.tscn       ← crie manualmente no Godot
│   └── NewsPanel.tscn      ← crie manualmente no Godot
├── scripts/
│   ├── country.gd          ✅ pronto
│   ├── world_simulator.gd  ✅ pronto
│   ├── event_system.gd     ✅ pronto
│   ├── war_system.gd       ✅ pronto
│   └── god_powers.gd       ✅ pronto
└── data/
	└── countries.json      ✅ pronto (10 países fictícios)
```

---

## 🚀 Como configurar no Godot

### Passo 1 — Instalar Godot
1. Acesse: https://godotengine.org/download
2. Baixe **Godot 4.x (Stable)** para Windows
3. É um `.exe` portátil — sem instalação

### Passo 2 — Criar o projeto
1. Abra o Godot
2. Clique em **"New Project"**
3. Nomeie como **Divinus**
4. Escolha uma pasta e clique em **"Create & Edit"**

### Passo 3 — Copiar os arquivos
1. Copie a pasta `scripts/` inteira para dentro do projeto
2. Copie a pasta `data/` inteira para dentro do projeto
3. Os arquivos vão aparecer na aba **FileSystem** do Godot

### Passo 4 — Criar a cena principal (WorldMap)
1. Clique em **"+ Add Scene"**
2. Escolha **Node** como raiz → renomeie para `WorldMap`
3. Clique com botão direito no nó → **"Attach Script"**
4. Crie o script `world_map.gd` com este conteúdo:

```gdscript
extends Node

@onready var simulator = WorldSimulator.new()

func _ready():
	add_child(simulator)
	simulator.turn_completed.connect(_on_turn_completed)
	simulator.game_over.connect(_on_game_over)

func _on_button_next_turn():
	simulator.advance_turn()

func _on_turn_completed(year, news):
	print("Ano: ", year)
	for n in news:
		print(n["desc"])

func _on_game_over(ending):
	print("FIM DE JOGO: ", ending)

func _input(event):
	# Pressione ESPAÇO para avançar um ano (teste rápido)
	if event.is_action_pressed("ui_accept"):
		_on_button_next_turn()
```

5. Pressione **F5** para testar → veja o Output no Godot

---

## 🎮 O que já está funcionando

| Sistema | Status |
|---|---|
| 10 países com atributos | ✅ |
| Simulação por turno | ✅ |
| Guerras automáticas | ✅ |
| Acordos de paz | ✅ |
| Relações diplomáticas | ✅ |
| Eventos aleatórios (pandemia, boom, revolução...) | ✅ |
| Poderes divinos (7 poderes) | ✅ |
| Avanço de eras | ✅ |
| 3 finais de jogo | ✅ |

---

## ⚡ Poderes Divinos disponíveis

| Poder | Custo | Efeito |
|---|---|---|
| ✨ Abençoar | 2 | +Economia +Estabilidade |
| 📉 Crise Econômica | 2 | -Economia -Estabilidade |
| 🔬 Iluminação | 3 | +Tecnologia |
| 🌋 Desastre Natural | 2 | -População -Estabilidade |
| ☮️ Paz Divina | 3 | Encerra guerras |
| 📣 Nova Ideologia | 2 | Muda regime político |
| ⏪ Regressão | 4 | Regride 1 era |

Você ganha **3 pontos divinos** por turno.

---

## 🏁 Condições de fim de jogo

- 🌟 **Utopia**: todos os países com tecnologia > 85 e estabilidade > 75
- 💀 **Colapso**: todos os países com estabilidade < 15
- ⚔️ **Guerra Mundial**: 60%+ dos países em conflito simultâneo
- ⏳ **Fim da Era**: ano 2200 atingido

---

## 🔜 Próximos passos (V0.2)

- [ ] Interface visual com mapa de países
- [ ] Painel de notícias com feed estilo jornal
- [ ] Líderes com personalidade
- [ ] Mapa procedural
- [ ] Efeitos sonoros
- [ ] Exportar para Android

---

## 🌍 Como montar o Globo 3D

### Passo 1 — Criar a cena Globe3D.tscn

1. No Godot, clique em **"+ Add Scene"**
2. Escolha **Node3D** como raiz
3. Renomeie para `Globe3D`
4. Salve como `res://scenes/Globe3D.tscn`

### Passo 2 — Adicionar a câmera

1. Clique com botão direito em `Globe3D` → **"Add Child Node"**
2. Adicione um nó **Camera3D**
3. No Inspetor, defina a posição da câmera:
   - Position: `X=0, Y=0, Z=4`
4. Marque a câmera como **"Current"** no Inspetor

### Passo 3 — Anexar o script

1. Clique com botão direito em `Globe3D` → **"Add Script"**
2. Seleciona o arquivo `scripts/globe_3d.gd`

### Passo 4 — Integrar com o WorldMap

1. Abra a cena `WorldMap.tscn`
2. Clique com botão direito no nó `WorldMap` → **"Add Child Node"**
3. Adicione um nó **Node** simples
4. Renomeie para `GlobeIntegration`
5. Attach o script `scripts/globe_integration.gd`

### Passo 5 — Rodar

Pressione **F5**. O globo vai aparecer, girar sozinho e os países vão pulsar.

### Controles do Globo

| Ação | Controle |
|---|---|
| Girar o planeta | Arrastar com mouse |
| Zoom | Scroll do mouse |
| Selecionar país | Clique na bolinha |
| Guerras | Linha vermelha automática |
| Pulso por era | Cor + tamanho da bolinha |
=======
# Divinus
Simulador procedural de civilizações onde a humanidade evolui de tribos primitivas até sociedades futuristas sob influência divina.
