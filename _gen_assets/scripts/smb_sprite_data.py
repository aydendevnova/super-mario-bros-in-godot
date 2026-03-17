"""
smb_sprite_data.py

Baked sprite layout data extracted from the smb-master disassembly.
Each animation is a list of frames; each frame is a list of tile slots.
A tile slot is (tile_index, is_bg_tile) or None for a transparent slot.
  tile_index  — 0-255 index within the OBJ or BG half of the CHR ROM
  is_bg_tile  — False = OBJ CHR (first 4KB), True = BG CHR (second 4KB)

Layout for player:  2 cols x 4 rows = 16x32 px per frame
Layout for actors:  2 cols x 3 rows = 16x24 px per frame (most actors)
Tiles read left-to-right, top-to-bottom.

Generated from smb-master disassembly — no ROM bytes included.
"""

# ---------------------------------------------------------------------------
# Player (Mario) animations
# 8 tiles per frame: [row0_left, row0_right, row1_left, row1_right, ...]
# ---------------------------------------------------------------------------
PLAYER_ANIMATIONS = {
    # walk_large
    'walk_large': [
        [(0, False), (1, False), (2, False), (3, False), (4, False), (5, False), (6, False), (7, False)],
        [(8, False), (9, False), (10, False), (11, False), (12, False), (13, False), (14, False), (15, False)],
        [(16, False), (17, False), (18, False), (19, False), (20, False), (21, False), (22, False), (23, False)],
    ],
    # skid_large
    'skid_large': [
        [(24, False), (25, False), (26, False), (27, False), (28, False), (29, False), (30, False), (31, False)],
    ],
    # jump_large
    'jump_large': [
        [(32, False), (33, False), (34, False), (35, False), (36, False), (37, False), (38, False), (39, False)],
    ],
    # swim_large
    'swim_large': [
        [(8, False), (9, False), (40, False), (41, False), (42, False), (43, False), (44, False), (45, False)],
        [(8, False), (9, False), (10, False), (11, False), (12, False), (48, False), (44, False), (45, False)],
        [(8, False), (9, False), (10, False), (11, False), (46, False), (47, False), (44, False), (45, False)],
    ],
    # climb_large
    'climb_large': [
        [(8, False), (9, False), (40, False), (41, False), (42, False), (43, False), (92, False), (93, False)],
        [(8, False), (9, False), (10, False), (11, False), (12, False), (13, False), (94, False), (95, False)],
    ],
    # crouch_large
    'crouch_large': [
        [(252, False), (252, False), (8, False), (9, False), (88, False), (89, False), (90, False), (90, False)],
    ],
    # proj_large
    'proj_large': [
        [(8, False), (9, False), (40, False), (41, False), (42, False), (43, False), (14, False), (15, False)],
    ],
    # walk_small
    'walk_small': [
        [(252, False), (252, False), (252, False), (252, False), (50, False), (51, False), (52, False), (53, False)],
        [(252, False), (252, False), (252, False), (252, False), (54, False), (55, False), (56, False), (57, False)],
        [(252, False), (252, False), (252, False), (252, False), (58, False), (55, False), (59, False), (60, False)],
    ],
    # skid_small
    'skid_small': [
        [(252, False), (252, False), (252, False), (252, False), (61, False), (62, False), (63, False), (64, False)],
    ],
    # jump_small
    'jump_small': [
        [(252, False), (252, False), (252, False), (252, False), (50, False), (65, False), (66, False), (67, False)],
    ],
    # swim_small
    'swim_small': [
        [(252, False), (252, False), (252, False), (252, False), (50, False), (51, False), (68, False), (69, False)],
        [(252, False), (252, False), (252, False), (252, False), (50, False), (51, False), (68, False), (71, False)],
        [(252, False), (252, False), (252, False), (252, False), (50, False), (51, False), (72, False), (73, False)],
    ],
    # climb_small
    'climb_small': [
        [(252, False), (252, False), (252, False), (252, False), (50, False), (51, False), (144, False), (145, False)],
        [(252, False), (252, False), (252, False), (252, False), (58, False), (55, False), (146, False), (147, False)],
    ],
    # death_small
    'death_small': [
        [(252, False), (252, False), (252, False), (252, False), (158, False), (158, False), (159, False), (159, False)],
    ],
    # stand_small
    'stand_small': [
        [(252, False), (252, False), (252, False), (252, False), (58, False), (55, False), (79, False), (79, False)],
    ],
    # stand_medium
    'stand_medium': [
        [(252, False), (252, False), (0, False), (1, False), (76, False), (77, False), (78, False), (78, False)],
    ],
    # stand_large
    'stand_large': [
        [(0, False), (1, False), (76, False), (77, False), (74, False), (74, False), (75, False), (75, False)],
    ],
}

