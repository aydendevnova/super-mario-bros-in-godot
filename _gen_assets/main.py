#!/usr/bin/env python3
"""
Asset generation pipeline for the SMB Godot project.

Options:
    1) Generate sprites  — requires smb.nes + Pillow
    2) Generate audio    — requires smb.nsf + vgm2wav (bundled) + ffmpeg

Usage:
    python3 main.py            (interactive menu)
    python3 main.py sprites    (skip menu, run sprites only)
    python3 main.py audio      (skip menu, run audio only)
    python3 main.py all        (skip menu, run both)
"""

import csv
import json
import math
import os
import pathlib
import shutil
import subprocess
import sys

HERE = pathlib.Path(__file__).resolve().parent
PROJECT_ROOT = HERE.parent
DATA_DIR = HERE / "data"

ROM_PATH = HERE / "smb.nes"
NSF_PATH = HERE / "smb.nsf"
VGM2WAV_DIR = HERE / "vgm2wav"
VGM2WAV_PATH = VGM2WAV_DIR / "vgm2wav"

TEXTURES_OUT = PROJECT_ROOT / "assets" / "textures"
MUSIC_OUT = PROJECT_ROOT / "assets" / "music"
SFX_OUT = PROJECT_ROOT / "assets" / "sfx"
AUDIO_DATA_OUT = PROJECT_ROOT / "audio_system" / "audio_data.gd"

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
# AUDIO
# ═══════════════════════════════════════════════════════════════════════════

CHANNELS = [
    {"name": "pulse1",   "select": 0},
    {"name": "pulse2",   "select": 1},
    {"name": "triangle", "select": 2},
    {"name": "noise",    "select": 3},
    {"name": "dmc",      "select": 4},
]
CHANNELS_BY_SELECT = {ch["select"]: ch for ch in CHANNELS}

