# DIVINUS - Contexto Atual do Projeto

## O que e o Divinus

Divinus e um simulador de civilizacoes feito em **Godot 4.x**, onde o jogador atua como uma entidade divina que observa, influencia e acompanha a evolucao de um mundo vivo.

O foco atual nao e mobile. **Mobile fica para depois.** A prioridade agora e montar uma experiencia forte no PC: funcionando, legivel, jogavel e com gameplay emergente.

A ideia central do jogo e:

> O jogador nao controla diretamente o mundo. Ele observa, interfere e lida com as consequencias.

O Divinus precisa gerar historias que o jogador queira contar:

- "No meu mundo, um lider agressivo iniciou uma guerra continental."
- "Uma civilizacao medieval virou potencia tecnologica."
- "Um pais colapsou depois de uma sequencia de desastres e guerras."
- "A era moderna iluminou o planeta com cidades."

---

## Visao de Gameplay

### Loop principal

1. O jogador observa o globo.
2. O mundo evolui sozinho a cada ano.
3. Noticias mostram eventos importantes.
4. O jogador escolhe um poder divino.
5. O poder e aplicado em um pais.
6. O mundo reage mecanicamente e visualmente.
7. Novas historias, guerras, colapsos e aliancas surgem.

### Pilar principal

**Divinus e um mundo observavel.**

O jogador deve conseguir olhar para o globo e perceber:

- paises crescendo;
- paises em guerra;
- regioes colapsando;
- civilizacoes avancando de era;
- luzes surgindo com tecnologia;
- consequencias visuais dos poderes divinos.

O painel de noticias explica. O globo mostra.

---

## Stack Tecnica

- **Engine:** Godot 4.x
- **Linguagem:** GDScript
- **Plataforma atual de desenvolvimento:** PC
- **Plataforma futura:** Android/iOS depois que a base de gameplay estiver forte
- **Cena principal atual:** `res://scenes/main_menu.tscn`
- **Cena do jogo:** `res://scenes/WorldMap.tscn`
- **Globo 3D:** `res://scenes/Globe3D.tscn`

---

## Estado Atual do Projeto

### Ja implementado

- Simulador central por turnos.
- 10 paises ficticios.
- Economia, tecnologia, militar, estabilidade, fe, agressividade e populacao.
- Progresso de eras: Tribal, Antiga, Medieval, Moderna, Futura.
- Poderes divinos com custo.
- Sistema de guerras.
- Sistema de aliancas.
- Lideres com nome e personalidade.
- Painel de detalhes do pais.
- Historico/timeline de eventos por pais.
- Tela inicial com opcoes de cenario.
- Eventos separados em arquivos JSON.
- Sistema modular de eventos, cadeias gerais e cadeias politicas.
- Globo 3D interativo com selecao de pais.
- Geracao procedural de planeta estilizado.
- Continentes, oceanos, montanhas e florestas.
- Atmosfera, nuvens, luzes noturnas e marcadores reativos.
- Linhas/flashes de guerra no globo.
- CivilizationLayer inicial por pais, com estruturas low-poly por era.
- `.gitignore` corrigido.

---

## Estrutura Importante

```text
Divinus/
├── project.godot
├── divinus_prompt.md
├── README.md
├── data/
│   ├── countries.json
│   └── events/
│       ├── standalone_events.json
│       ├── general_chains.json
│       └── political_chains.json
├── scenes/
│   ├── main_menu.tscn
│   ├── WorldMap.tscn
│   └── Globe3D.tscn
└── scripts/
    ├── country.gd
    ├── leader.gd
    ├── world_simulator.gd
    ├── event_system.gd
    ├── war_system.gd
    ├── god_powers.gd
    ├── world_map.gd
    ├── main_menu.gd
    ├── globe_3d.gd
    ├── civilization_layer.gd
    └── events/
        ├── event_database.gd
        ├── event_runner.gd
        └── chain_system.gd
```

---

## Sistemas de Gameplay

### Paises

Cada pais possui:

