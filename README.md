# Super Mario Bros. — Full NES Remake in Godot 4

**This project is work-in-progress.**

*All levels are added to the game, but not all are completely functional.*

Objective: A complete recreation of Super Mario Bros. (1985) built from the ground up in Godot 4.6, covering all 32 levels (World 1-1 through 8-4) with accurate physics, enemies, music, and palette-swap rendering.

<img width="1756" height="1002" alt="1" src="https://github.com/user-attachments/assets/f3b63eea-18fc-46d1-8e01-7a2b09cddc51" />


## Why You Need to Generate Assets

**Note: Do this BEFORE opening the project in Godot.**

This repository **does not include any Nintendo-owned artwork or audio**. The original sprites, tiles, and music are copyrighted material extracted directly from the NES ROM, so distributing them would be illegal.

Instead, the project ships with extraction scripts that read your own legally obtained ROM and NSF files and produce every asset the engine needs. The game code, level data, shaders, and scene structures are all included — you just need to run one script to fill in the textures and audio.

## Prerequisites
- **Python 3.10+** with [Pillow](https://pypi.org/project/Pillow/) (`pip install Pillow`)
- **ffmpeg** in your PATH (for audio generation)
- **smb.nes** — a Super Mario Bros. NES ROM (iNES format)
- **smb.nsf** — the "Super Mario Bros. 1+2+VS+Extra Tracks" NSF from [Zophar's Domain](https://www.zophar.net/music/nintendo-nes-nsf/super-mario-bros-1-2-vs-extra-tracks)

## Setup

### 1. Place your ROM files

Copy both files into the `_gen_assets/` directory:

```
_gen_assets/
├── smb.nes      ← your NES ROM here
└── smb.nsf      ← your NSF file here
```

### 2. Install Python dependencies

```bash
pip install Pillow
```

### 3. Generate assets

From the `_gen_assets/` directory:

```bash
python3 main.py
```

You will see a menu:

```
==================================================
  SMB Godot — Asset Generator
==================================================

  1) Generate sprites  (requires smb.nes + Pillow)
  2) Generate audio    (requires smb.nsf + ffmpeg)
  3) Generate all
  q) Quit
```

Select **3** to generate everything, or run them separately if one step has issues. You can also skip the menu entirely:

```bash
python3 main.py sprites    # sprites only
python3 main.py audio      # audio only
python3 main.py all        # both
```

### 4. Open in Godot

Open the project root folder in Godot 4.6+. The editor will import the generated textures and audio on first launch. The game is ready to run.

## What Gets Generated

**Sprites** (from `smb.nes`):

| Output | Description |
|---|---|
| `assets/textures/chr-mapping.png` | Background tile atlas (pipes, bricks, ground, scenery) |
| `assets/textures/spritesheet.png` | Combined sprite sheet for all characters |
| `assets/textures/player/*.png` | 28 individual player animation frames |
| `assets/textures/enemies/*.png` | 39 individual enemy/NPC animation frames |

All sprite images use palette-index encoding (color stored in the red channel) so the palette-swap shader can recolor them at runtime for different world themes.

**Audio** (from `smb.nsf`):

| Output | Description |
|---|---|
| `assets/music/*.ogg` | 70 per-channel music stems (pulse1, pulse2, triangle, noise) |
| `assets/sfx/*.ogg` | 20 per-channel sound effects |
| `audio_system/audio_data.gd` | Track metadata (durations, channel mapping, loop flags) |

The audio system plays individual NES channels as separate audio streams synchronised in GDScript, reproducing the original 2A03 sound.

## Controls

| Action | Keyboard | Gamepad |
|---|---|---|
| Move | A / D | D-Pad / Left Stick |
| Jump | Space | A |
| Run / Fire | Shift | X |
| Crouch | S | D-Pad Down |
| Start | Enter | Start |

## Project Structure

```
├── _gen_assets/          # Asset generation pipeline
│   ├── main.py           # Entry point — run this
│   ├── data/             # Tile mapping CSV/JSON, palette definitions
│   ├── scripts/          # ROM extraction and sprite rendering modules
│   └── vgm2wav/          # Bundled NSF-to-WAV converter (macOS arm64)
├── assets/               # Generated textures, music, sfx (gitignored)
├── audio_system/         # NES-style 4-channel audio engine
├── data/levels/          # JSON level definitions for all 32 levels
├── player/               # Player controller, sprite frames, atlas
├── scenes/               # Godot scenes (enemies, items, levels, sprites)
├── scripts/              # Game logic, palette shader, physics, autoloads
├── tilesets/              # Tileset resources referencing chr-mapping.png
└── ui/                   # HUD and text rendering
```

## Troubleshooting

**"smb.nsf has N tracks but 41 are needed"** — You have the wrong NSF file. The generator expects the combined "Super Mario Bros. 1+2+VS+Extra Tracks" NSF (41 tracks). Download the correct one from [Zophar's Domain](https://www.zophar.net/music/nintendo-nes-nsf/super-mario-bros-1-2-vs-extra-tracks).

**"ROM not found" / "not a valid iNES ROM"** — Make sure `smb.nes` is a standard iNES-format ROM placed directly in the `_gen_assets/` directory.

**"ffmpeg not found"** — Install ffmpeg (`brew install ffmpeg` on macOS, `apt install ffmpeg` on Linux, or download from [ffmpeg.org](https://ffmpeg.org/download.html)).

**vgm2wav for Linux/Windows???** — The bundled `vgm2wav` binary is compiled for macOS arm64. I will have to build it for other platforms. For now, build it from the [project fork](https://github.com/aydendevnova/vgm2wav) and place the binary and `libgme` library in `_gen_assets/vgm2wav/`.

## Related Repositories

The extraction scripts and data bundled in `_gen_assets/` were built using the following tools, each documented in their own repository:

- **[smb-tileset-assembler](https://github.com/aydendevnova/smb-tileset-assembler)** — Generates the `chr-mapping.csv`/`.json` tile map that defines how raw CHR-ROM tiles are arranged into the background atlas (`chr-mapping.png`). Documents the full process of mapping NES nametable data to a usable tileset.

- **[smb-sprites-extractor](https://github.com/aydendevnova/smb-sprites-extractor)** — Extracts player and enemy sprites from the NES ROM using layout data derived from the SMB disassembly. Produces palette-indexed PNGs and the master spritesheet.

- **[smb-level-extractor](https://github.com/aydendevnova/smb-level-extractor)** — Automates level creation by extracting object and enemy placement data from the ROM and converting it into the JSON level definitions used by `data/levels/`.

- **[vgm2wav](https://github.com/aydendevnova/vgm2wav)** — Fork of vgm2wav with fixes specific to this project. Renders individual NES audio channels from NSF files to WAV for conversion to OGG.

## License

The game engine code, level data, shaders, and tooling in this repository are provided as-is for educational and preservation purposes. Nintendo owns all rights to Super Mario Bros. — this project does not distribute any copyrighted assets.