TRACKS = [
    {"name": "overworld_bgm",             "file": "overworld_bgm",             "group": "music", "duration": 38.3,  "voices": [0, 1, 2, 3], "loop": True},
    {"name": "underwater_bgm",            "file": "underwater_bgm",            "group": "music", "duration": 25.56, "voices": [0, 1, 2, 3], "loop": True},
    {"name": "underground_bgm",           "file": "underground_bgm",           "group": "music", "duration": 12.6,  "voices": [1, 2],       "loop": True},
    {"name": "course_clear_fanfare",      "file": "course_clear_fanfare",      "group": "music", "duration": 6,     "voices": [0, 1, 2],    "loop": False},
    {"name": "castle_bgm",                "file": "castle_bgm",                "group": "music", "duration": 7.99,  "voices": [0, 1, 2],    "loop": True},
    {"name": "world_clear_fanfare",       "file": "world_clear_fanfare",       "group": "music", "duration": 5.5,   "voices": [0, 1, 2],    "loop": False},
    {"name": "invincible_bgm",            "file": "invincible_bgm",            "group": "music", "duration": 6.44,  "voices": [0, 1, 2, 3], "loop": True},
    {"name": "scene_change_bgm",          "file": "scene_change_bgm",          "group": "music", "duration": 2.5,   "voices": [0, 1, 2, 3], "loop": False},
    {"name": "time_up_warning_sound",     "file": "time_up_warning_sound",     "group": "music", "duration": 3,     "voices": [0, 1, 2],    "loop": False},
    {"name": "overworld_bgm_hurry_up",    "file": "overworld_bgm_hurry_up",    "group": "music", "duration": 25.56, "voices": [0, 1, 2, 3], "loop": True},
    {"name": "underwater_bgm_hurry_up",   "file": "underwater_bgm_hurry_up",   "group": "music", "duration": 19.18, "voices": [0, 1, 2, 3], "loop": True},
    {"name": "underground_bgm_hurry_up",  "file": "underground_bgm_hurry_up",  "group": "music", "duration": 8.4,   "voices": [1, 2],       "loop": True},
    {"name": "castle_bgm_hurry_up",       "file": "castle_bgm_hurry_up",       "group": "music", "duration": 6.4,   "voices": [0, 1, 2],    "loop": True},
    {"name": "invincible_bgm_hurry_up",   "file": "invincible_bgm_hurry_up",   "group": "music", "duration": 3.2,   "voices": [0, 1, 2, 3], "loop": True},
    {"name": "player_down",               "file": "player_down",               "group": "music", "duration": 2.6,   "voices": [0, 1, 2],    "loop": False},
    {"name": "game_over",                 "file": "game_over",                 "group": "music", "duration": 3.6,   "voices": [0, 1, 2],    "loop": False},
    {"name": "smb_ending_bgm",            "file": "smb_ending_bgm",            "group": "music", "duration": 6.4,   "voices": [0, 1, 2],    "loop": False},
    {"name": "vs_smb_ending_bgm",         "file": "vs_smb_ending_bgm",         "group": "music", "duration": 6.4,   "voices": [0, 1, 2],    "loop": False},
    {"name": "worker_mario_name_entry",   "file": "worker_mario_name_entry",   "group": "music", "duration": 7.2,   "voices": [0, 1, 2, 3], "loop": False},
    {"name": "game_over_unused",          "file": "game_over_unused",          "group": "music", "duration": 3.2,   "voices": [0, 1, 2],    "loop": False},
    {"name": "smb2_ending_bgm",           "file": "smb2_ending_bgm",           "group": "music", "duration": 7.2,   "voices": [0, 1, 2, 3], "loop": False},
    {"name": "pause",                     "file": "sfx_1",  "group": "sfx", "duration": 0.65, "voices": [0]},
    {"name": "brick_smash",               "file": "sfx_2",  "group": "sfx", "duration": 0.5,  "voices": [3]},
    {"name": "bowsers_fire",              "file": "sfx_3",  "group": "sfx", "duration": 1.1,  "voices": [3]},
    {"name": "sfx_4",                     "file": "sfx_4",  "group": "sfx", "duration": 0.15, "voices": [2]},
    {"name": "coin",                      "file": "sfx_5",  "group": "sfx", "duration": 0.9,  "voices": [1]},
    {"name": "powerup_appears",           "file": "sfx_6",  "group": "sfx", "duration": 0.55, "voices": [1]},
    {"name": "vine_growing",              "file": "sfx_7",  "group": "sfx", "duration": 0.65, "voices": [1]},
    {"name": "fireworks",                 "file": "sfx_8",  "group": "sfx", "duration": 0.43, "voices": [1]},
    {"name": "select",                    "file": "sfx_9",  "group": "sfx", "duration": 0.15, "voices": [1]},
    {"name": "power_up",                  "file": "sfx_10", "group": "sfx", "duration": 1,    "voices": [1]},
    {"name": "one_up",                    "file": "sfx_11", "group": "sfx", "duration": 0.84, "voices": [1]},
    {"name": "bowser_falls",              "file": "sfx_12", "group": "sfx", "duration": 1,    "voices": [1]},
    {"name": "jump_small",               "file": "sfx_13", "group": "sfx", "duration": 0.6,  "voices": [0]},
    {"name": "jump_super",               "file": "sfx_14", "group": "sfx", "duration": 0.6,  "voices": [0]},
    {"name": "bump",                     "file": "sfx_15", "group": "sfx", "duration": 0.5,  "voices": [0]},
    {"name": "stomp",                    "file": "sfx_16", "group": "sfx", "duration": 0.3,  "voices": [0]},
    {"name": "kick",                     "file": "sfx_17", "group": "sfx", "duration": 0.2,  "voices": [0]},
    {"name": "pipe",                     "file": "sfx_18", "group": "sfx", "duration": 0.8,  "voices": [0]},
    {"name": "fireball",                 "file": "sfx_19", "group": "sfx", "duration": 0.1,  "voices": [0]},
    {"name": "down_the_flagpole",        "file": "sfx_20", "group": "sfx", "duration": 2,    "voices": [0]},
]

SAMPLE_RATE = 44100


def _run_cmd(cmd: list[str], timeout: float | None = None) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, check=True, timeout=timeout, capture_output=True, text=True)


def _resolve_ffmpeg() -> str:
    path = shutil.which("ffmpeg")
    if path:
        return path
    raise SystemExit(
        "ERROR: ffmpeg not found in PATH.\n"
        "Install ffmpeg (brew install ffmpeg / apt install ffmpeg) and try again."
    )


def _resolve_ogg_codec(ffmpeg: str) -> tuple[list[str], bool]:
    """Returns (codec_args, supports_mono)."""
    result = subprocess.run(
        [ffmpeg, "-hide_banner", "-encoders"],
        capture_output=True, text=True, check=True,
    )
    encoders = result.stdout
    if " libvorbis " in encoders or encoders.rstrip().endswith(" libvorbis"):
        return ["-c:a", "libvorbis", "-q:a", "5"], True
    if " vorbis " in encoders or encoders.rstrip().endswith(" vorbis"):
        return ["-strict", "-2", "-c:a", "vorbis", "-q:a", "5"], False
    raise SystemExit("ERROR: ffmpeg has no usable Vorbis encoder (need libvorbis or vorbis).")


