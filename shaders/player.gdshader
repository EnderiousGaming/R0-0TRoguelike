shader_type canvas_item;

// Grab the screen texture
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

// Shader settings you can tweak in the Inspector
uniform float curvature : hint_range(1.0, 10.0) = 3.5;
uniform float scanline_count : hint_range(0.0, 1000.0) = 250.0;
uniform float scanline_intensity : hint_range(0.0, 1.0) = 0.2;

void fragment() {
    // 1. Center the UV coordinates for curving
    vec2 uv = SCREEN_UV * 2.0 - 1.0;
    vec2 offset = uv.yx / curvature;
    uv = uv + uv * offset * offset;
    uv = uv * 0.5 + 0.5;

    // 2. Check if the curved UVs are outside the screen bounds (creates black borders)
    if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
        COLOR = vec4(0.0, 0.0, 0.0, 1.0);
    } else {
        // 3. Sample the curved screen texture
        vec4 color = texture(screen_texture, uv);

        // 4. Apply horizontal scanlines
        float scanline = sin(uv.y * scanline_count * 3.14159) * scanline_intensity;
        color.rgb -= scanline;

        // 5. Apply a slight vignette (darken the corners)
        float vignette = uv.x * uv.y * (1.0 - uv.x) * (1.0 - uv.y);
        color.rgb *= clamp(vignette * 20.0, 0.0, 1.0);

        COLOR = color;
    }
}