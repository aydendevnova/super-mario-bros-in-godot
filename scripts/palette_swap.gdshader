shader_type canvas_item;

// Palette presets baked from palettes.json.
// Set palette_id uniform to pick a palette at runtime.
//    0 = Overworld Foreground
//    1 = Underground Foreground
//    2 = Castle Foreground
//    3 = Underwater Foreground
//    4 = Overworld Background
//    5 = Underground Background
//    6 = Castle Background
//    7 = Underwater Background
//    8 = Overworld Gold
//    9 = Underground Gold
//   10 = Castle Gold
//   11 = Underwater Gold
//   12 = Scenery Overworld
//   13 = Scenery Underground
//   14 = Scenery Underwater
//   15 = Scenery Snow
//   16 = Scenery Mushrooms
//   17 = Overworld Atmospheric
//   18 = Underground Atmospheric
//   19 = Underwater Atmospheric
//   20 = Castle Atmospheric
//   21 = Mario
//   22 = Luigi
//   23 = Fire Mario
//   24 = Overworld Enemies
//   25 = Underground Enemies
//   26 = Underwater Enemies
//   27 = Red Enemies
//   28 = Overworld Gold F1
//   29 = Underground Gold F1
//   30 = Castle Gold F1
//   31 = Underwater Gold F1
//   32 = Overworld Gold F2
//   33 = Underground Gold F2
//   34 = Castle Gold F2
//   35 = Underwater Gold F2
//   36 = Dark Enemies (Goomba/Buzzy/Bullet/Blooper)
//   37 = Princess
//   38 = Toad
//   39 = Castle Green Enemies
uniform int palette_id : hint_range(0, 39) = 0;