# ---------------------------------------------------------------------------
# Actor (enemy / item) animations
# 6 tiles per frame for most; some multi-tile actors have more.
# ---------------------------------------------------------------------------
ACTOR_ANIMATIONS = {
    # buzzy  (palette slot 3)
    'buzzy': {
        "palette": 3,
        "frames": [
            [(252, False), (252, False), (170, False), (171, False), (172, False), (173, False)],
            [(252, False), (252, False), (174, False), (175, False), (176, False), (177, False)],
        ],
    },
    # koopa  (palette slot 1)
    'koopa': {
        "palette": 1,
        "frames": [
            [(252, False), (165, False), (166, False), (167, False), (168, False), (169, False)],
            [(252, False), (160, False), (161, False), (162, False), (163, False), (164, False)],
        ],
    },
    # koopa_para  (palette slot 1)
    'koopa_para': {
        "palette": 1,
        "frames": [
            [(105, False), (165, False), (106, False), (167, False), (168, False), (169, False)],
            [(107, False), (160, False), (108, False), (162, False), (163, False), (164, False)],
        ],
    },
    # spiny  (palette slot 2)
    'spiny': {
        "palette": 2,
        "frames": [
            [(252, False), (252, False), (150, False), (151, False), (152, False), (153, False)],
            [(252, False), (252, False), (154, False), (155, False), (156, False), (157, False)],
        ],
    },
    # spiny_egg  (palette slot 2)
    # Game: color_mod_2=2 swaps tile pairs + sets h_flip on all OAM entries.
    # Post-render fixup (state_5) strips h_flip from left column, adds v_flip to right column.
    # Final: left col = no flip, right col = h_flip + v_flip (180° rotation → ball symmetry)
    'spiny_egg': {
        "palette": 2,
        "frames": [
            [(252, False), (252, False), (142, False, False), (143, False, True, True), (143, False, False), (142, False, True, True)],
            [(252, False), (252, False), (148, False, False), (149, False, True, True), (149, False, False), (148, False, True, True)],
        ],
    },
    # blooper  (palette slot 3)
    'blooper': {
        "palette": 3,
        "frames": [
            [(252, False), (252, False), (220, False), (220, False), (223, False), (223, False)],
            [(220, False), (220, False), (221, False), (221, False), (222, False), (222, False)],
        ],
    },
    # cheep  (palette slot 1)
    'cheep': {
        "palette": 1,
        "frames": [
            [(252, False), (252, False), (178, False), (179, False), (180, False), (181, False)],
            [(252, False), (252, False), (182, False), (179, False), (183, False), (181, False)],
        ],
    },
    # goomba  (palette slot 3)
    'goomba': {
        "palette": 3,
        "frames": [
            [(252, False), (252, False), (112, False), (113, False), (114, False), (115, False)],
        ],
    },
    # koopa_stun_flip  (palette slot 1)
    'koopa_stun_flip': {
        "palette": 1,
        "frames": [
            [(252, False), (252, False), (110, False), (110, False), (111, False), (111, False)],
            [(252, False), (252, False), (109, False), (109, False), (111, False), (111, False)],
        ],
    },
    # koopa_stun  (palette slot 1)
    # In-game rendered with v_flip; swap non-empty rows so top half appears on top.
    'koopa_stun': {
        "palette": 1,
        "frames": [
            [(252, False), (252, False), (110, False), (110, False), (111, False), (111, False)],
            [(252, False), (252, False), (109, False), (109, False), (111, False), (111, False)],
        ],
    },
    # buzzy_stun_flip  (palette slot 3)
    # In-game rendered with v_flip; swap non-empty rows to match buzzy_stun row order.
    'buzzy_stun_flip': {
        "palette": 3,
        "frames": [
            [(252, False), (252, False), (245, False), (245, False), (244, False), (244, False)],
            [(252, False), (252, False), (245, False), (245, False), (244, False), (244, False)],
        ],
    },
    # buzzy_stun  (palette slot 3)
    'buzzy_stun': {
        "palette": 3,
        "frames": [
            [(252, False), (252, False), (245, False), (245, False), (244, False), (244, False)],
            [(252, False), (252, False), (245, False), (245, False), (244, False), (244, False)],
        ],
    },
    # goomba_stomped  (palette slot 3)
    # Tile is stored face-up; stomped goomba shows feet-up (squished from above) → v_flip.
    # Right tile is same-tile h_flip (symmetric squish). Format: (tile, is_bg, h_flip, v_flip)
    'goomba_stomped': {
        "palette": 3,
        "frames": [
            [(252, False), (252, False), (252, False), (252, False), (239, False, False, True), (239, False, True, True)],
        ],
    },
    # lakitu  (palette slot 1)
    'lakitu': {
        "palette": 1,
        "frames": [
            [(185, False), (184, False), (187, False), (186, False), (188, False), (188, False)],
        ],
    },
    # lakitu_duck  (palette slot 1)
    'lakitu_duck': {
        "palette": 1,
        "frames": [
            [(252, False), (252, False), (189, False), (189, False), (188, False), (188, False)],
        ],
    },
    # princess  (ending scene palette: transparent, peach-skin, red, white)
    'princess': {
        "palette": 3,
        "custom_palette": [0x0F, 0x27, 0x16, 0x30],
        "frames": [
            # SMBV1 tiles only: princess_a+0, princess_a+1, princess_c+0, princess_c+1, princess_b+0 (×2)
            [(122, False), (123, False), (218, False), (219, False), (216, False), (216, False)],
        ],
    },
    # toad  (ending scene palette: transparent, white, red, peach-skin)
    'toad': {
        "palette": 3,
        "custom_palette": [0x0F, 0x30, 0x16, 0x27],
        "frames": [
            # SMB branch only: toad+0 (×2), toad+1 (×2), toad+2 (×2)
            [(205, False), (205, False), (206, False), (206, False), (207, False), (207, False)],
        ],
    },
    # hammer_bro_a  (palette slot 1)
    'hammer_bro_a': {
        "palette": 1,
        "frames": [
            [(125, False), (124, False), (209, False), (140, False), (211, False), (210, False)],
            [(125, False), (124, False), (137, False), (136, False), (139, False), (138, False)],
        ],
    },
    # hammer_bro_b  (palette slot 1)
    'hammer_bro_b': {
        "palette": 1,
        "frames": [
            [(213, False), (212, False), (227, False), (226, False), (211, False), (210, False)],
            [(213, False), (212, False), (227, False), (226, False), (139, False), (138, False)],
        ],
    },
    # piranha  (palette slot 1)
    'piranha': {
        "palette": 1,
        "frames": [
            [(229, False), (229, False), (230, False), (230, False), (235, False), (235, False)],
            [(236, False), (236, False), (237, False), (237, False), (238, False), (238, False), (235, False), (235, False)],
        ],
    },
    # podoboo  (palette slot 2)
    'podoboo': {
        "palette": 2,
        "frames": [
            [(252, False), (252, False), (208, False), (208, False), (215, False), (215, False)],
        ],
    },
    # bowser_mouth_opened  (palette slot 1)
    'bowser_mouth_opened': {
        "palette": 1,
        "frames": [
            [(191, False), (190, False), (193, False), (192, False), (194, False), (252, False)],
        ],
    },
    # bowser_step_right  (palette slot 1)
    'bowser_step_right': {
        "palette": 1,
        "frames": [
            [(196, False), (195, False), (198, False), (197, False), (200, False), (199, False)],
        ],
    },
    # bowser_mouth_closed  (palette slot 1)
    'bowser_mouth_closed': {
        "palette": 1,
        "frames": [
            [(191, False), (190, False), (202, False), (201, False), (194, False), (252, False)],
        ],
    },
    # bowser_step_left  (palette slot 1)
    'bowser_step_left': {
        "palette": 1,
        "frames": [
            [(196, False), (195, False), (198, False), (197, False), (204, False), (203, False)],
        ],
    },
    # bullet  (palette slot 3)
    'bullet': {
        "palette": 3,
        "frames": [
            [(252, False), (252, False), (232, False), (231, False), (234, False), (233, False)],
        ],
    },
    # spring_a  (palette slot 2)
    # Post-render fixup for id >= swarm_stop: rows 1-2 get v_flip (left) and h_flip+v_flip (right)
    'spring_a': {
        "palette": 2,
        "frames": [
            [(242, False), (242, False), (243, False, False, True), (243, False, True, True), (242, False, False, True), (242, False, True, True)],
        ],
    },
    # spring_b  (palette slot 2)
    'spring_b': {
        "palette": 2,
        "frames": [
            [(241, False), (241, False), (241, False, False, True), (241, False, True, True), (252, False), (252, False)],
        ],
    },
    # spring_c  (palette slot 2)
    'spring_c': {
        "palette": 2,
        "frames": [
            [(240, False), (240, False), (252, False), (252, False), (252, False), (252, False)],
        ],
    },
}