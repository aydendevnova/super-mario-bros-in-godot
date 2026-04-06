#!/usr/bin/env python3
"""
SMB Sprite Extractor
Extracts sprites from a Super Mario Bros. NES ROM.

Usage:
    python3 smb_sprite_extractor.py [rom.nes] [output_dir] [theme] [--indexed]

Defaults:
    rom.nes    → ../smb.nes
    output_dir → ../assets
    theme      → overworld   (also: underground, castle — ignored when --indexed)

Flags:
    --indexed  Export palette-indexed sprites (R channel encodes index 1/2/3)
               for runtime palette swapping via shader. Also emits palettes.json
               and a reference Godot shader file.

Requires: Pillow  (pip install Pillow)

No disassembly directory needed. All sprite layout data is in smb_sprite_data.py.
"""

import pathlib
import sys
from PIL import Image

from smb_sprite_data import PLAYER_ANIMATIONS, ACTOR_ANIMATIONS

# ---------------------------------------------------------------------------
# NES NTSC 2C02 palette (64 RGB triples — hardware characteristic, not copyrighted)
# ---------------------------------------------------------------------------
NES_PALETTE = [
    # 0x0x
    ( 84, 84, 84), (  0, 30,116), (  8, 16,144), ( 48,  0,136),
    ( 68,  0,100), ( 92,  0, 48), ( 84,  4,  0), ( 60, 24,  0),
    ( 32, 42,  0), (  8, 58,  0), (  0, 64,  0), (  0, 60,  0),
    (  0, 50, 60), (  0,  0,  0), (  0,  0,  0), (  0,  0,  0),
    # 0x1x
    (152,150,152), (  8, 76,196), ( 48, 50,236), ( 92, 30,228),
    (136, 20,176), (160, 20,100), (152, 34, 32), (120, 60,  0),
    ( 84, 90,  0), ( 40,114,  0), (  8,124,  0), (  0,118, 40),
    (  0,102,120), (  0,  0,  0), (  0,  0,  0), (  0,  0,  0),
    # 0x2x
    (236,238,236), ( 76,154,236), (120,124,236), (176, 98,236),
    (228, 84,236), (236, 88,180), (236,106,100), (212,136, 32),
    (160,170,  0), (116,196,  0), ( 76,208, 32), ( 56,204,108),
    ( 56,180,204), ( 60, 60, 60), (  0,  0,  0), (  0,  0,  0),
    # 0x3x
    (236,238,236), (168,204,236), (188,188,236), (212,178,236),
    (236,174,236), (236,174,212), (236,180,176), (228,196,144),
    (204,210,120), (180,222,120), (168,226,144), (152,226,180),
    (160,214,228), (160,162,160), (  0,  0,  0), (  0,  0,  0),
]

# Sprite palettes per world theme.
# Each slot: [transparent, color1, color2, color3] as NES palette indices.
# Derived from nmi_data.s palette_* tables in the smb-master disassembly.
SPRITE_PALETTES = {
    "overworld": [
        [0x0F, 0x16, 0x27, 0x18],  # 0: Mario       red / orange / yellow
        [0x0F, 0x1A, 0x30, 0x27],  # 1: Koopa        green / white / orange
        [0x0F, 0x16, 0x30, 0x27],  # 2: Red enemies  red / white / orange
        [0x0F, 0x0F, 0x36, 0x17],  # 3: Bowser / specials
    ],
    "underground": [
        [0x0F, 0x16, 0x27, 0x18],
        [0x0F, 0x00, 0x10, 0x30],
        [0x0F, 0x16, 0x30, 0x27],
        [0x0F, 0x0F, 0x36, 0x17],
    ],
    "castle": [
        [0x0F, 0x16, 0x27, 0x18],
        [0x0F, 0x1C, 0x36, 0x17],
        [0x0F, 0x16, 0x30, 0x27],
        [0x0F, 0x0F, 0x36, 0x17],
    ],
}

FRAME_COLS = 2  # all sprites are 2 tiles wide

