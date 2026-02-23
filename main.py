"""
StarForge — Space Shooter RPG
Run with: python main.py
Controls: WASD / Arrow keys to move, SPACE to shoot, 1-3 to pick upgrade on level-up.
"""

import pygame
import random
import sys

from constants import *
from entities  import Player, Enemy
from hud       import HUD, StarField, UpgradeScreen, GameOverScreen


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def pick_upgrade_choices(player):
    """Pick 3 random upgrades (avoiding duplicates, with some weight logic)."""
    import constants as C
    pool = C.UPGRADES[:]
    # Never offer spread if already has spread, etc.
    if player.spread:
        pool = [u for u in pool if u["id"] != "spread"]
    if player.piercing:
        pool = [u for u in pool if u["id"] != "pierce"]
    if not player.has_shield:
        pass  # shield is always available until acquired
    else:
        pool = [u for u in pool if u["id"] != "shield"]
    random.shuffle(pool)
    return pool[:3]


def make_wave(wave_num):
    """Return a list of (tier_idx, x, delay) tuples for the wave."""
    enemies = []
    count = 4 + wave_num * 2
    boss_wave = (wave_num % 5 == 0)
    for i in range(count):
        # Higher waves introduce higher-tier enemies more often
        weights = [max(0, 40 - wave_num * 4),   # Scout
                   max(0, 30 + wave_num * 2),    # Fighter
                   max(0, 10 + wave_num * 3),    # Cruiser
                   0]                            # Boss only on boss waves
        if boss_wave:
            weights[3] = 50
        total = sum(weights)
        weights = [w / total for w in weights]
        tier = random.choices([0, 1, 2, 3], weights=weights)[0]
        x    = random.randint(30, SCREEN_W - 30)
        delay = i * max(BASE_SPAWN_INTERVAL - wave_num * 0.05, MIN_SPAWN_INTERVAL)
        enemies.append((tier, x, delay))
    return enemies


# ---------------------------------------------------------------------------
# Game states
# ---------------------------------------------------------------------------
STATE_PLAYING  = "playing"
STATE_UPGRADE  = "upgrade"
STATE_GAMEOVER = "gameover"


