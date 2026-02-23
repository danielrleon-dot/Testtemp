import pygame
import math
import random
from constants import *


class Bullet(pygame.sprite.Sprite):
    def __init__(self, x, y, angle_deg, damage, speed, color, piercing=False):
        super().__init__()
        self.damage   = damage
        self.piercing = piercing
        rad = math.radians(angle_deg)
        self.vx = math.sin(rad) * speed
        self.vy = -math.cos(rad) * speed
        self.image = pygame.Surface((5, 12), pygame.SRCALPHA)
        pygame.draw.rect(self.image, color, (0, 0, 5, 12), border_radius=2)
        self.rect = self.image.get_rect(center=(x, y))
        self.pos  = pygame.Vector2(x, y)

    def update(self, dt, *_):
        self.pos.x += self.vx * dt
        self.pos.y += self.vy * dt
        self.rect.center = (int(self.pos.x), int(self.pos.y))
        if (self.rect.bottom < 0 or self.rect.top > SCREEN_H
                or self.rect.right < 0 or self.rect.left > SCREEN_W):
            self.kill()


class EnemyBullet(Bullet):
    def __init__(self, x, y, damage):
        super().__init__(x, y, 0, damage, 260, RED, False)
        # straight down
        self.vx = 0
        self.vy = 260


