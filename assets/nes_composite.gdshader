shader_type canvas_item;

// ============================================================================
// NES Composite Output Shader for Godot 4 (Optimized)
// ============================================================================
// Simulates the NTSC composite video signal path:
//   RGB -> YIQ encode -> composite signal -> decode (with bandwidth limits) -> RGB
//
// This version reads from SCREEN_TEXTURE via hint_screen_texture.
// Apply it to a ColorRect INSIDE your SubViewport (as the last child, so it
// renders on top of everything). The shader runs at the SubViewport's
// resolution, not the display resolution, so performance is constant
// regardless of window size.
//
// SETUP:
//   SubViewportContainer (Stretch OFF, no material)
//     SubViewport (your game resolution, e.g. 426x240)
//       Level (your game content)
//       CanvasLayer (z_index high, e.g. 100)
//         ColorRect (full rect, this shader on its material)
//
// The CanvasLayer ensures the ColorRect renders after all game content.
// The ColorRect reads the already-rendered game via screen texture and
// outputs the composite-processed result.
// ============================================================================

// -- Signal quality --
uniform float composite_quality : hint_range(0.5, 4.0, 0.1) = 1.0;
uniform float chroma_quality : hint_range(0.2, 2.0, 0.05) = 0.6;
uniform float artifact_strength : hint_range(0.0, 1.5, 0.05) = 1.0;

// -- Color adjustments --
uniform float hue_offset : hint_range(-1.0, 1.0, 0.01) = 0.0;
uniform float saturation : hint_range(0.0, 2.0, 0.05) = 1.0;
uniform float brightness : hint_range(-0.2, 0.2, 0.01) = 0.0;
uniform float contrast : hint_range(0.5, 1.5, 0.05) = 1.0;

// -- Dot crawl --
uniform bool enable_dot_crawl = true;
uniform float dot_crawl_speed : hint_range(0.5, 4.0, 0.1) = 2.0;

// -- Signal characteristics --
uniform float carrier_cycles_per_pixel : hint_range(0.2, 1.5, 0.01) = 0.6667;
uniform float scanline_phase_shift : hint_range(0.0, 1.0, 0.01) = 0.333;

// ============================================================================
// Tap count: compile-time constant. Change and re-save for quality/perf:
//   HALF_TAPS 3 = 7 taps  (fast, slight ringing)
//   HALF_TAPS 4 = 9 taps  (good balance)
//   HALF_TAPS 5 = 11 taps (clean)
//   HALF_TAPS 6 = 13 taps (very clean, heavier)
// ============================================================================
const int HALF_TAPS = 4;
const int TAPS = HALF_TAPS * 2 + 1;


// Screen texture: reads whatever has been drawn to this viewport so far
uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_nearest;

// ============================================================================

float blackman_window(float t) {
    return 0.42 - 0.5 * cos(TAU * t) + 0.08 * cos(2.0 * TAU * t);
}

float weighted_sinc(float x, float cutoff, float win) {
    if (abs(x) < 0.001) return cutoff * win;
    return (sin(PI * cutoff * x) / (PI * x)) * win;
}

float rgb_to_y(vec3 rgb) {
    return dot(rgb, vec3(0.299, 0.587, 0.114));
}

vec2 rgb_to_iq(vec3 rgb) {
    return vec2(
        dot(rgb, vec3(0.5959, -0.2746, -0.3213)),
        dot(rgb, vec3(0.2115, -0.5227, 0.3112))
    );
}

vec3 yiq_to_rgb(vec3 yiq) {
    return vec3(
        dot(yiq, vec3(1.0, 0.9563, 0.6210)),
        dot(yiq, vec3(1.0, -0.2721, -0.6474)),
        dot(yiq, vec3(1.0, -1.1070, 1.7046))
    );
}

// ============================================================================

void fragment() {
    // Screen texture size = SubViewport size (e.g. 426x240)
    // This is the resolution the shader actually runs at.
    vec2 vp_size = vec2(textureSize(screen_tex, 0));
    float inv_w = 1.0 / vp_size.x;

    vec2 pixel_coord = SCREEN_UV * vp_size;

    float cpp = carrier_cycles_per_pixel;
    float scanline = floor(pixel_coord.y);

    float frame_phase = 0.0;
    if (enable_dot_crawl) {
        frame_phase = mod(TIME * dot_crawl_speed, 3.0) * TAU / 3.0;
    }

    float base_phase = TAU * cpp * pixel_coord.x
                     + TAU * scanline_phase_shift * scanline
                     + frame_phase
                     + hue_offset * PI;

    float phase_step = TAU * cpp;

    float luma_cutoff = min(composite_quality * 0.4, cpp * 0.9);
    float chroma_cutoff = min(chroma_quality * 0.25, cpp * 0.5);

    float y_sum = 0.0;
    float i_sum = 0.0;
    float q_sum = 0.0;
    float y_wsum = 0.0;
    float iq_wsum = 0.0;

    float taps_m1 = float(TAPS - 1);

    for (int n = -HALF_TAPS; n <= HALF_TAPS; n++) {
        float offset = float(n);

        vec2 sample_uv = vec2(clamp(SCREEN_UV.x + offset * inv_w, 0.0, 1.0), SCREEN_UV.y);
        vec3 s = texture(screen_tex, sample_uv).rgb;

        float phase = base_phase + offset * phase_step;
        float sin_p = sin(phase);
        float cos_p = cos(phase);

        float y = rgb_to_y(s);
        vec2 iq = rgb_to_iq(s);
        float composite = y + (iq.x * sin_p + iq.y * cos_p) * artifact_strength;

        float win = blackman_window((offset + float(HALF_TAPS)) / taps_m1);
        float y_w = weighted_sinc(offset, luma_cutoff, win);
        float iq_w = weighted_sinc(offset, chroma_cutoff, win);

        y_sum += composite * y_w;
        y_wsum += y_w;

        float iq_w2 = iq_w * 2.0;
        i_sum += composite * sin_p * iq_w2;
        q_sum += composite * cos_p * iq_w2;
        iq_wsum += iq_w;
    }

    float y_dec = (y_sum / y_wsum + brightness) * contrast;
    float i_dec = (i_sum / iq_wsum) * saturation;
    float q_dec = (q_sum / iq_wsum) * saturation;

    vec3 result = clamp(yiq_to_rgb(vec3(y_dec, i_dec, q_dec)), 0.0, 1.0);
    COLOR = vec4(result, 1.0);
}