def _render_track(
    *,
    track_index: int,
    duration: float,
    track_name: str,
    ffmpeg: str,
    ogg_codec_args: list[str],
    ogg_supports_mono: bool,
    channel_select: int,
    channel_name: str,
    out_dest: pathlib.Path,
) -> None:
    """Render one channel of one track.

    Runs vgm2wav from inside VGM2WAV_DIR using relative paths (the binary
    is sensitive to path format).  The NSF must already be copied into that
    directory.  The finished .ogg is moved to out_dest afterwards.
    """
    render_secs = math.ceil(duration)
    wav_name = f".tmp_{track_name}_{channel_name}_{os.getpid()}.wav"
    ogg_name = f"{track_name}__{channel_name}.ogg"

    vgm_cmd = [
        "./vgm2wav",
        "-i", "smb.nsf",
        "-o", wav_name,
        "-t", str(render_secs),
        "-r", str(track_index),
        "-s", str(channel_select),
    ]

    end_sample = int(round(duration * SAMPLE_RATE))
    af = f"atrim=end_sample={end_sample},asetpts=PTS-STARTPTS"

    ffmpeg_cmd = [
        ffmpeg, "-y", "-v", "error",
        "-i", wav_name,
        "-af", af,
    ]
    if ogg_supports_mono:
        ffmpeg_cmd += ["-ac", "1"]
    ffmpeg_cmd += [*ogg_codec_args, ogg_name]

    print(f"  rendering {track_name}__{channel_name} (track {track_index}, voice {channel_select}, {render_secs}s) ...")

    work_dir = str(VGM2WAV_DIR)
    wav_path = VGM2WAV_DIR / wav_name
    ogg_path = VGM2WAV_DIR / ogg_name

    try:
        result = subprocess.run(vgm_cmd, check=True, timeout=90,
                                capture_output=True, text=True, cwd=work_dir)
        if result.stderr:
            print(f"    vgm2wav stderr: {result.stderr.strip()}")

        result = subprocess.run(ffmpeg_cmd, check=True, timeout=90,
                                capture_output=True, text=True, cwd=work_dir)
        if result.stderr:
            print(f"    ffmpeg stderr: {result.stderr.strip()}")
    except subprocess.TimeoutExpired:
        print(f"    TIMEOUT rendering {track_name}__{channel_name} — skipping")
        return
    except subprocess.CalledProcessError as exc:
        print(f"    FAILED {track_name}__{channel_name} (exit={exc.returncode}): {exc.stderr or ''}")
        return
    finally:
        if wav_path.exists():
            wav_path.unlink()

    if not ogg_path.exists():
        print(f"    WARNING: no output produced for {ogg_name}")
        return

    out_dest.parent.mkdir(parents=True, exist_ok=True)
    shutil.move(str(ogg_path), str(out_dest))

    size_kb = out_dest.stat().st_size / 1024
    print(f"    -> {ogg_name} ({size_kb:.0f} KB)")


def _generate_audio_data_gd() -> None:
    lines = [
        "# AUTO-GENERATED by _gen_assets/main.py — do not edit manually",
        "class_name AudioData",
        "",
        'const CHANNEL_NAMES: PackedStringArray = ["pulse1", "pulse2", "triangle", "noise"]',
        "",
        "const TRACKS := {",
    ]
    for track in TRACKS:
        voices = ", ".join(str(v) for v in track["voices"])
        loop = track.get("loop", False)
        lines.append(
            f'\t"{track["name"]}": {{"group": "{track["group"]}", '
            f'"duration": {track["duration"]}, "voices": [{voices}], '
            f'"loop": {"true" if loop else "false"}}},'
        )
    lines.append("}")
    lines.append("")
    AUDIO_DATA_OUT.parent.mkdir(parents=True, exist_ok=True)
    AUDIO_DATA_OUT.write_text("\n".join(lines))
    print(f"Generated {AUDIO_DATA_OUT}")


def _validate_nsf(path: pathlib.Path) -> bool:
    """Check that the NSF has enough tracks for all entries in TRACKS."""
    data = path.read_bytes()
    if len(data) < 0x80 or data[:5] != b"NESM\x1a":
        print(f"ERROR: {path.name} is not a valid NSF file (bad header).")
        return False
    track_count = data[6]
    required = len(TRACKS)
    if track_count < required:
        print(f"ERROR: smb.nsf has {track_count} tracks but {required} are needed.")
        print("       This is likely the wrong NSF. The expected file is the")
        print("       'Super Mario Bros. 1+2+VS+Extra Tracks' NSF from Zophar's Domain")
        return False
    print(f"NSF validated: {track_count} tracks available ({required} needed)")
    return True


