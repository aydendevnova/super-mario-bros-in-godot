#!/usr/bin/env python3
"""
Asset generation pipeline for the SMB Godot project (dev-only).

Generates palette-indexed sprite textures from the NES ROM for editor preview.
End users do NOT need this — the GDScript ripper in-engine handles ROM extraction.

Usage:
    python3 main.py            (interactive menu)
    python3 main.py sprites    (generate real textures from ROM)
    python3 main.py placeholders (generate magenta placeholder PNGs)
"""

import csv
import json
import os
import pathlib
import sys

HERE = pathlib.Path(__file__).resolve().parent
PROJECT_ROOT = HERE.parent
DATA_DIR = HERE / "data"

ROM_PATH = HERE / "smb.nes"

TEXTURES_OUT = PROJECT_ROOT / "assets" / "textures"

# ═══════════════════════════════════════════════════════════════════════════
# SPRITES
# ═══════════════════════════════════════════════════════════════════════════

sys.path.insert(0, str(HERE / "scripts"))

from smb_sprite_data import PLAYER_ANIMATIONS, ACTOR_ANIMATIONS
from smb_sprite_extractor import (
    load_chr_rom,
    render_frame,
    crop_transparent_rows,
    compose_bowser,
    build_master_spritesheet,
)

ACTOR_AUTOCROP = {
    "spring_a", "spring_b", "spring_c", "goomba_stomped", "spiny_egg", "spiny",
    "goomba", "buzzy", "cheep", "bullet", "podoboo",
    "koopa_stun", "buzzy_stun", "buzzy_stun_flip", "lakitu_duck",
}

PLAYER_AUTOCROP = {
    "walk_small", "skid_small", "jump_small", "swim_small",
    "climb_small", "death_small", "stand_small", "stand_medium",
}

PLAYER_NEED_FULL = {"stand_small", "stand_medium"}

ENEMY_DEFS = [
    ("goomba", {
        "walk": [("goomba", 0)],
        "flat": [("goomba_stomped", 0)],
    }),
    ("koopa_troopa", {
        "walk": [("koopa", 0), ("koopa", 1)],
    }),
    ("paratroopa", {
        "fly": [("koopa_para", 0), ("koopa_para", 1)],
    }),
    ("buzzy_beetle", {
        "walk": [("buzzy", 0), ("buzzy", 1)],
    }),
    ("spiny", {
        "walk": [("spiny", 0), ("spiny", 1)],
    }),
    ("spiny_egg", {
        "spin": [("spiny_egg", 0), ("spiny_egg", 1)],
    }),
    ("blooper", {
        "swim": [("blooper", 0), ("blooper", 1)],
    }),
    ("cheep_cheep", {
        "swim": [("cheep", 0), ("cheep", 1)],
    }),
    ("hammer_bro", {
        "walk": [("hammer_bro_a", 0), ("hammer_bro_a", 1)],
        "throw": [("hammer_bro_b", 0), ("hammer_bro_b", 1)],
    }),
    ("lakitu", {
        "idle": [("lakitu", 0)],
        "duck": [("lakitu_duck", 0)],
    }),
    ("piranha_plant", {
        "bite": [("piranha", 0), ("piranha", 1)],
    }),
    ("podoboo", {
        "idle": [("podoboo", 0)],
    }),
    ("bowser", {
        "walk": [("bowser", 0), ("bowser", 1), ("bowser", 2), ("bowser", 3)],
    }),
    ("bullet_bill", {
        "idle": [("bullet", 0)],
    }),
    ("koopa_shell", {
        "idle": [("koopa_stun", 0), ("koopa_stun", 1)],
    }),
    ("buzzy_shell", {
        "idle": [("buzzy_stun", 0)],
    }),
    ("springboard", {
        "idle": [("spring_a", 0)],
        "bounce": [("spring_a", 0), ("spring_b", 0), ("spring_c", 0)],
    }),
    ("princess", {
        "idle": [("princess", 0)],
    }),
    ("toad", {
        "idle": [("toad", 0)],
    }),
]

