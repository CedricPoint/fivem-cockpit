# cockpit

[English](README.md) · **Français**

**Des contrôles de véhicule pour FiveM qui marchent sur n'importe quel serveur.**
Portes, vitres, sièges, moteur, clignotants et régulateur de vitesse — aucun
framework, aucune dépendance, aucune base de données, quatre fichiers.

[![CI](https://github.com/CedricPoint/fivem-cockpit/actions/workflows/ci.yml/badge.svg)](https://github.com/CedricPoint/fivem-cockpit/actions/workflows/ci.yml)
[![autonome](https://img.shields.io/badge/framework-aucun-brightgreen.svg)](#compatibilité)
[![licence](https://img.shields.io/badge/licence-MIT-blue.svg)](LICENSE)

Chaque action est un simple natif du jeu appliqué à la voiture que vous
conduisez. Rien à migrer, rien à régler avant de démarrer, et rien qui casse
quand vous changez de framework — puisqu'il ne demande jamais lequel vous
utilisez.

## Ce que vous obtenez

| | commande | touche par défaut | |
| --- | --- | --- | --- |
| 🔑 | `/engine` | `PAVÉ NUM 0` | démarrer ou couper le moteur |
| 🚪 | `/door 1-6 \| fl fr rl rr hood trunk \| all` | — | ouvrir ou fermer n'importe quelle porte |
| 🧰 | `/hood`, `/trunk` | — | les deux dont on se sert vraiment, en un mot |
| 🪟 | `/window 1-4 \| fl fr rl rr \| all` | — | baisser et remonter les vitres |
| 💺 | `/seat [1-4]` | — | changer de place sans sortir — vide prend le premier siège libre |
| ↔️ | `/left`, `/right` | `PAVÉ NUM 4`, `PAVÉ NUM 6` | clignotants, vus par tous les joueurs |
| ⚠️ | `/hazards` | `PAVÉ NUM 5` | warnings, qui continuent de clignoter sur une voiture que vous quittez |
| 🎯 | `/cruise [km/h]` | `PAVÉ NUM 8` | tenir une vitesse — vide tient celle du moment |

Les touches ne sont que des valeurs par défaut : chaque joueur peut les
réassigner dans **Paramètres → Raccourcis clavier → FiveM**, et les commandes
restent accessibles depuis le chat dans tous les cas.

## Installation

```bash
cd resources
git clone https://github.com/CedricPoint/fivem-cockpit.git cockpit
```

Puis dans votre `server.cfg` :

```cfg
ensure cockpit
```

C'est toute l'installation. N'importe quelle version actuelle de serveur FiveM,
et rien d'autre.

## Configuration

`config.lua`, et elle est facultative : les valeurs par défaut sont l'expérience
prévue.

```lua
Config.Features = {
    engine     = true,
    doors      = true,
    windows    = true,
    seats      = true,
    indicators = true,
    cruise     = true,
}

Config.SeatSwapMaxSpeed = 30.0   -- km/h, 0 supprime le contrôle
Config.CruiseMaxSpeed   = 250.0  -- km/h
Config.SyncIndicators   = true   -- montrer vos clignotants aux autres joueurs
Config.Notifications    = true
```

Les commandes et les touches par défaut s'y trouvent également : vous pouvez
renommer tout ce qui entre en conflit avec une ressource déjà en place.
Désactiver une fonction retire sa commande et son raccourci, et ne touche à rien
d'autre.

## Comment il se comporte

Quelques choix qui méritent d'être connus avant de lire le code :

- **Seul le conducteur agit sur le véhicule.** Un passager ne possède pas la
  voiture sur le réseau : une porte qu'il ouvrirait resterait fermée sur tous les
  autres écrans. Refuser est plus clair que ne rien faire. Le changement de siège
  fait exception — il ne déplace que votre propre personnage, donc tout le monde
  peut le faire.
- **Les warnings vous survivent.** Éloignez-vous d'une voiture warnings allumés :
  ils continuent de clignoter, pour vous comme pour les autres, comme il se doit.
- **Freiner coupe le régulateur**, comme un vrai limiteur. Sortir du véhicule
  aussi.
- **Les clignotants passent par le serveur**, parce que le jeu les garde en
  local. Le relais est limité en débit, et le pire qu'un paquet forgé puisse
  faire est de faire clignoter la voiture de quelqu'un.
- **Rien n'est stocké.** Pas de base de données, pas de fichier d'état, aucune
  donnée de joueur.

## Compatibilité

Autonome veut dire autonome : ni ESX, ni QBCore, ni ox_lib, ni NUI, aucun export
de quoi que ce soit. Cela veut dire aussi qu'il cohabite avec ces frameworks sans
y toucher — si le vôtre gère déjà les sièges, désactivez cette seule fonction et
gardez le reste.

La seule chose à surveiller est une autre ressource qui occupe les mêmes noms de
commandes (`/engine` et `/seat` sont populaires). Renommez-les dans `config.lua`
et c'est réglé.

## Tests

La logique des commandes tourne en dehors du jeu. `test/harness.lua` bouchonne
chaque natif contre un petit monde factice — un joueur, une quatre-places — pour
que les vrais gestionnaires de `client.lua` soient exercés sous Lua tout court :

```bash
lua5.4 test/run.lua
```

```
cockpit
  ok   the engine toggles off and back on
  ok   /door all opens everything, then shuts everything
  ok   seats cannot be swapped at speed
  ok   hazards keep blinking on a car the player left
  ok   braking releases cruise control
  ok   a passenger cannot touch the vehicle
  ...
  26 checks, 0 failed
```

Ce n'est pas un substitut à un tour de voiture, mais cela veut dire qu'une faute
de frappe dans l'analyse des arguments ou une bascule inversée n'arrivera jamais
sur votre serveur.

## Licence

MIT — faites-en ce que vous voulez.
