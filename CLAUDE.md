# CLAUDE.md

This file provides context and guidance for AI assistants (such as Claude) working in this repository.

## Repository Overview

**Name:** StarForge — Space Shooter RPG
**Language:** Python 3
**Dependency:** pygame 2.x

A top-down vertical-scrolling space shooter with RPG-style progression.
The player's spaceship fights through waves of enemies, gains XP, levels up,
and chooses upgrades that permanently change how the ship plays.

## Project Structure

```
Testtemp/
├── main.py        # Entry point, Game class, game-state machine
├── entities.py    # Player, Enemy, Bullet, EnemyBullet sprites
├── hud.py         # HUD, StarField, UpgradeScreen, GameOverScreen
├── constants.py   # All tunable values: screen size, colors, stats, upgrades
├── README.md
└── CLAUDE.md      # This file
```

## Development Setup

```bash
pip install pygame
python main.py
```

No virtual environment is required, but one is recommended on shared machines.

## Controls

| Key(s)            | Action           |
|-------------------|------------------|
| WASD / Arrow keys | Move spaceship   |
| Space / Z         | Shoot            |
| 1 / 2 / 3         | Pick upgrade     |
| Up / Down         | Navigate upgrade |
| Enter / Space     | Confirm upgrade  |
| R                 | Restart (game over) |
| Q                 | Quit (game over) |

## Architecture

### State machine (main.py)
`Game.state` is one of `STATE_PLAYING`, `STATE_UPGRADE`, `STATE_GAMEOVER`.
Transitions:
- `PLAYING` → `UPGRADE` when `player.pending_levelups > 0`
- `UPGRADE` → `PLAYING` (or next `UPGRADE`) when the player picks
- `PLAYING` → `GAMEOVER` when `player.hp <= 0`
- `GAMEOVER` → `PLAYING` on `R` (full reset via `_reset()`)

### Wave system
`make_wave(wave_num)` returns a list of `(tier, x, delay)` tuples.
Enemies are spawned on a timer inside `_spawn_pending`. Every 5th wave is a
"boss wave" that greatly increases Boss-tier spawns. The wave advances
automatically 2 s after all enemies are cleared.

### Entities (entities.py)
- **Player** — tracks stats (`hp`, `speed`, `shoot_rate`, `bullet_dmg`),
  upgrade flags (`spread`, `piercing`, `has_shield`), score, XP, and level.
  `apply_upgrade(id)` mutates stats in-place.
- **Enemy** — four tiers (Scout, Fighter, Cruiser, Boss) defined in
  `ENEMY_TIERS`. Moves downward with sinusoidal x-drift. Draws its own
  health bar via `draw_healthbar`.
- **Bullet / EnemyBullet** — simple velocity sprites; `piercing=True` skips
  self-kill on hit.

### RPG Upgrades (constants.py `UPGRADES`)
Each entry has `id`, `label`, `desc`, `color`.
`pick_upgrade_choices` filters already-obtained one-time upgrades and samples
3 random options. Adding a new upgrade only requires adding an entry here and
a matching branch in `Player.apply_upgrade`.

### HUD (hud.py)
- **HUD** — HP bar, XP bar, score, active upgrade tags.
- **StarField** — parallax star background.
- **UpgradeScreen** — semi-transparent overlay, 3 upgrade cards.
- **GameOverScreen** — final stats.

## Key Conventions for AI Assistants

- **Read before modifying.** Always read a file before editing it.
- **Minimal changes.** Only change what is necessary for the task at hand.
- **constants.py is the single source of truth** for all numeric tuning values.
  Do not hardcode magic numbers in entity or game logic files.
- **New upgrade type?** Add entry to `UPGRADES` in `constants.py` and a branch
  in `Player.apply_upgrade` in `entities.py`. Nothing else needs to change.
- **New enemy tier?** Append to `ENEMY_TIERS` and update `make_wave` weights.
- **No commented-out code.** Delete unused code.
- **No new files without clear need.** Prefer editing existing files.
- **Commit and push when done.** Use descriptive imperative-mood messages.

## Testing

No automated test framework. Use the headless smoke test pattern:

```bash
python3 -c "
import os; os.environ['SDL_VIDEODRIVER']='dummy'; os.environ['SDL_AUDIODRIVER']='dummy'
import pygame; pygame.init(); pygame.display.set_mode((600,800))
from entities import Player, Enemy
p = Player(); p.gain_xp(500); assert p.level > 1
print('OK')
"
```

## Git Workflow

- `master` — primary integration branch
- `claude/<description>-<session-id>` — AI-assisted work branches

```bash
git push -u origin <branch-name>
```