# ---------------------------------------------------------------------------
# ROM loading
# ---------------------------------------------------------------------------

def load_chr_rom(rom_path: pathlib.Path) -> bytes:
    data = rom_path.read_bytes()
    if data[:4] != b"NES\x1a":
        raise ValueError(f"{rom_path} is not a valid iNES ROM")
    prg_banks = data[4]
    chr_banks  = data[5]
    if chr_banks == 0:
        raise ValueError("This ROM uses CHR RAM (no CHR ROM to extract)")
    prg_size  = prg_banks * 16384
    chr_size  = chr_banks * 8192
    chr_start = 16 + prg_size
    return data[chr_start : chr_start + chr_size]


# ---------------------------------------------------------------------------
# Tile decoding
# ---------------------------------------------------------------------------

def decode_tile(chr_data: bytes, tile_idx: int, is_bg: bool) -> list[list[int]]:
    """
    Decode one NES tile (16 bytes, 2-bitplane format) into an 8x8 array of
    palette indices 0-3.

    OBJ tiles live at CHR ROM bytes 0x0000-0x0FFF (tile_idx 0-255, is_bg=False).
    BG  tiles live at CHR ROM bytes 0x1000-0x1FFF (tile_idx 0-255, is_bg=True).
    """
    base = (0x1000 if is_bg else 0x0000) + tile_idx * 16
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


def render_tile(pixels: list[list[int]], nes_palette_indices: list[int]) -> Image.Image:
    """Convert an 8x8 pixel array to an RGBA image using the supplied palette slot."""
    img = Image.new("RGBA", (8, 8), (0, 0, 0, 0))
    px  = img.load()
    for y, row in enumerate(pixels):
        for x, val in enumerate(row):
            if val == 0:
                px[x, y] = (0, 0, 0, 0)
            else:
                r, g, b = NES_PALETTE[nes_palette_indices[val] & 0x3F]
                px[x, y] = (r, g, b, 255)
    return img


INDEX_COLORS = {
    0: (0, 0, 0, 0),
    1: (85, 0, 0, 255),
    2: (170, 0, 0, 255),
    3: (255, 0, 0, 255),
}


def render_tile_indexed(pixels: list[list[int]]) -> Image.Image:
    """Encode palette indices 0-3 into the red channel. No colors applied.

    Index 0 → transparent, 1 → R=85, 2 → R=170, 3 → R=255.
    The shader reads R to determine which palette color to apply at runtime.
    """
    img = Image.new("RGBA", (8, 8), (0, 0, 0, 0))
    px  = img.load()
    for y, row in enumerate(pixels):
        for x, val in enumerate(row):
            px[x, y] = INDEX_COLORS[val]
    return img


# ---------------------------------------------------------------------------
# Sprite frame rendering
# ---------------------------------------------------------------------------

def render_frame(
    tile_slots: list,
    chr_data: bytes,
    palette: list[int] | None = None,
    cols: int = FRAME_COLS,
) -> Image.Image:
    """
    Assemble a sprite image from a list of tile slots.
    Slots are arranged left-to-right, top-to-bottom in a grid of `cols` columns.
    None slots render as fully transparent 8×8 blocks.

    When palette is None, outputs palette-indexed pixels (for shader-based coloring).
    When palette is provided, outputs fully colored pixels using NES_PALETTE.

    H-flip rule (derived from render_chr_pair_do + render_actor in smb-master):
    When the same tile appears in both the left and right column of a row,
    the NES engine h-flips the right tile (symmetric sprites rendered with
    motion_dir bit-1 set, e.g. Lakitu, koopa/buzzy shells, toad body).
    """
    rows = (len(tile_slots) + cols - 1) // cols
    img  = Image.new("RGBA", (cols * 8, rows * 8), (0, 0, 0, 0))

    for i, slot in enumerate(tile_slots):
        col = i % cols
        row = i // cols
        if slot is None:
            continue

        tile_idx, is_bg = slot[0], slot[1]
        explicit_h = slot[2] if len(slot) > 2 else None
        explicit_v = slot[3] if len(slot) > 3 else False

        if explicit_h is not None:
            h_flip = explicit_h
        else:
            h_flip = False
            if col == 1 and i >= 1:
                left_slot = tile_slots[i - 1]
                if left_slot is not None and left_slot[:2] == slot[:2]:
                    h_flip = True

        try:
            pixels = decode_tile(chr_data, tile_idx, is_bg)
            if explicit_v:
                pixels = pixels[::-1]
            if h_flip:
                pixels = [row_px[::-1] for row_px in pixels]
            tile_img = render_tile_indexed(pixels) if palette is None else render_tile(pixels, palette)
            img.paste(tile_img, (col * 8, row * 8), tile_img)
        except IndexError:
            pass

    return img


