# Assets de Civilizacoes

O `CivilizationLayer` atual funciona sem assets externos: ele usa formas low-poly geradas por codigo.

Esta pasta fica reservada para uma versao futura com sprites/modelos por era:

- `tribal/`: tendas, fogueiras, totens
- `ancient/`: templos, muralhas, fazendas
- `medieval/`: castelos, vilas, igrejas
- `modern/`: predios, fabricas, luzes urbanas
- `future/`: torres, drones, plataformas, neon

## Moderna

A pasta `modern/city/` ja contem um recorte leve do `city.zip` para a era Moderna:

- predios comerciais low-poly
- arranha-ceus
- predio industrial
- chamine industrial

O arquivo `modern/modern_city_manifest.json` lista os modelos importados. A licenca dos kits usados e Creative Commons Zero (CC0), criados/distribuidos por Kenney.

O `CivilizationLayer` tenta carregar esses GLBs automaticamente. Se algum modelo ainda nao estiver importado pelo Godot, ele volta para as formas low-poly geradas por codigo.

Fontes gratuitas sugeridas:

- https://kenney.nl/assets
- https://itch.io/game-assets/free
- https://craftpix.net/freebies