- nome;
- populacao;
- economia;
- tecnologia;
- militar;
- estabilidade;
- fe;
- agressividade;
- ideologia;
- era;
- relacoes diplomaticas;
- aliados;
- guerras ativas;
- lider;
- historico de eventos;
- historico de guerras;
- tendencia recente.

### Lideres

Cada pais tem um lider com:

- nome gerado;
- traco dominante;
- agressividade;
- diplomacia;
- isolamento;
- ambicao.

Os lideres influenciam:

- chance de guerra;
- chance de paz;
- relacoes diplomaticas;
- estabilidade;
- crescimento militar;
- eventos narrativos.

Exemplo de direcao desejada:

> "O ditador Kael de Kharuum declarou guerra aos vizinhos pelo terceiro ano seguido."

### Aliancas

Paises podem formar blocos por relacao alta.

Quando um pais entra em guerra, aliados podem ser chamados. Isso cria efeito domino:

- conflito local;
- chamada de aliado;
- escalada regional;
- guerra continental;
- possivel guerra mundial.

### Poderes Divinos

Poderes atuais:

- Abencoar;
- Crise Economica;
- Iluminacao;
- Desastre Natural;
- Paz Divina;
- Nova Ideologia;
- Regressao.

Fluxo desejado:

1. selecionar pais;
2. ver ficha/contexto;
3. escolher poder;
4. aplicar;
5. mundo reage visualmente e mecanicamente.

---

## Eventos

O sistema de eventos deve crescer em arquivos separados para evitar refatoracao gigante no futuro.

Estado atual importado:

- cerca de 50 eventos avulsos;
- 6 cadeias gerais;
- 5 cadeias politicas;
- 11 cadeias no total;
- 44 etapas;
- aproximadamente 50 eventos.

Arquivos atuais:

- `data/events/standalone_events.json`
- `data/events/general_chains.json`
- `data/events/political_chains.json`

Scripts responsaveis:

- `scripts/event_system.gd`
- `scripts/events/event_database.gd`
- `scripts/events/event_runner.gd`
- `scripts/events/chain_system.gd`

---

## Globo 3D

O globo e uma das partes centrais do jogo.

Ele deve ser:

- observavel;
- bonito;
- reativo;
- claro;
- leve o suficiente para mobile no futuro.

### Geracao procedural atual

A logica foi adaptada para Godot 4 a partir do conceito do projeto:

https://github.com/Bauxitedev/stylized-planet-generator

Adaptacao atual:

- icosphere procedural;
- deformacao por vetores aleatorios;
- biomas por altura;
- oceanos;
- continentes;
- montanhas;
- florestas;
- massas de terra ao redor dos paises;
- uso de `ArrayMesh`;
- uso de `MultiMesh` para elementos repetidos.

### Visual atual

O globo possui:

- planeta procedural;
- oceano;
- continentes;
- montanhas;
- florestas;
- atmosfera;
- nuvens;
- estrelas;
- marcadores por pais;
- luzes noturnas por tecnologia/era;
- linhas e flashes de guerra;
- auras de colapso/instabilidade.

### Regra de direcao visual

Cada sistema importante deve deixar uma marca no globo.

- crescimento: marcador maior;
- guerra: vermelho, pulso, linha, flash;
- colapso: aura escura;
- era moderna/futura: luzes noturnas;
- tecnologia avancada: mais brilho;
- desastre: efeito temporario futuro;
- aliancas: linhas suaves futuras;
- futuro: satelites futuros.

### CivilizationLayer

Cada marcador de pais possui uma camada visual filha:

- Tribal: tendas/fogueira/totens em geometria simples;
- Antiga: templos, fazendas e piramides;
- Medieval: castelo, vilas e igrejas;
- Moderna: predios, fabricas e luz urbana;
- Futura: megatorre, luz neon e orbitadores.

A camada usa fallback low-poly por codigo, entao funciona mesmo sem PNG/modelos externos.

---

## Tela Inicial e Cenarios

Ja existe tela inicial com cenarios.

Cenarios atuais:

- Mundo Padrao;
- Mundo Fragmentado;
- Era Dourada;
- Barril de Polvora.

Os cenarios alteram:

