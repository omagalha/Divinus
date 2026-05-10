# DIVINUS — Contexto Completo do Projeto

## O que é o Divinus

Divinus é um jogo mobile (Android + iOS) desenvolvido em **Godot 4.x** onde o jogador é uma entidade divina que influencia civilizações ao longo da história da humanidade. O mundo evolui sozinho — o jogador não controla diretamente, apenas influencia.

A grande diferença dos outros jogos: **consequências emergentes**. Cada partida gera histórias únicas que os jogadores vão querer compartilhar ("no meu save o Brasil virou potência e os EUA colapsaram").

---

## Visão do jogo

**Loop principal:**
1. Jogador observa o mundo
2. Recebe eventos automáticos
3. Aplica poderes divinos
4. O mundo reage
5. Novos problemas surgem

**Progressão de eras:**
- Fase 1 — Origem: tribos, fogo, caça, agricultura
- Fase 2 — Civilizações: cidades, reis, religiões
- Fase 3 — Nações: países, fronteiras, diplomacia
- Fase 4 — Modernidade: indústria, tecnologia, IA, nuclear
- Fase 5 — Futuro: colonização espacial, utopia ou extinção

**Finais de jogo:**
- 🌟 Utopia Tecnológica
- 💀 Colapso Civilizacional
- ⚔️ Guerra Mundial
- ⏳ Fim da Era (ano 2200)

---

## Stack técnica

- **Engine:** Godot 4.x (GDScript)
- **Plataforma alvo:** Android + iOS (portrait, 1080x1920)
- **Desenvolvimento:** Windows PC, testar no PC primeiro
- **Versão atual:** v0.1 (MVP funcional)

---

## Estrutura de arquivos atual

```
Divinus/
├── project.godot              ← configurado para portrait 1080x1920, mobile renderer
├── .gitignore
├── README.md                  ← guia de setup completo
├── data/
│   └── countries.json         ← 10 países fictícios com atributos e relações
├── scripts/
│   ├── country.gd             ← classe Country: atributos, simulação por turno, poderes
│   ├── world_simulator.gd     ← motor central: avança turnos, gerencia países
│   ├── event_system.gd        ← 9 tipos de eventos aleatórios
│   ├── war_system.gd          ← guerras eclodem, causam dano, terminam em paz
│   ├── god_powers.gd          ← 7 poderes divinos com custos
│   ├── world_map.gd           ← UI desktop atual (layout horizontal)
│   ├── globe_3d.gd            ← globo 3D interativo (drag, zoom, marcadores)
│   └── globe_integration.gd   ← conecta Globe3D com WorldSimulator
└── scenes/
    ├── WorldMap.tscn           ← cena principal (já criada e funcionando)
    └── Globe3D.tscn            ← cena do globo (a ser montada)
```

---

## O que já funciona (testado)

- ✅ 10 países fictícios simulando por turno
- ✅ Economia, tecnologia, militar, estabilidade, população evoluindo
- ✅ Sistema de guerras automático (eclodem, causam baixas, terminam em paz)
- ✅ 9 eventos aleatórios: pandemia, revolução, boom, desastre, aliança, IA...
- ✅ 7 poderes divinos: Abençoar, Crise Econômica, Iluminação, Desastre Natural, Paz Divina, Nova Ideologia, Regressão
- ✅ Progressão de eras (Tribal → Antiga → Medieval → Moderna → Futura)
- ✅ 3 condições de fim de jogo
- ✅ UI desktop funcional com feed de notícias
- ✅ Scripts do globo 3D criados (ainda não montados na cena)

---

## Países atuais (fictícios)

| ID | Nome | Era Inicial | Ideologia | Destaques |
|---|---|---|---|---|
| 1 | Valdoria | Moderna | Democracia | Equilibrada |
| 2 | Kharuum | Medieval | Autocracia | Militar forte |
| 3 | Sylveth | Moderna | Democracia | Tecnologia máxima |
| 4 | Dorrakan | Moderna | Autocracia | Maior população |
| 5 | Aeloria | Medieval | Teocracia | Estável |
| 6 | Vrexmoor | Antiga | Anarquia | Caótica |
| 7 | Thessomar | Moderna | Democracia | Tecnologia alta |
| 8 | Korrath | Medieval | Autocracia | Grande população |
| 9 | Lunaris | Moderna | Democracia | Mais avançada |
| 10 | Zethara | Medieval | Teocracia | Instável |

---

## Poderes divinos

| Poder | Custo ⚡ | Efeito |
|---|---|---|
| ✨ Abençoar | 2 | +Economia +Estabilidade |
| 📉 Crise Econômica | 2 | -Economia -Estabilidade |
| 🔬 Iluminação | 3 | +Tecnologia +20 |
| 🌋 Desastre Natural | 2 | -População -Estabilidade |
| ☮️ Paz Divina | 3 | Encerra guerras do país |
| 📣 Nova Ideologia | 2 | Muda regime político |
| ⏪ Regressão | 4 | Regride 1 era |

Jogador ganha **3 pontos divinos por turno**.

---

## Cores por era (globo 3D)

- 🟤 Tribal: `#8b5e3c`
- 🟡 Antiga: `#d4a843`
- 🟢 Medieval: `#4a9a6a`
- 🔵 Moderna: `#3a7fd4`
- 🟣 Futura: `#b844e0`

---

## Próximos passos planejados

### Imediato
- [ ] Montar Globe3D.tscn no Godot (Node3D + Camera3D + globe_3d.gd)
- [ ] Integrar globo com WorldMap via globe_integration.gd
- [ ] Testar rotação, zoom e seleção de países no globo

### V0.2
- [ ] Sistema de líderes com personalidade (ego, agressividade, diplomacia)
- [ ] Notícias estilo jornal com animação de entrada
- [ ] Mapa procedural com geração aleatória de continentes
- [ ] Tela de início com opções de cenário

### V0.3
- [ ] Exportar APK para Android e testar no celular
- [ ] UI adaptada para toque (portrait mobile)
- [ ] Sistema de save/load

### Futuro
- [ ] Integrar IA real para líderes (negociam, mentem, fazem alianças)
- [ ] Multiplayer: mundos compartilhados
- [ ] Monetização: skins de mapas, timelines alternativas, assinatura premium

---

## Monetização planejada (sem pay-to-win)

- Skins de mapas (cyberpunk, apocalipse, medieval)
- Timelines alternativas (e se Roma nunca caiu?)
- Pacotes históricos
- Assinatura premium
- Poderes especiais cosméticos

---

## Potencial viral

O jogo cria histórias emergentes únicas que os jogadores compartilham:
- "Na minha partida uma tribo do sul dominou o mundo"
- "A IA exterminou a humanidade no ano 2150"
- "O Vrexmoor saiu da anarquia e virou democracia"

Isso gera conteúdo orgânico no TikTok e redes sociais.

---

## Como me ajudar

Quando eu pedir ajuda no Divinus, as tarefas mais comuns são:

1. **Novos scripts GDScript** para funcionalidades novas
2. **Correção de erros** que aparecem no console do Godot
3. **Melhorias na UI** (sempre pensando em mobile portrait)
4. **Balanceamento** dos sistemas de simulação
5. **Assets e dados** (novos eventos, países, poderes)

Sempre que criar arquivos GDScript, use **Godot 4.x** (não Godot 3). A linguagem é GDScript com tipagem estática quando possível.
