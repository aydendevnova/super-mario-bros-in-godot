#!/usr/bin/env python3
"""
Extract CHR-ROM tiles from an iNES (.nes) ROM and render them as a PNG image.

Usage: python chr_extract.py <rom.nes> [out.png]

Requires: Pillow  (pip install pillow)
No py65emu or numpy needed.
"""

import sys
import struct
from pathlib import Path

from PIL import Image

INES_MAGIC = b"NES\x1a"
HEADER_SIZE = 16
PRG_PAGE = 16 * 1024   # 16 KB
CHR_PAGE =  8 * 1024   #  8 KB

# Grayscale palette for the 4 color indices (0-3)
PALETTE = [
    (0x00, 0x00, 0x00),   # 0 – transparent / background (black)
    (0x55, 0x55, 0x55),   # 1 – dark grey
    (0xaa, 0xaa, 0xaa),   # 2 – light grey
    (0xff, 0xff, 0xff),   # 3 – white
]

TILES_PER_ROW = 16   # tiles drawn per row in the output sheet
TILE_SIZE     =  8   # pixels per tile side


def parse_header(data: bytes) -> tuple[int, int]:
    """Return (prg_pages, chr_pages) from a 16-byte iNES header."""
    if data[:4] != INES_MAGIC:
        sys.exit("Not an iNES file (bad magic bytes)")
    prg_pages = data[4]
    chr_pages = data[5]
    return prg_pages, chr_pages


def extract_chr(rom: bytes) -> bytes:
    """Slice the CHR-ROM block out of the ROM."""
    prg_pages, chr_pages = parse_header(rom[:HEADER_SIZE])
    if chr_pages == 0:
        sys.exit("ROM uses CHR-RAM (no CHR-ROM present in file)")

    chr_start = HEADER_SIZE + prg_pages * PRG_PAGE
    chr_end   = chr_start   + chr_pages * CHR_PAGE
    return rom[chr_start:chr_end]


def decode_tile(tile_bytes: bytes) -> list[list[int]]:
    """
    Decode one 16-byte NES tile into an 8x8 grid of color indices (0-3).

    Each tile has two 8-byte bitplanes:
      plane 0 (bytes 0-7)  → low bit of color index
      plane 1 (bytes 8-15) → high bit of color index
    """
    rows = []
    for row in range(8):
        lo = tile_bytes[row]
        hi = tile_bytes[row + 8]
        pixels = []
        for bit in range(7, -1, -1):
            color = ((hi >> bit) & 1) << 1 | ((lo >> bit) & 1)
            pixels.append(color)
        rows.append(pixels)
    return rows


def render_chr_sheet(chr_data: bytes) -> Image.Image:
    """Render all CHR tiles onto a single palette image."""
    num_tiles = len(chr_data) // 16
    num_cols  = TILES_PER_ROW
    num_rows  = (num_tiles + num_cols - 1) // num_cols

    img_w = num_cols * TILE_SIZE
    img_h = num_rows * TILE_SIZE
    img   = Image.new("RGB", (img_w, img_h), PALETTE[0])
    pixels = img.load()

    for tile_idx in range(num_tiles):
        tile_bytes = chr_data[tile_idx * 16 : tile_idx * 16 + 16]
        tile_grid  = decode_tile(tile_bytes)

        tile_col = tile_idx % num_cols
        tile_row = tile_idx // num_cols
        ox = tile_col * TILE_SIZE
        oy = tile_row * TILE_SIZE

        for r, row_pixels in enumerate(tile_grid):
            for c, color_idx in enumerate(row_pixels):
                pixels[ox + c, oy + r] = PALETTE[color_idx]

    return img


def main():
    if len(sys.argv) < 2:
        # Support ../smb.nes (output in ../), smb.nes (output here ./)
        default_rom = Path("../smb.nes")
        default_rom_local = Path("smb.nes")
        if default_rom.exists():
            sys.argv.append(str(default_rom.resolve()))
            out_dir = default_rom.parent.resolve()
        elif default_rom_local.exists():
            sys.argv.append(str(default_rom_local.resolve()))
            out_dir = Path(".").resolve()
        else:
            print(f"Usage: {sys.argv[0]} <rom.nes> [out.png]", file=sys.stderr)
            sys.exit(1)

    rom_path = Path(sys.argv[1])
    out_path = Path(sys.argv[2]) if len(sys.argv) > 2 else rom_path.with_suffix(".chr.png")

    rom      = rom_path.read_bytes()
    chr_data = extract_chr(rom)

    prg_pages, chr_pages = parse_header(rom[:HEADER_SIZE])
    num_tiles = len(chr_data) // 16
    print(f"PRG-ROM: {prg_pages} × 16 KB = {prg_pages * 16} KB")
    print(f"CHR-ROM: {chr_pages} ×  8 KB = {chr_pages *  8} KB  ({num_tiles} tiles)")

    img = render_chr_sheet(chr_data)
    img.save(out_path)
    print(f"Saved → {out_path}  ({img.width}×{img.height} px)")


if __name__ == "__main__":
    main()
