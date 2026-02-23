# Screen
SCREEN_W = 600
SCREEN_H = 800
FPS = 60
TITLE = "StarForge"

# Colors
BLACK  = (0,   0,   0)
WHITE  = (255, 255, 255)
GREY   = (120, 120, 120)
DARK   = (15,  15,  30)
RED    = (220, 50,  50)
ORANGE = (255, 140, 0)
YELLOW = (255, 220, 50)
GREEN  = (50,  220, 100)
CYAN   = (50,  220, 255)
BLUE   = (50,  100, 255)
PURPLE = (180, 50,  255)
PINK   = (255, 80,  180)

# Player
PLAYER_SPEED      = 240      # px/s
PLAYER_MAX_HP     = 100
PLAYER_SHOOT_RATE = 0.18     # seconds between shots (lower = faster)

# Bullet
BULLET_SPEED  = 520
BULLET_DAMAGE = 12

# Enemy tiers  (name, color, hp, speed, score, xp, shoot_rate, bullet_dmg)
ENEMY_TIERS = [
    ("Scout",   CYAN,   30,  110, 10, 12,  0.0,  0),
    ("Fighter", ORANGE, 70,  80,  25, 28,  1.8, 10),
    ("Cruiser", RED,   160,  55,  60, 65,  1.2, 18),
    ("Boss",    PINK,  500,  35, 200,200,  0.9, 25),
]

# Spawn timing (seconds between spawns at wave 1; decreases with wave)
BASE_SPAWN_INTERVAL = 1.4
MIN_SPAWN_INTERVAL  = 0.35

# XP thresholds per level (level 1 needs XP_PER_LEVEL[0] xp, etc.)
XP_PER_LEVEL = [100, 160, 240, 340, 460, 600, 760, 940, 1140, 9999]

# Upgrade choices per level-up
UPGRADES = [
    {
        "id": "damage",
        "label": "Weapon Damage +25%",
        "desc": "Each bullet hits harder.",
        "color": ORANGE,
    },
    {
        "id": "fire_rate",
        "label": "Fire Rate +20%",
        "desc": "Shoot more bullets per second.",
        "color": YELLOW,
    },
    {
        "id": "spread",
        "label": "Spread Shot",
        "desc": "Fire 3 bullets in a cone.",
        "color": CYAN,
    },
    {
        "id": "max_hp",
        "label": "Hull Plating +30 HP",
        "desc": "Increase maximum health.",
        "color": GREEN,
    },
    {
        "id": "heal",
        "label": "Emergency Repair",
        "desc": "Restore 40% of max HP now.",
        "color": GREEN,
    },
    {
        "id": "shield",
        "label": "Shield Generator",
        "desc": "Absorbs one hit every 6 s.",
        "color": BLUE,
    },
    {
        "id": "speed",
        "label": "Engine Boost +15%",
        "desc": "Move faster across the field.",
        "color": PURPLE,
    },
    {
        "id": "pierce",
        "label": "Piercing Rounds",
        "desc": "Bullets pass through enemies.",
        "color": PINK,
    },
]
