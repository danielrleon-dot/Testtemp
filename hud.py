import pygame
import random
from constants import *


def _font(size):
    return pygame.font.SysFont("monospace", size, bold=True)


class HUD:
    def __init__(self):
        self._f_large  = _font(22)
        self._f_medium = _font(16)
        self._f_small  = _font(13)

    def draw(self, surface, player):
        # HP bar
        bar_x, bar_y, bar_w, bar_h = 10, SCREEN_H - 28, 200, 18
        ratio = player.hp / player.max_hp
        pygame.draw.rect(surface, DARK,  (bar_x - 1, bar_y - 1, bar_w + 2, bar_h + 2))
        pygame.draw.rect(surface, GREY,  (bar_x, bar_y, bar_w, bar_h))
        hp_color = GREEN if ratio > 0.5 else YELLOW if ratio > 0.25 else RED
        pygame.draw.rect(surface, hp_color, (bar_x, bar_y, int(bar_w * ratio), bar_h))
        txt = self._f_small.render(f"HP {player.hp}/{player.max_hp}", True, WHITE)
        surface.blit(txt, (bar_x + 4, bar_y + 2))

        # XP bar
        xp_x, xp_y, xp_w, xp_h = 10, SCREEN_H - 52, 200, 8
        xp_ratio = min(player.xp / player.xp_to_next, 1.0)
        pygame.draw.rect(surface, DARK, (xp_x - 1, xp_y - 1, xp_w + 2, xp_h + 2))
        pygame.draw.rect(surface, GREY, (xp_x, xp_y, xp_w, xp_h))
        pygame.draw.rect(surface, PURPLE, (xp_x, xp_y, int(xp_w * xp_ratio), xp_h))
        lv_txt = self._f_small.render(f"LV {player.level}", True, PURPLE)
        surface.blit(lv_txt, (214, xp_y - 2))

        # Shield indicator
        if player.has_shield:
            s_color = BLUE if player.shield_active else GREY
            pygame.draw.circle(surface, s_color, (bar_x + bar_w + 16, bar_y + bar_h // 2), 9)
            sh_txt = self._f_small.render("SH", True, s_color)
            surface.blit(sh_txt, (bar_x + bar_w + 26, bar_y + 2))

        # Score (top right)
        sc_txt = self._f_large.render(f"{player.score:07d}", True, WHITE)
        surface.blit(sc_txt, (SCREEN_W - sc_txt.get_width() - 10, 8))

        # Upgrades list (top left tiny)
        tags = []
        if player.spread:   tags.append("SPREAD")
        if player.piercing: tags.append("PIERCE")
        for i, tag in enumerate(tags):
            t = self._f_small.render(tag, True, CYAN)
            surface.blit(t, (10, 8 + i * 16))


class StarField:
    def __init__(self, n=120):
        self.stars = [
            [random.randint(0, SCREEN_W), random.randint(0, SCREEN_H),
             random.uniform(0.3, 1.8), random.randint(80, 200)]
            for _ in range(n)
        ]

    def update_and_draw(self, surface, dt):
        for s in self.stars:
            s[1] += s[2] * 60 * dt
            if s[1] > SCREEN_H:
                s[1] = 0
                s[0] = random.randint(0, SCREEN_W)
            c = int(s[3])
            pygame.draw.circle(surface, (c, c, c), (int(s[0]), int(s[1])), 1)


class UpgradeScreen:
    """Pause overlay for choosing an upgrade on level-up."""

    def __init__(self):
        self._f_title  = _font(30)
        self._f_label  = _font(20)
        self._f_desc   = _font(14)
        self._f_key    = _font(16)
        self._overlay  = pygame.Surface((SCREEN_W, SCREEN_H), pygame.SRCALPHA)
        self._overlay.fill((0, 0, 0, 180))

    def draw(self, surface, choices, selected):
        surface.blit(self._overlay, (0, 0))
        title = self._f_title.render("LEVEL UP  —  Choose an upgrade", True, YELLOW)
        surface.blit(title, (SCREEN_W // 2 - title.get_width() // 2, 80))

        card_w, card_h = 480, 90
        start_y = 160
        gap     = 105
        for i, upg in enumerate(choices):
            y = start_y + i * gap
            x = SCREEN_W // 2 - card_w // 2
            bg_color = (30, 30, 60) if i != selected else (50, 50, 120)
            pygame.draw.rect(surface, bg_color,   (x, y, card_w, card_h), border_radius=8)
            pygame.draw.rect(surface, upg["color"], (x, y, card_w, card_h), width=2, border_radius=8)

            # Key hint
            key_s = self._f_key.render(f"[{i+1}]", True, upg["color"])
            surface.blit(key_s, (x + 12, y + card_h // 2 - key_s.get_height() // 2))

            label_s = self._f_label.render(upg["label"], True, WHITE)
            surface.blit(label_s, (x + 48, y + 16))
            desc_s  = self._f_desc.render(upg["desc"],  True, GREY)
            surface.blit(desc_s,  (x + 50, y + 46))


class GameOverScreen:
    def __init__(self):
        self._f_big    = _font(52)
        self._f_medium = _font(24)
        self._f_small  = _font(18)

    def draw(self, surface, player, wave):
        ov = pygame.Surface((SCREEN_W, SCREEN_H), pygame.SRCALPHA)
        ov.fill((0, 0, 0, 200))
        surface.blit(ov, (0, 0))

        go = self._f_big.render("GAME OVER", True, RED)
        surface.blit(go, (SCREEN_W // 2 - go.get_width() // 2, 180))

        for i, line in enumerate([
            f"Score : {player.score:,}",
            f"Wave  : {wave}",
            f"Level : {player.level}",
        ]):
            t = self._f_medium.render(line, True, WHITE)
            surface.blit(t, (SCREEN_W // 2 - t.get_width() // 2, 310 + i * 38))

        restart = self._f_small.render("Press  R  to restart   or   Q  to quit", True, GREY)
        surface.blit(restart, (SCREEN_W // 2 - restart.get_width() // 2, 480))