- estabilidade;
- relacoes diplomaticas;
- aliancas;
- militarizacao;
- economia;
- pontos divinos iniciais.

---

## Objetivo de Curto Prazo

Prioridade atual:

1. Deixar o globo visualmente legivel.
2. Melhorar continentes e distribuicao de terra.
3. Refinar fluxo de selecao de pais e aplicacao de poder.
4. Melhorar feedback visual dos poderes.
5. Fortalecer painel de pais.
6. Fazer guerras e aliancas ficarem mais dramáticas visualmente.
7. Continuar expandindo eventos modulares.

Mobile fica para depois.

---

## Roadmap

### Agora

- [x] Globo 3D integrado.
- [x] Lideres com personalidade.
- [x] Aliancas.
- [x] Painel de pais.
- [x] Tela inicial com cenarios.
- [x] Eventos divididos em arquivos.
- [x] Globo procedural.
- [x] Atmosfera e nuvens.
- [x] Marcadores reativos.
- [x] CivilizationLayer inicial por pais.
- [ ] Continentes mais legiveis e bonitos.
- [ ] Aplicacao de poder com feedback visual especifico.
- [ ] Linhas de alianca.
- [ ] Efeitos de desastre, fogo/fumaca e colapso regional.

### Depois

- [ ] Balanceamento de guerras.
- [ ] Mais eventos e cadeias.
- [ ] Save/load.
- [ ] Sons e feedbacks.
- [ ] Melhorar UI desktop.
- [ ] Exportar build PC jogavel.

### Futuro

- [ ] Mobile portrait.
- [ ] Otimizacao mobile.
- [ ] Satelites na era futura.
- [ ] Skins de planeta.
- [ ] Timelines alternativas.
- [ ] Possivel IA mais avancada para lideres.

---

## Tom do Jogo

Divinus deve parecer:

- divino;
- observacional;
- emergente;
- dramatico;
- historico;
- um pouco cruel;
- cheio de consequencias.

O jogador deve sentir que esta olhando para um pequeno planeta vivo.

---

## Como ajudar no projeto

Quando trabalhar no Divinus:

- usar Godot 4.x;
- manter GDScript simples e legivel;
- preferir sistemas modulares;
- evitar arquivos gigantes quando o conteudo for crescer;
- preservar performance pensando em mobile futuro;
- testar no PC primeiro;
- priorizar gameplay e clareza visual;
- fazer o mundo reagir visualmente sempre que possivel.

Passo 1: Estabilizar o Planeta

Ajustar proporção de terra/água.
Clarear continentes e costas.
Reduzir áreas escuras demais.
Garantir que rotação, seleção e marcadores funcionem bem.
Passo 2: Criar Camadas Visuais

Separar no código: terreno, natureza, civilização, guerra, atmosfera e órbita.
Não precisa refatorar tudo de uma vez.
Primeiro organizar globe_3d.gd para receber essas camadas.
Passo 3: Civilização Básica

Tribal/Antiga: fogueiras e aldeias pequenas.
Medieval: torres/castelos simples.
Moderna: blocos urbanos e luzes.
Futura: neon ou pequenos satélites.
Tudo low-poly, com MultiMesh.
Passo 4: Reação aos Dados

População alta aumenta densidade visual.
Tecnologia alta aumenta luzes/neon.
Estabilidade baixa cria fumaça/escurecimento.
Guerra cria vermelho, fogo e linhas.
Passo 5: Feedback dos Poderes

Abençoar: brilho dourado temporário.
Crise: escurecimento/fumaça.
Iluminação: pulso azul.
Desastre: impacto/fumaça.
Paz: pulso branco/verde.
Regressão: luzes somem ou reduzem.
Passo 6: Eventos Globais

Guerra mundial: várias linhas vermelhas e flashes.
Pandemia: luzes diminuem.
Era de ouro: aura dourada.
Colapso climático: nuvens escuras/fogo.
Passo 7: Polimento

Ajustar cores.
Ajustar escala dos elementos.
Melhorar câmera/zoom.
Remover excesso visual.
Testar performance.