class Game:
    def __init__(self, screen, clock):
        self.screen = screen
        self.clock  = clock
        self._reset()

    def _reset(self):
        self.player  = Player()
        self.all_sprites   = pygame.sprite.Group(self.player)
        self.enemies       = pygame.sprite.Group()
        self.player_bullets= pygame.sprite.Group()
        self.enemy_bullets = pygame.sprite.Group()

        self.hud           = HUD()
        self.stars         = StarField()
        self.upgrade_ui    = UpgradeScreen()
        self.gameover_ui   = GameOverScreen()

        self.state         = STATE_PLAYING
        self.wave          = 0
        self._wave_enemies = []
        self._wave_timer   = 0.0
        self._between_wave = False
        self._wave_pause   = 0.0

        self._upgrade_choices = []
        self._upgrade_sel     = 0

        self._advance_wave()

    def _advance_wave(self):
        self.wave += 1
        self._wave_enemies = make_wave(self.wave)
        self._wave_timer   = 0.0
        self._between_wave = False

    def _spawn_pending(self, dt):
        self._wave_timer += dt
        while self._wave_enemies and self._wave_timer >= self._wave_enemies[0][2]:
            tier, x, _ = self._wave_enemies.pop(0)
            e = Enemy(tier, x, -30)
            self.enemies.add(e)
            self.all_sprites.add(e)

    def _check_wave_complete(self):
        if not self._wave_enemies and len(self.enemies) == 0 and not self._between_wave:
            self._between_wave = True
            self._wave_pause   = 2.0

    def _handle_levelups(self):
        if self.player.pending_levelups > 0:
            self.player.pending_levelups -= 1
            self._upgrade_choices = pick_upgrade_choices(self.player)
            self._upgrade_sel     = 0
            self.state = STATE_UPGRADE

    def _apply_selected_upgrade(self):
        upg = self._upgrade_choices[self._upgrade_sel]
        self.player.apply_upgrade(upg["id"])
        self.state = STATE_PLAYING
        self._handle_levelups()   # chain if multiple pending

    def run(self):
        running = True
        while running:
            dt = self.clock.tick(FPS) / 1000.0
            dt = min(dt, 0.05)  # cap to avoid spiral of death

            for event in pygame.event.get():
                if event.type == pygame.QUIT:
                    pygame.quit()
                    sys.exit()
                self._handle_event(event)

            self._update(dt)
            self._draw()
            pygame.display.flip()

    # ------------------------------------------------------------------
    # Event handling
    # ------------------------------------------------------------------
    def _handle_event(self, event):
        if self.state == STATE_PLAYING:
            pass  # continuous key handling in _update

        elif self.state == STATE_UPGRADE:
            if event.type == pygame.KEYDOWN:
                if event.key == pygame.K_1 and len(self._upgrade_choices) >= 1:
                    self._upgrade_sel = 0
                    self._apply_selected_upgrade()
                elif event.key == pygame.K_2 and len(self._upgrade_choices) >= 2:
                    self._upgrade_sel = 1
                    self._apply_selected_upgrade()
                elif event.key == pygame.K_3 and len(self._upgrade_choices) >= 3:
                    self._upgrade_sel = 2
                    self._apply_selected_upgrade()
                elif event.key == pygame.K_UP:
                    self._upgrade_sel = max(0, self._upgrade_sel - 1)
                elif event.key == pygame.K_DOWN:
                    self._upgrade_sel = min(len(self._upgrade_choices) - 1,
                                            self._upgrade_sel + 1)
                elif event.key == pygame.K_RETURN or event.key == pygame.K_SPACE:
                    self._apply_selected_upgrade()

        elif self.state == STATE_GAMEOVER:
            if event.type == pygame.KEYDOWN:
                if event.key == pygame.K_r:
                    self._reset()
                elif event.key == pygame.K_q:
                    pygame.quit()
                    sys.exit()

    # ------------------------------------------------------------------
    # Update
    # ------------------------------------------------------------------
    def _update(self, dt):
        if self.state == STATE_UPGRADE or self.state == STATE_GAMEOVER:
            return

        keys = pygame.key.get_pressed()
        self.player.update(dt, keys)

        # Shoot
        if keys[pygame.K_SPACE] or keys[pygame.K_z]:
            new_bullets = self.player.try_shoot()
            for b in new_bullets:
                self.player_bullets.add(b)
                self.all_sprites.add(b)

        # Spawn wave enemies
        self._spawn_pending(dt)

        # Update enemies
        for e in list(self.enemies):
            e.update(dt)
            eb = e.try_shoot(dt)
            if eb:
                self.enemy_bullets.add(eb)
                self.all_sprites.add(eb)

        # Update bullets
        self.player_bullets.update(dt)
        self.enemy_bullets.update(dt)

        # Collision: player bullets vs enemies
        hits = pygame.sprite.groupcollide(
            self.enemies, self.player_bullets,
            False, False
        )
        for enemy, bullets in hits.items():
            for b in bullets:
                killed = enemy.take_damage(b.damage)
                if not b.piercing:
                    b.kill()
                if killed:
                    self.player.score += enemy.score_val
                    self.player.gain_xp(enemy.xp_val)

        # Collision: enemy bullets vs player
        for eb in list(self.enemy_bullets):
            if eb.rect.colliderect(self.player.rect):
                self.player.take_damage(eb.bullet_dmg)
                eb.kill()

        # Collision: enemies vs player (ram)
        for e in list(self.enemies):
            if e.rect.colliderect(self.player.rect):
                self.player.take_damage(e.max_hp // 4)
                e.kill()

        # Level-up check
        self._handle_levelups()

        # Wave management
        self._check_wave_complete()
        if self._between_wave:
            self._wave_pause -= dt
            if self._wave_pause <= 0:
                self._advance_wave()

        # Game over
        if not self.player.alive:
            self.state = STATE_GAMEOVER

    # ------------------------------------------------------------------
    # Draw
    # ------------------------------------------------------------------
    def _draw(self):
        self.screen.fill(DARK)
        self.stars.update_and_draw(self.screen, 1 / FPS)

        # Draw all sprites
        for sprite in self.all_sprites:
            if sprite.alive():
                self.screen.blit(sprite.image, sprite.rect)

        # Enemy health bars
        for e in self.enemies:
            e.draw_healthbar(self.screen)

        # Player invuln flash
        if self.player.invuln_timer > 0:
            if int(self.player.invuln_timer * 10) % 2 == 0:
                flash = pygame.Surface(self.player.rect.size, pygame.SRCALPHA)
                flash.fill((255, 255, 255, 80))
                self.screen.blit(flash, self.player.rect)

        # Shield ring
        if self.player.has_shield and self.player.shield_active:
            pygame.draw.circle(
                self.screen, BLUE,
                self.player.rect.center,
                self.player.rect.width // 2 + 10,
                width=2
            )

        # Wave banner (between waves)
        if self._between_wave:
            font = pygame.font.SysFont("monospace", 32, bold=True)
            if self._wave_pause > 1.2:
                txt = font.render(f"WAVE {self.wave} CLEARED", True, GREEN)
            else:
                txt = font.render(f"WAVE {self.wave + 1}", True, YELLOW)
            self.screen.blit(txt, (SCREEN_W // 2 - txt.get_width() // 2, SCREEN_H // 2 - 20))

        self.hud.draw(self.screen, self.player)

        if self.state == STATE_UPGRADE:
            self.upgrade_ui.draw(self.screen, self._upgrade_choices, self._upgrade_sel)

        if self.state == STATE_GAMEOVER:
            self.gameover_ui.draw(self.screen, self.player, self.wave)


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------
def main():
    pygame.init()
    screen = pygame.display.set_mode((SCREEN_W, SCREEN_H))
    pygame.display.set_caption(TITLE)
    clock  = pygame.time.Clock()
    Game(screen, clock).run()


if __name__ == "__main__":
    main()
