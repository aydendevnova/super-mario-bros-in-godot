# Super Mario Bros. — Full NES Remake in Godot 4

**This project is work-in-progress.**

*All levels are added to the game, but not all are completely functional.*

A complete recreation of Super Mario Bros. (1985) built from the ground up in Godot 4.6, covering all 32 levels (World 1-1 through 8-4) with accurate physics, enemies, music, and palette-swap rendering.

<img width="1756" height="1002" alt="1" src="https://github.com/user-attachments/assets/f3b63eea-18fc-46d1-8e01-7a2b09cddc51" />

## Playing the Game

This repository does not ship with Nintendo's original graphics. The sprites and tiles are copyrighted material, so they cannot be distributed. On first launch the game will prompt you to select a Super Mario Bros. NES ROM file (iNES `.nes` format). The engine extracts the graphics from your ROM and saves them locally — you only need to do this once.

If you skip the ROM prompt, the game will run with magenta placeholder textures.

### Requirements

- **Godot 4.6+**
- **smb.nes** — a legally obtained Super Mario Bros. NES ROM (iNES format)

### Steps

1. Open the project in Godot 4.6+ and run it.
2. When prompted, select your `smb.nes` ROM file.
3. The engine generates all required textures and loads the game. Subsequent launches skip this step automatically.

## Editor Preview (Optional)

The in-engine ROM extractor writes textures to `user://generated/`, so the Godot editor still shows placeholder textures in the scene and sprite inspectors. If you want real sprites visible in the editor, you can overwrite the placeholder PNGs in `assets/textures/` using the bundled Python script.

### Prerequisites

- **Python 3.10+** with [Pillow](https://pypi.org/project/Pillow/) (`pip install Pillow`)

### Generate editor textures

```bash
cd _gen_assets
cp /path/to/your/smb.nes .
python3 main.py sprites
```

After running, reopen the project in Godot so it reimports the updated PNGs. To prevent these local texture changes from appearing in `git status`, run the dev setup script:

```bash
bash scripts/dev_setup.sh    # macOS / Linux
scripts\dev_setup.bat        # Windows
```

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
├── _gen_assets/          # Dev-only Python sprite extractor
│   ├── main.py           # Entry point for editor-preview generation
│   ├── data/             # Tile mapping CSV/JSON, palette definitions
│   └── scripts/          # ROM extraction and sprite rendering modules
├── assets/               # Placeholder textures (overwritten by extractor)
├── audio_system/         # NES-style 4-channel audio engine
├── data/
│   ├── levels/           # JSON level definitions for all 32 levels
│   └── asset_ripper/     # JSON data files for the in-engine ROM extractor
├── player/               # Player controller, sprite frames, atlas
├── scenes/               # Godot scenes (enemies, items, levels, sprites)
├── scripts/              # Game logic, palette shader, physics, autoloads
├── tilesets/             # Tileset resources referencing chr-mapping.png
└── ui/                   # HUD and text rendering
```

## Troubleshooting

**"not a valid iNES ROM"** — The file is not a standard iNES-format ROM, or it is the wrong game. Ensure you are selecting a Super Mario Bros. (1985) ROM with the `.nes` extension.

**Placeholder textures still showing after ROM extraction** — Delete the `user://generated/` directory and relaunch to regenerate. On macOS this is located at `~/Library/Application Support/Godot/app_userdata/MarioRecreation/generated/`.

## Related Repositories

The extraction scripts and data bundled in `_gen_assets/` were built using the following tools, each documented in their own repository:

- **[smb-tileset-assembler](https://github.com/aydendevnova/smb-tileset-assembler)** — Generates the `chr-mapping.csv`/`.json` tile map that defines how raw CHR-ROM tiles are arranged into the background atlas (`chr-mapping.png`). Documents the full process of mapping NES nametable data to a usable tileset.

- **[smb-sprites-extractor](https://github.com/aydendevnova/smb-sprites-extractor)** — Extracts player and enemy sprites from the NES ROM using layout data derived from the SMB disassembly. Produces palette-indexed PNGs and the master spritesheet.

- **[smb-level-extractor](https://github.com/aydendevnova/smb-level-extractor)** — Automates level creation by extracting object and enemy placement data from the ROM and converting it into the JSON level definitions used by `data/levels/`.

## License

The game engine code, level data, shaders, and tooling in this repository are provided as-is for educational and preservation purposes. Nintendo owns all rights to Super Mario Bros. — this project does not distribute any copyrighted assets.