def crop_transparent_rows(img: Image.Image) -> Image.Image:
    """Remove fully-transparent rows from the bottom (and top) of a sprite image."""
    px = img.load()
    w, h = img.size
    top = 0
    for r in range(h):
        if any(px[c, r][3] > 0 for c in range(w)):
            top = r
            break
    bottom = h
    for r in range(h - 1, -1, -1):
        if any(px[c, r][3] > 0 for c in range(w)):
            bottom = r + 1
            break
    if bottom <= top:
        return img
    top    = (top    // 8) * 8
    bottom = ((bottom + 7) // 8) * 8
    return img.crop((0, top, w, bottom))


# ---------------------------------------------------------------------------
# Bowser composition
# ---------------------------------------------------------------------------

def compose_bowser(head_img: Image.Image, body_img: Image.Image) -> Image.Image:
    """Combine Bowser head and body into one 32×32 image.

    Sub-sprites have reversed column order (NES facing convention), so body
    goes on the left and head on the right so the connecting edges meet.
    Head overlaps body by 1px to close the tile-boundary gap.
    """
    canvas = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    canvas.paste(body_img, (0, 8), body_img)
    canvas.paste(head_img, (15, 0), head_img)
    return canvas


# ---------------------------------------------------------------------------
# Master spritesheet
# ---------------------------------------------------------------------------

SPRITESHEET_ROWS = [
    # Small Mario
    [("stand_small", 0), ("walk_small", 0), ("walk_small", 1), ("walk_small", 2),
     ("jump_small", 0), ("skid_small", 0), ("climb_small", 0), ("climb_small", 1),
     ("swim_small", 0), ("swim_small", 1), ("swim_small", 2), ("death_small", 0)],
    # Large Mario
    [("stand_large", 0), ("stand_medium", 0),
     ("walk_large", 0), ("walk_large", 1), ("walk_large", 2),
     ("jump_large", 0), ("skid_large", 0), ("climb_large", 0), ("climb_large", 1),
     ("swim_large", 0), ("swim_large", 1), ("swim_large", 2),
     ("crouch_large", 0), ("proj_large", 0)],
    # Enemies
    [("goomba", 0), ("goomba_stomped", 0),
     ("koopa", 0), ("koopa", 1), ("koopa_para", 0), ("koopa_para", 1),
     ("buzzy", 0), ("buzzy", 1),
     ("spiny", 0), ("spiny", 1), ("spiny_egg", 0), ("spiny_egg", 1)],
    # Special enemies
    [("hammer_bro_a", 0), ("hammer_bro_a", 1), ("hammer_bro_b", 0), ("hammer_bro_b", 1),
     ("lakitu", 0), ("lakitu_duck", 0),
     ("piranha", 0), ("piranha", 1),
     ("blooper", 0), ("blooper", 1),
     ("cheep", 0), ("cheep", 1),
     ("podoboo", 0), ("bullet", 0)],
    # Shells
    #removed buzzy_stun_flip, koopa_sun_flip, and buzzy_stun_1 because they seemed the same
    [("koopa_stun", 0), ("koopa_stun", 1),
     ("buzzy_stun", 0)],
    # Items & NPCs
    # removed spring from here.
     [("princess", 0), ("toad", 0)],
    # Bowser (combined head + body)
    [("bowser", 0), ("bowser", 1), ("bowser", 2), ("bowser", 3)],
]


def _align8(val: int) -> int:
    return (val + 7) // 8 * 8


def build_master_spritesheet(all_frames: dict) -> Image.Image:
    """Lay out every sprite frame in an organized grid, 8x8-aligned.

    Every sprite's (x, y) position is a multiple of 8 and the final sheet
    dimensions are divisible by 8, matching NES CHR 8x8 tile alignment.
    """
    row_metrics = []
    for row in SPRITESHEET_ROWS:
        w = sum(_align8(all_frames[n][f].width) for n, f in row)
        h = _align8(max(all_frames[n][f].height for n, f in row))
        row_metrics.append((w, h))

    sheet_w = _align8(max(m[0] for m in row_metrics))
    sheet_h = _align8(sum(m[1] for m in row_metrics))
    sheet = Image.new("RGBA", (sheet_w, sheet_h), (0, 0, 0, 0))

    y = 0
    for row, (_, rh) in zip(SPRITESHEET_ROWS, row_metrics):
        x = 0
        for name, fi in row:
            img = all_frames[name][fi]
            sheet.paste(img, (x, y + rh - img.height), img)
            x += _align8(img.width)
        y += rh

    return sheet


# ---------------------------------------------------------------------------
# Palette slot mapping (which palette slot each sprite uses)
# ---------------------------------------------------------------------------

PLAYER_PALETTE_SLOT = 0

def _actor_palette_slot(anim_name: str) -> int | None:
    """Return the NES palette slot for an actor, or None for custom-palette sprites."""
    anim_def = ACTOR_ANIMATIONS[anim_name]
    if "custom_palette" in anim_def:
        return None
    return anim_def["palette"]


# ---------------------------------------------------------------------------
# Main export pipeline
# ---------------------------------------------------------------------------

def export_all(
    rom_path: pathlib.Path,
    output_dir: pathlib.Path,
    theme: str = "overworld",
    indexed: bool = False,
) -> None:
    import json

    if not indexed and theme not in SPRITE_PALETTES:
        raise ValueError(f"Unknown theme '{theme}'. Choose from: {list(SPRITE_PALETTES)}")

    print(f"Loading CHR ROM from {rom_path} ...")
    chr_data = load_chr_rom(rom_path)
    palettes = SPRITE_PALETTES.get(theme)

    autocrop_names = {"spring_a", "spring_b", "spring_c", "goomba_stomped",
                      "spiny_egg", "spiny"}
    all_frames: dict[str, list[Image.Image]] = {}

    if indexed:
        print("Mode: indexed (palette-index encoding for shader swap)")
    else:
        print(f"Mode: colored (theme={theme})")

    # --- Player sprites ---
    print("Rendering player sprites ...")
    for anim_name, frames in PLAYER_ANIMATIONS.items():
        pal = None if indexed else palettes[PLAYER_PALETTE_SLOT]
        all_frames[anim_name] = [render_frame(ts, chr_data, pal) for ts in frames]
        print(f"  {anim_name}: {len(frames)} frame(s)")

    # --- Actor sprites ---
    print("Rendering actor sprites ...")
    for anim_name, anim_def in ACTOR_ANIMATIONS.items():
        if indexed:
            pal = None
        else:
            pal = anim_def.get("custom_palette") or palettes[anim_def["palette"]]
        rendered = []
        for tile_slots in anim_def["frames"]:
            img = render_frame(tile_slots, chr_data, pal)
            if anim_name in autocrop_names:
                img = crop_transparent_rows(img)
            rendered.append(img)
        all_frames[anim_name] = rendered
        print(f"  {anim_name}: {len(rendered)} frame(s)")

    # --- Compose Bowser (head + body → 32×32) ---
    print("Composing Bowser frames ...")
    all_frames["bowser"] = [
        compose_bowser(all_frames["bowser_mouth_opened"][0], all_frames["bowser_step_right"][0]),
        compose_bowser(all_frames["bowser_mouth_opened"][0], all_frames["bowser_step_left"][0]),
        compose_bowser(all_frames["bowser_mouth_closed"][0], all_frames["bowser_step_right"][0]),
        compose_bowser(all_frames["bowser_mouth_closed"][0], all_frames["bowser_step_left"][0]),
    ]

    # --- Master spritesheet ---
    print("Building master spritesheet ...")
    sheet = build_master_spritesheet(all_frames)
    output_dir.mkdir(parents=True, exist_ok=True)
    sheet_path = output_dir / "spritesheet.png"
    sheet.save(sheet_path)
    print(f"  Saved {sheet_path}  ({sheet.width}×{sheet.height})")

    # --- Sprite metadata ---
    meta: dict = {"mode": "indexed" if indexed else "colored", "sprites": {}}
    if not indexed:
        meta["theme"] = theme
    y = 0
    for row_entries in SPRITESHEET_ROWS:
        rh = _align8(max(all_frames[n][f].height for n, f in row_entries))
        x = 0
        for name, fi in row_entries:
            img = all_frames[name][fi]
            key = name if len(all_frames[name]) == 1 else f"{name}_{fi}"
            entry: dict = {
                "x": x, "y": y + rh - img.height,
                "w": img.width, "h": img.height,
            }
            if indexed:
                if name in PLAYER_ANIMATIONS:
                    entry["palette_slot"] = PLAYER_PALETTE_SLOT
                elif name == "bowser":
                    entry["palette_slot"] = ACTOR_ANIMATIONS["bowser_mouth_opened"]["palette"]
                else:
                    base_name = name
                    for bname in ACTOR_ANIMATIONS:
                        if name == bname or name.startswith(bname):
                            base_name = bname
                            break
                    slot = _actor_palette_slot(base_name)
                    if slot is not None:
                        entry["palette_slot"] = slot
                    else:
                        rgb = [list(NES_PALETTE[c & 0x3F]) for c in ACTOR_ANIMATIONS[base_name]["custom_palette"]]
                        entry["custom_palette_rgb"] = rgb[1:]
            meta["sprites"][key] = entry
            x += _align8(img.width)
        y += rh
    (output_dir / "spritesheet.json").write_text(json.dumps(meta, indent=2))

    # --- Palettes + reference shader (always useful for runtime palette swapping) ---
    _export_palettes_json(output_dir)
    _export_godot_shader(output_dir)

    print(f"\nDone — output saved to {output_dir}/")


def _export_palettes_json(output_dir: pathlib.Path) -> None:
    """Write all theme palettes resolved to RGB for easy engine consumption."""
    import json
    out: dict = {}
    for theme_name, slots in SPRITE_PALETTES.items():
        theme_out = {}
        for slot_idx, slot in enumerate(slots):
            theme_out[str(slot_idx)] = [list(NES_PALETTE[c & 0x3F]) for c in slot[1:]]
        out[theme_name] = theme_out
    path = output_dir / "palettes.json"
    path.write_text(json.dumps(out, indent=2))
    print(f"  Saved {path}")


EXTRA_PALETTES = [
    ("Fire Mario", [0x30, 0x27, 0x16]),
]

SLOT_LABELS = {
    "overworld":    ["Mario", "Green (Koopa/Bowser)", "Red (Spiny/Cheep)", "Dark (Goomba/Buzzy/Bullet)"],
    "underground":  ["Mario", "Gray (Koopa/Bowser)",  "Red (Spiny/Cheep)", "Dark (Goomba/Buzzy/Bullet)"],
    "castle":       ["Mario", "Teal (Koopa/Bowser)",  "Red (Spiny/Cheep)", "Dark (Goomba/Buzzy/Bullet)"],
}


def _collect_shader_palettes() -> list[tuple[str, tuple, tuple, tuple]]:
    """Build the ordered list of (label, c1_rgb, c2_rgb, c3_rgb) for the shader."""
    palettes = []
    for theme_name, slots in SPRITE_PALETTES.items():
        for si, slot in enumerate(slots):
            rgb = [NES_PALETTE[c & 0x3F] for c in slot[1:]]
            palettes.append((f"{theme_name.capitalize()} - {SLOT_LABELS[theme_name][si]}", rgb[0], rgb[1], rgb[2]))
    for label, indices in EXTRA_PALETTES:
        rgb = [NES_PALETTE[c & 0x3F] for c in indices]
        palettes.append((label, rgb[0], rgb[1], rgb[2]))
    for name in ("princess", "toad"):
        custom = ACTOR_ANIMATIONS[name]["custom_palette"]
        rgb = [NES_PALETTE[c & 0x3F] for c in custom[1:]]
        palettes.append((name.capitalize(), rgb[0], rgb[1], rgb[2]))
    return palettes


def _build_godot_shader() -> str:
    """Generate palette swap shader with all presets baked in from palette data."""
    palettes = _collect_shader_palettes()
    n = len(palettes)

    def v3(c):
        return f"vec3({c[0] / 255.0:.3f}, {c[1] / 255.0:.3f}, {c[2] / 255.0:.3f})"

    lines = [
        "shader_type canvas_item;",
        "//READ: spritesheet.png must be in --indexed mode to work with this shader!",
        "",
        "// Palette presets. Set palette_id in the inspector to pick a palette.",
        "// For star power, cycle palette_id through the 4 slots of the current",
        "// theme (e.g. 0-3 for overworld) on a timer in GDScript.",
    ]
    for i, (label, _, _, _) in enumerate(palettes):
        lines.append(f"//   {i:2d} = {label}")
    lines.append(f"uniform int palette_id : hint_range(0, {n - 1}) = 0;")
    lines.append("")
    lines.append(f"const vec3 PAL[{n * 3}] = " + "{")
    for i, (label, c1, c2, c3) in enumerate(palettes):
        sep = "," if i < n - 1 else ""
        lines.append(f"    {v3(c1)}, {v3(c2)}, {v3(c3)}{sep} // {i}: {label}")
    lines.append("};")
    lines.append("")
    lines.append("void fragment() {")
    lines.append("    vec4 tex = texture(TEXTURE, UV);")
    lines.append("    if (tex.a < 0.5) {")
    lines.append("        discard;")
    lines.append("    }")
    lines.append("    int base = palette_id * 3;")
    lines.append("    float r = tex.r;")
    lines.append("    if (r < 0.45) {")
    lines.append("        COLOR = vec4(PAL[base], 1.0);")
    lines.append("    } else if (r < 0.78) {")
    lines.append("        COLOR = vec4(PAL[base + 1], 1.0);")
    lines.append("    } else {")
    lines.append("        COLOR = vec4(PAL[base + 2], 1.0);")
    lines.append("    }")
    lines.append("}")
    lines.append("")
    return "\n".join(lines)


def _export_godot_shader(output_dir: pathlib.Path) -> None:
    path = output_dir / "palette_swap.gdshader"
    path.write_text(_build_godot_shader())
    print(f"  Saved {path}")


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

def main() -> None:
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    flags = {a for a in sys.argv[1:] if a.startswith("--")}
    indexed = "--indexed" in flags

    here = pathlib.Path(__file__).resolve().parent

    rom_path   = pathlib.Path(args[0]) if len(args) > 0 else here / "smb.nes"
    output_dir = pathlib.Path(args[1]) if len(args) > 1 else here / "assets"
    theme      = args[2]               if len(args) > 2 else "overworld"

    if not rom_path.exists():
        print(f"ERROR: ROM not found at {rom_path}")
        print("Usage: python3 smb_sprite_extractor.py [rom.nes] [output_dir] [theme] [--indexed]")
        print("Themes:", ", ".join(SPRITE_PALETTES))
        print("Flags:  --indexed  Export palette-indexed sprites for shader swap")
        sys.exit(1)

    output_dir.mkdir(parents=True, exist_ok=True)
    export_all(rom_path, output_dir, theme, indexed=indexed)


if __name__ == "__main__":
    main()