const vec3 PAL[120] = {
    vec3(0.000, 0.000, 0.000), vec3(0.925, 0.706, 0.690), vec3(0.471, 0.235, 0.000), // 0: Overworld Foreground
    vec3(0.000, 0.196, 0.235), vec3(0.627, 0.839, 0.894), vec3(0.000, 0.400, 0.471), // 1: Underground Foreground
    vec3(0.329, 0.329, 0.329), vec3(0.925, 0.933, 0.925), vec3(0.596, 0.588, 0.596), // 2: Castle Foreground
    vec3(0.000, 0.000, 0.000), vec3(0.925, 0.933, 0.925), vec3(0.596, 0.588, 0.596), // 3: Underwater Foreground
    vec3(0.925, 0.706, 0.690), vec3(0.471, 0.235, 0.000), vec3(0.000, 0.000, 0.000), // 4: Overworld Background
    vec3(0.627, 0.839, 0.894), vec3(0.000, 0.400, 0.471), vec3(0.000, 0.000, 0.000), // 5: Underground Background
    vec3(0.925, 0.933, 0.925), vec3(0.596, 0.588, 0.596), vec3(0.329, 0.329, 0.329), // 6: Castle Background
    vec3(0.659, 0.886, 0.565), vec3(0.031, 0.486, 0.000), vec3(0.000, 0.000, 0.000), // 7: Underwater Background
    vec3(0.831, 0.533, 0.125), vec3(0.471, 0.235, 0.000), vec3(0.000, 0.000, 0.000), // 8: Overworld Gold
    vec3(0.831, 0.533, 0.125), vec3(0.471, 0.235, 0.000), vec3(0.000, 0.400, 0.471), // 9: Underground Gold
    vec3(0.831, 0.533, 0.125), vec3(0.471, 0.235, 0.000), vec3(0.329, 0.329, 0.329), // 10: Castle Gold
    vec3(0.831, 0.533, 0.125), vec3(0.188, 0.196, 0.925), vec3(0.000, 0.000, 0.000), // 11: Underwater Gold
    vec3(0.455, 0.769, 0.000), vec3(0.031, 0.486, 0.000), vec3(0.000, 0.000, 0.000), // 12: Scenery Overworld
    vec3(0.455, 0.769, 0.000), vec3(0.031, 0.486, 0.000), vec3(0.031, 0.227, 0.000), // 13: Scenery Underground
    vec3(0.627, 0.078, 0.392), vec3(0.188, 0.196, 0.925), vec3(0.925, 0.345, 0.706), // 14: Scenery Underwater
    vec3(0.596, 0.588, 0.596), vec3(0.925, 0.933, 0.925), vec3(0.329, 0.329, 0.329), // 15: Scenery Snow
    vec3(0.831, 0.533, 0.125), vec3(0.596, 0.133, 0.125), vec3(0.000, 0.000, 0.000), // 16: Scenery Mushrooms
    vec3(0.925, 0.933, 0.925), vec3(0.298, 0.604, 0.925), vec3(0.000, 0.000, 0.000), // 17: Overworld Atmospheric
    vec3(0.925, 0.933, 0.925), vec3(0.298, 0.604, 0.925), vec3(0.000, 0.400, 0.471), // 18: Underground Atmospheric
    vec3(0.925, 0.933, 0.925), vec3(0.188, 0.196, 0.925), vec3(0.000, 0.000, 0.000), // 19: Underwater Atmospheric
    vec3(0.925, 0.933, 0.925), vec3(0.596, 0.133, 0.125), vec3(0.329, 0.329, 0.329), // 20: Castle Atmospheric
    vec3(0.596, 0.133, 0.125), vec3(0.831, 0.533, 0.125), vec3(0.329, 0.353, 0.000), // 21: Mario
    vec3(0.925, 0.933, 0.925), vec3(0.831, 0.533, 0.125), vec3(0.157, 0.447, 0.000), // 22: Luigi
    vec3(0.894, 0.769, 0.565), vec3(0.831, 0.533, 0.125), vec3(0.596, 0.133, 0.125), // 23: Fire Mario
    vec3(0.031, 0.486, 0.000), vec3(0.925, 0.933, 0.925), vec3(0.831, 0.533, 0.125), // 24: Overworld Enemies
    vec3(0.000, 0.400, 0.471), vec3(0.925, 0.706, 0.690), vec3(0.471, 0.235, 0.000), // 25: Underground Enemies
    vec3(0.596, 0.588, 0.596), vec3(0.925, 0.933, 0.925), vec3(0.831, 0.533, 0.125), // 26: Underwater Enemies
    vec3(0.596, 0.133, 0.125), vec3(0.925, 0.933, 0.925), vec3(0.831, 0.533, 0.125), // 27: Red Enemies
    vec3(0.471, 0.235, 0.000), vec3(0.471, 0.235, 0.000), vec3(0.000, 0.000, 0.000), // 28: Overworld Gold F1
    vec3(0.471, 0.235, 0.000), vec3(0.471, 0.235, 0.000), vec3(0.000, 0.400, 0.471), // 29: Underground Gold F1
    vec3(0.471, 0.235, 0.000), vec3(0.471, 0.235, 0.000), vec3(0.329, 0.329, 0.329), // 30: Castle Gold F1
    vec3(0.471, 0.235, 0.000), vec3(0.188, 0.196, 0.925), vec3(0.000, 0.000, 0.000), // 31: Underwater Gold F1
    vec3(0.235, 0.094, 0.000), vec3(0.471, 0.235, 0.000), vec3(0.000, 0.000, 0.000), // 32: Overworld Gold F2
    vec3(0.235, 0.094, 0.000), vec3(0.471, 0.235, 0.000), vec3(0.000, 0.400, 0.471), // 33: Underground Gold F2
    vec3(0.235, 0.094, 0.000), vec3(0.471, 0.235, 0.000), vec3(0.329, 0.329, 0.329), // 34: Castle Gold F2
    vec3(0.235, 0.094, 0.000), vec3(0.188, 0.196, 0.925), vec3(0.000, 0.000, 0.000), // 35: Underwater Gold F2
    vec3(0.000, 0.000, 0.000), vec3(0.925, 0.706, 0.690), vec3(0.471, 0.235, 0.000), // 36: Dark Enemies (Goomba/Buzzy/Bullet/Blooper)
    vec3(0.831, 0.533, 0.125), vec3(0.596, 0.133, 0.125), vec3(0.925, 0.933, 0.925), // 37: Princess
    vec3(0.925, 0.933, 0.925), vec3(0.596, 0.133, 0.125), vec3(0.831, 0.533, 0.125), // 38: Toad
    vec3(0.000, 0.400, 0.471), vec3(0.925, 0.706, 0.690), vec3(0.471, 0.235, 0.000)  // 39: Castle Green Enemies
};

void fragment() {
    vec4 tex = texture(TEXTURE, UV);
    if (tex.a < 0.5) {
        discard;
    }
    int base = palette_id * 3;
    float r = tex.r;
    if (r < 0.45) {
        COLOR = vec4(PAL[base], 1.0);
    } else if (r < 0.78) {
        COLOR = vec4(PAL[base + 1], 1.0);
    } else {
        COLOR = vec4(PAL[base + 2], 1.0);
    }
}