INDEX_COLORS = {
    0: (0, 0, 0, 0),
    1: (85, 0, 0, 255),
    2: (170, 0, 0, 255),
    3: (255, 0, 0, 255),
}


def decode_tile_absolute(chr_data: bytes, abs_idx: int) -> list[list[int]]:
    from PIL import Image as _  # noqa: ensure Pillow loaded
    base = abs_idx * 16
    pixels = []
    for row in range(8):
        lo = chr_data[base + row]
        hi = chr_data[base + row + 8]
        row_px = []
        for bit in range(7, -1, -1):
            val = ((lo >> bit) & 1) | (((hi >> bit) & 1) << 1)
            row_px.append(val)
        pixels.append(row_px)
    return pixels


def build_chr_mapping(chr_data: bytes):
    from PIL import Image
    meta = json.loads((DATA_DIR / "chr-mapping.json").read_text())
    width, height = meta["sheet_width"], meta["sheet_height"]
    img = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    px = img.load()
    with open(DATA_DIR / "chr-mapping.csv") as f:
        for row in csv.DictReader(f):
            col, r = int(row["col"]), int(row["row"])
            tile_idx = int(row["chr_tile"])
            hflip = int(row["hflip"]) != 0
            vflip = int(row["vflip"]) != 0
            pixels = decode_tile_absolute(chr_data, tile_idx)
            if vflip:
                pixels = pixels[::-1]
            if hflip:
                pixels = [rp[::-1] for rp in pixels]
            ox, oy = col * 8, r * 8
            for y, row_px in enumerate(pixels):
                for x, val in enumerate(row_px):
                    px[ox + x, oy + y] = INDEX_COLORS[val]
    return img


def render_actor_frames(chr_data: bytes) -> dict:
    frames = {}
    for name, anim_def in ACTOR_ANIMATIONS.items():
        rendered = []
        for tile_slots in anim_def["frames"]:
            img = render_frame(tile_slots, chr_data, palette=None)
            if name in ACTOR_AUTOCROP:
                img = crop_transparent_rows(img)
            rendered.append(img)
        frames[name] = rendered
    frames["bowser"] = [
        compose_bowser(frames["bowser_mouth_opened"][0], frames["bowser_step_right"][0]),
        compose_bowser(frames["bowser_mouth_opened"][0], frames["bowser_step_left"][0]),
        compose_bowser(frames["bowser_mouth_closed"][0], frames["bowser_step_right"][0]),
        compose_bowser(frames["bowser_mouth_closed"][0], frames["bowser_step_left"][0]),
    ]
    return frames


def render_player_frames(chr_data: bytes) -> dict:
    frames = {}
    for name, anim_frames in PLAYER_ANIMATIONS.items():
        rendered, rendered_full = [], []
        for tile_slots in anim_frames:
            img = render_frame(tile_slots, chr_data, palette=None)
            if name in PLAYER_NEED_FULL:
                rendered_full.append(img)
            if name in PLAYER_AUTOCROP:
                img = crop_transparent_rows(img)
            rendered.append(img)
        frames[name] = rendered
        if rendered_full:
            frames[f"{name}_full"] = rendered_full
    return frames


def export_enemy_pngs(actor_frames: dict, out_dir: pathlib.Path) -> int:
    out_dir.mkdir(parents=True, exist_ok=True)
    count = 0
    for scene_name, anims in ENEMY_DEFS:
        for anim_name, frame_refs in anims.items():
            for i, (src_anim, src_frame) in enumerate(frame_refs):
                actor_frames[src_anim][src_frame].save(out_dir / f"{scene_name}_{anim_name}_{i}.png")
                count += 1
    return count


def export_player_pngs(player_frames: dict, out_dir: pathlib.Path) -> int:
    out_dir.mkdir(parents=True, exist_ok=True)
    count = 0
    for anim_name, frames in sorted(player_frames.items()):
        for i, img in enumerate(frames):
            img.save(out_dir / f"{anim_name}_{i}.png")
            count += 1
    return count