def run_audio() -> None:
    # --- Preflight checks ---
    if not NSF_PATH.exists():
        print(f"ERROR: smb.nsf not found at {NSF_PATH}")
        print("Place the Super Mario Bros. NSF file as 'smb.nsf' in the _gen_assets/ directory.")
        print("Download from: https://www.zophar.net/music/nintendo-nes-nsf/super-mario-bros-1-2-vs-extra-tracks")
        return

    if not _validate_nsf(NSF_PATH):
        return

    if not VGM2WAV_PATH.exists():
        print(f"ERROR: vgm2wav binary not found at {VGM2WAV_PATH}")
        return

    if os.name != "nt":
        st = os.stat(VGM2WAV_PATH)
        os.chmod(VGM2WAV_PATH, st.st_mode | 0o111)

    ffmpeg = _resolve_ffmpeg()
    ogg_codec_args, ogg_supports_mono = _resolve_ogg_codec(ffmpeg)

    print(f"Using vgm2wav: {VGM2WAV_DIR}/")
    print(f"Using ffmpeg:  {ffmpeg}")
    print(f"Encoder: {'libvorbis (mono)' if ogg_supports_mono else 'vorbis (stereo fallback)'}")

    # Copy NSF into the vgm2wav working directory so the binary gets a
    # simple relative path (it's picky about path formats).
    nsf_work = VGM2WAV_DIR / "smb.nsf"
    if not nsf_work.exists() or nsf_work.stat().st_mtime < NSF_PATH.stat().st_mtime:
        shutil.copy2(NSF_PATH, nsf_work)

    failed = []
    music_count = 0
    sfx_count = 0

    for idx, track in enumerate(TRACKS):
        print(f"\n[{idx + 1}/{len(TRACKS)}] {track['name']} ({track['group']}, {track['duration']}s)")

        if track["group"] == "music":
            dest_dir = MUSIC_OUT
        else:
            dest_dir = SFX_OUT

        for voice_id in track["voices"]:
            channel = CHANNELS_BY_SELECT[voice_id]
            ogg_name = f"{track['name']}__{channel['name']}.ogg"
            out_dest = dest_dir / ogg_name
            try:
                _render_track(
                    track_index=idx,
                    duration=track["duration"],
                    track_name=track["name"],
                    ffmpeg=ffmpeg,
                    ogg_codec_args=ogg_codec_args,
                    ogg_supports_mono=ogg_supports_mono,
                    channel_select=voice_id,
                    channel_name=channel["name"],
                    out_dest=out_dest,
                )
                if out_dest.exists():
                    if track["group"] == "music":
                        music_count += 1
                    else:
                        sfx_count += 1
            except Exception as exc:
                failed.append(f"{track['name']}__{channel['name']}: {exc}")
                print(f"    ERROR: {exc}")

    # Clean up the NSF copy from the working directory
    if nsf_work.exists():
        nsf_work.unlink()

    # --- Generate audio_data.gd ---
    _generate_audio_data_gd()

    print(f"\n  {music_count} music files -> {MUSIC_OUT}/")
    print(f"  {sfx_count} sfx files -> {SFX_OUT}/")

    if failed:
        print(f"\nWARNING: {len(failed)} track(s) failed:")
        for f in failed:
            print(f"  - {f}")
    else:
        print("\nAudio done — all tracks rendered successfully.")


# ═══════════════════════════════════════════════════════════════════════════
# MENU
# ═══════════════════════════════════════════════════════════════════════════

def main() -> None:
    args = [a.lower() for a in sys.argv[1:]]

    if args:
        if "sprites" in args or "all" in args:
            run_sprites()
        if "audio" in args or "all" in args:
            run_audio()
        if not any(a in ("sprites", "audio", "all") for a in args):
            print("Usage: python3 main.py [sprites|audio|all]")
        return

    print("=" * 50)
    print("  SMB Godot — Asset Generator")
    print("=" * 50)
    print()
    print("  1) Generate sprites  (requires smb.nes + Pillow)")
    print("  2) Generate audio    (requires smb.nsf + ffmpeg)")
    print("  3) Generate all")
    print("  q) Quit")
    print()

    choice = input("Select option: ").strip().lower()

    if choice in ("1", "sprites"):
        run_sprites()
    elif choice in ("2", "audio"):
        run_audio()
    elif choice in ("3", "all"):
        run_sprites()
        run_audio()
    elif choice in ("q", "quit", "exit"):
        print("Bye.")
    else:
        print(f"Unknown option: {choice}")


if __name__ == "__main__":
    main()