class Player(pygame.sprite.Sprite):
    def __init__(self):
        super().__init__()
        self._build_image()
        self.rect = self.image.get_rect(center=(SCREEN_W // 2, SCREEN_H - 100))
        self.pos  = pygame.Vector2(self.rect.center)

        # Stats
        self.max_hp      = PLAYER_MAX_HP
        self.hp          = self.max_hp
        self.speed       = PLAYER_SPEED
        self.shoot_rate  = PLAYER_SHOOT_RATE   # cooldown in seconds
        self._shoot_cd   = 0.0
        self.bullet_dmg  = BULLET_DAMAGE
        self.spread      = False
        self.piercing    = False

        # Shield
        self.has_shield      = False
        self.shield_active   = False
        self.shield_cd       = 0.0
        self.SHIELD_RECHARGE = 6.0

        # Invincibility after hit
        self.invuln_timer = 0.0
        self.INVULN_TIME  = 1.0

        # Score / XP
        self.score = 0
        self.xp    = 0
        self.level = 1
        self.xp_to_next = XP_PER_LEVEL[0]
        self.pending_levelups = 0

    def _build_image(self):
        self.image = pygame.Surface((40, 48), pygame.SRCALPHA)
        # Body
        body = [(20, 0), (36, 40), (20, 32), (4, 40)]
        pygame.draw.polygon(self.image, CYAN, body)
        # Engine glow
        pygame.draw.ellipse(self.image, BLUE, (12, 36, 16, 10))
        # Cockpit
        pygame.draw.ellipse(self.image, WHITE, (15, 10, 10, 14))

    def gain_xp(self, amount):
        self.xp += amount
        while self.xp >= self.xp_to_next and self.level <= len(XP_PER_LEVEL):
            self.xp -= self.xp_to_next
            self.level += 1
            idx = min(self.level - 1, len(XP_PER_LEVEL) - 1)
            self.xp_to_next = XP_PER_LEVEL[idx]
            self.pending_levelups += 1

    def apply_upgrade(self, upg_id):
        if upg_id == "damage":
            self.bullet_dmg = int(self.bullet_dmg * 1.25)
        elif upg_id == "fire_rate":
            self.shoot_rate = max(0.04, self.shoot_rate * 0.80)
        elif upg_id == "spread":
            self.spread = True
        elif upg_id == "max_hp":
            self.max_hp += 30
            self.hp = min(self.hp + 30, self.max_hp)
        elif upg_id == "heal":
            self.hp = min(self.hp + int(self.max_hp * 0.4), self.max_hp)
        elif upg_id == "shield":
            self.has_shield = True
            self.shield_active = True
        elif upg_id == "speed":
            self.speed = int(self.speed * 1.15)
        elif upg_id == "pierce":
            self.piercing = True

    def take_damage(self, amount):
        if self.invuln_timer > 0:
            return
        if self.shield_active:
            self.shield_active = False
            self.shield_cd = self.SHIELD_RECHARGE
            return
        self.hp -= amount
        self.hp = max(self.hp, 0)
        self.invuln_timer = self.INVULN_TIME

    def shoot(self):
        bullets = []
        if self.spread:
            for angle in (-15, 0, 15):
                bullets.append(Bullet(
                    self.rect.centerx, self.rect.top,
                    angle, self.bullet_dmg, BULLET_SPEED, YELLOW, self.piercing
                ))
        else:
            bullets.append(Bullet(
                self.rect.centerx, self.rect.top,
                0, self.bullet_dmg, BULLET_SPEED, YELLOW, self.piercing
            ))
        return bullets

    def update(self, dt, keys):
        # Movement
        dx = dy = 0
        if keys[pygame.K_LEFT]  or keys[pygame.K_a]: dx -= 1
        if keys[pygame.K_RIGHT] or keys[pygame.K_d]: dx += 1
        if keys[pygame.K_UP]    or keys[pygame.K_w]: dy -= 1
        if keys[pygame.K_DOWN]  or keys[pygame.K_s]: dy += 1
        if dx and dy:
            dx *= 0.7071
            dy *= 0.7071
        self.pos.x += dx * self.speed * dt
        self.pos.y += dy * self.speed * dt
        # Clamp
        hw = self.rect.width  // 2
        hh = self.rect.height // 2
        self.pos.x = max(hw,           min(SCREEN_W - hw, self.pos.x))
        self.pos.y = max(hh,           min(SCREEN_H - hh, self.pos.y))
        self.rect.center = (int(self.pos.x), int(self.pos.y))

        # Shoot cooldown
        self._shoot_cd = max(0.0, self._shoot_cd - dt)

        # Invuln timer
        self.invuln_timer = max(0.0, self.invuln_timer - dt)

        # Shield recharge
        if self.has_shield and not self.shield_active:
            self.shield_cd -= dt
            if self.shield_cd <= 0:
                self.shield_active = True

    def try_shoot(self):
        if self._shoot_cd <= 0:
            self._shoot_cd = self.shoot_rate
            return self.shoot()
        return []

    @property
    def alive(self):
        return self.hp > 0


class Enemy(pygame.sprite.Sprite):
    def __init__(self, tier_idx, x, y):
        super().__init__()
        name, color, hp, speed, score, xp, shoot_rate, bullet_dmg = ENEMY_TIERS[tier_idx]
        self.tier       = tier_idx
        self.name       = name
        self.color      = color
        self.max_hp     = hp
        self.hp         = hp
        self.speed      = speed
        self.score_val  = score
        self.xp_val     = xp
        self.shoot_rate = shoot_rate
        self.bullet_dmg = bullet_dmg
        self._shoot_cd  = random.uniform(0, shoot_rate) if shoot_rate > 0 else 0
        self._build_image()
        self.rect = self.image.get_rect(center=(x, y))
        self.pos  = pygame.Vector2(self.rect.center)
        # Sine-wave drift
        self._drift_phase = random.uniform(0, math.pi * 2)
        self._drift_amp   = random.uniform(40, 90)
        self._drift_freq  = random.uniform(0.8, 1.6)
        self._time        = 0.0

    def _build_image(self):
        size = (28, 28, 40, 64)[self.tier]
        self.image = pygame.Surface((size, size), pygame.SRCALPHA)
        pts = self._hull_points(size)
        pygame.draw.polygon(self.image, self.color, pts)
        # Cockpit mark
        cx, cy = size // 2, size // 2
        r = max(4, size // 5)
        pygame.draw.circle(self.image, BLACK, (cx, cy), r)

    def _hull_points(self, s):
        h = s // 2
        if self.tier == 0:   # Scout — diamond
            return [(h, 0), (s, h), (h, s), (0, h)]
        elif self.tier == 1: # Fighter — arrow
            return [(h, s), (0, 0), (h, s//3), (s, 0)]
        elif self.tier == 2: # Cruiser — wide
            return [(0, s//4), (s//3, 0), (2*s//3, 0), (s, s//4), (s, 3*s//4), (0, 3*s//4)]
        else:                # Boss — octagon
            q = s // 4
            return [(q,0),(3*q,0),(s,q),(s,3*q),(3*q,s),(q,s),(0,3*q),(0,q)]

    def take_damage(self, amount):
        self.hp -= amount
        if self.hp <= 0:
            self.kill()
            return True
        return False

    def try_shoot(self, dt):
        if self.shoot_rate <= 0:
            return None
        self._shoot_cd -= dt
        if self._shoot_cd <= 0:
            self._shoot_cd = self.shoot_rate
            return EnemyBullet(self.rect.centerx, self.rect.bottom, self.bullet_dmg)
        return None

    def update(self, dt, *_):
        self._time += dt
        drift = math.sin(self._time * self._drift_freq + self._drift_phase) * self._drift_amp * dt
        self.pos.x += drift
        self.pos.y += self.speed * dt
        self.pos.x = max(0, min(SCREEN_W, self.pos.x))
        self.rect.center = (int(self.pos.x), int(self.pos.y))
        if self.rect.top > SCREEN_H + 10:
            self.kill()

    def draw_healthbar(self, surface):
        bw = self.rect.width
        bh = 4
        bx = self.rect.left
        by = self.rect.top - 6
        ratio = self.hp / self.max_hp
        pygame.draw.rect(surface, GREY, (bx, by, bw, bh))
        pygame.draw.rect(surface, GREEN, (bx, by, int(bw * ratio), bh))