def run_sprites() -> None:
    if not ROM_PATH.exists():
        print(f"ERROR: smb.nes not found at {ROM_PATH}")
        print("Place the Super Mario Bros. NES ROM as 'smb.nes' in the _gen_assets/ directory.")
        return

    try:
        from PIL import Image  # noqa
    except ImportError:
        print("ERROR: Pillow is required.  pip install Pillow")
        return

    print(f"Loading CHR ROM from {ROM_PATH} ...")
    chr_data = load_chr_rom(ROM_PATH)
    TEXTURES_OUT.mkdir(parents=True, exist_ok=True)

    print("Building chr-mapping.png ...")
    chr_img = build_chr_mapping(chr_data)
    chr_img.save(TEXTURES_OUT / "chr-mapping.png")
    print(f"  {TEXTURES_OUT / 'chr-mapping.png'}  ({chr_img.width}x{chr_img.height})")

    print("Rendering actor frames ...")
    actor_frames = render_actor_frames(chr_data)
    print("Rendering player frames ...")
    player_frames = render_player_frames(chr_data)

    print("Building spritesheet.png ...")
    merged = {**player_frames, **actor_frames}
    sheet = build_master_spritesheet(merged)
    sheet.save(TEXTURES_OUT / "spritesheet.png")
    print(f"  {TEXTURES_OUT / 'spritesheet.png'}  ({sheet.width}x{sheet.height})")

    print("Exporting enemy PNGs ...")
    n = export_enemy_pngs(actor_frames, TEXTURES_OUT / "enemies")
    print(f"  {n} frames -> {TEXTURES_OUT / 'enemies'}/")

    print("Exporting player PNGs ...")
    n = export_player_pngs(player_frames, TEXTURES_OUT / "player")
    print(f"  {n} frames -> {TEXTURES_OUT / 'player'}/")

    print(f"\nSprites done — all assets in {TEXTURES_OUT}/")


# ═══════════════════════════════════════════════════════════════════════════
# PLACEHOLDER GENERATION
# ═══════════════════════════════════════════════════════════════════════════

TEXTURE_DIMENSIONS = {
    "chr-mapping.png": (432, 232),
    "spritesheet.png": (224, 176),
    "enemies/blooper_swim_0.png": (16, 24),
    "enemies/blooper_swim_1.png": (16, 24),
    "enemies/bowser_walk_0.png": (32, 32),
    "enemies/bowser_walk_1.png": (32, 32),
    "enemies/bowser_walk_2.png": (32, 32),
    "enemies/bowser_walk_3.png": (32, 32),
    "enemies/bullet_bill_idle_0.png": (16, 16),
    "enemies/buzzy_beetle_walk_0.png": (16, 16),
    "enemies/buzzy_beetle_walk_1.png": (16, 16),
    "enemies/buzzy_shell_idle_0.png": (16, 16),
    "enemies/cheep_cheep_swim_0.png": (16, 16),
    "enemies/cheep_cheep_swim_1.png": (16, 16),
    "enemies/goomba_flat_0.png": (16, 8),
    "enemies/goomba_walk_0.png": (16, 16),
    "enemies/hammer_bro_throw_0.png": (16, 24),
    "enemies/hammer_bro_throw_1.png": (16, 24),
    "enemies/hammer_bro_walk_0.png": (16, 24),
    "enemies/hammer_bro_walk_1.png": (16, 24),
    "enemies/koopa_shell_idle_0.png": (16, 16),
    "enemies/koopa_shell_idle_1.png": (16, 16),
    "enemies/koopa_troopa_walk_0.png": (16, 24),
    "enemies/koopa_troopa_walk_1.png": (16, 24),
    "enemies/lakitu_duck_0.png": (16, 16),
    "enemies/lakitu_idle_0.png": (16, 24),
    "enemies/paratroopa_fly_0.png": (16, 24),
    "enemies/paratroopa_fly_1.png": (16, 24),
    "enemies/piranha_plant_bite_0.png": (16, 24),
    "enemies/piranha_plant_bite_1.png": (16, 32),
    "enemies/podoboo_idle_0.png": (16, 16),
    "enemies/princess_idle_0.png": (16, 24),
    "enemies/spiny_egg_spin_0.png": (16, 16),
    "enemies/spiny_egg_spin_1.png": (16, 16),
    "enemies/spiny_walk_0.png": (16, 16),
    "enemies/spiny_walk_1.png": (16, 16),
    "enemies/springboard_bounce_0.png": (16, 24),
    "enemies/springboard_bounce_1.png": (16, 16),
    "enemies/springboard_bounce_2.png": (16, 8),
    "enemies/springboard_idle_0.png": (16, 24),
    "enemies/toad_idle_0.png": (16, 24),
    "player/climb_large_0.png": (16, 32),
    "player/climb_large_1.png": (16, 32),
    "player/climb_small_0.png": (16, 16),
    "player/climb_small_1.png": (16, 16),
    "player/crouch_large_0.png": (16, 32),
    "player/death_small_0.png": (16, 16),
    "player/jump_large_0.png": (16, 32),
    "player/jump_small_0.png": (16, 16),
    "player/proj_large_0.png": (16, 32),
    "player/skid_large_0.png": (16, 32),
    "player/skid_small_0.png": (16, 16),
    "player/stand_large_0.png": (16, 32),
    "player/stand_medium_0.png": (16, 24),
    "player/stand_medium_full_0.png": (16, 32),
    "player/stand_small_0.png": (16, 16),
    "player/stand_small_full_0.png": (16, 32),
    "player/swim_large_0.png": (16, 32),
    "player/swim_large_1.png": (16, 32),
    "player/swim_large_2.png": (16, 32),
    "player/swim_small_0.png": (16, 16),
    "player/swim_small_1.png": (16, 16),
    "player/swim_small_2.png": (16, 16),
    "player/walk_large_0.png": (16, 32),
    "player/walk_large_1.png": (16, 32),
    "player/walk_large_2.png": (16, 32),
    "player/walk_small_0.png": (16, 16),
    "player/walk_small_1.png": (16, 16),
    "player/walk_small_2.png": (16, 16),
}


def run_placeholders() -> None:
    """Generate magenta placeholder PNGs at correct dimensions for every texture."""
    from PIL import Image

    TEXTURES_OUT.mkdir(parents=True, exist_ok=True)
    (TEXTURES_OUT / "enemies").mkdir(parents=True, exist_ok=True)
    (TEXTURES_OUT / "player").mkdir(parents=True, exist_ok=True)

    count = 0
    for rel_path, (w, h) in sorted(TEXTURE_DIMENSIONS.items()):
        out = TEXTURES_OUT / rel_path
        img = Image.new("RGBA", (w, h), (255, 0, 255, 255))
        img.save(out)
        count += 1

    print(f"Generated {count} magenta placeholder PNGs in {TEXTURES_OUT}/")
    print("Run 'python3 main.py sprites' with smb.nes to overwrite with real textures.")


# ═══════════════════════════════════════════════════════════════════════════
# MENU
# ═══════════════════════════════════════════════════════════════════════════

def main() -> None:
    args = [a.lower() for a in sys.argv[1:]]

    if args:
        if "sprites" in args:
            run_sprites()
        elif "placeholders" in args:
            run_placeholders()
        else:
            print("Usage: python3 main.py [sprites|placeholders]")
        return

    print("=" * 50)
    print("  SMB Godot — Asset Generator (dev-only)")
    print("=" * 50)
    print()
    print("  1) Generate sprites      (requires smb.nes + Pillow)")
    print("  2) Generate placeholders (magenta PNGs, no ROM needed)")
    print("  q) Quit")
    print()

    choice = input("Select option: ").strip().lower()

    if choice in ("1", "sprites"):
        run_sprites()
    elif choice in ("2", "placeholders"):
        run_placeholders()
    elif choice in ("q", "quit", "exit"):
        print("Bye.")
    else:
        print(f"Unknown option: {choice}")


if __name__ == "__main__":
    main()
