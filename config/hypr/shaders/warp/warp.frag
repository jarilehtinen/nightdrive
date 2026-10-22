// The trip back in time (shell.qml): the desktop as it was ripples like a film's flashback, loses its colours and pixels
// down to the old machine's, and turns into its screen. p runs from 0 to 1.
// Compiled with qt6-qtshadertools: qsb-qt6 --glsl "100es,120,150" --hlsl 50 --msl 12 -o warp.frag.qsb warp.frag
#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float p;          // progress, 0 → 1
    float t;          // seconds
    float blocks;     // the machine's pixel in screen pixels, at the end
    vec2 area;        // the window in pixels
    vec4 tint;        // the machine's colour
};
layout(binding = 1) uniform sampler2D source;   // the desktop
layout(binding = 2) uniform sampler2D target;   // the machine's screen

void main() {
    vec2 uv = qt_TexCoord0;
    // The ripple: rows slide sideways on two waves, strongest in the middle of the trip
    float wave = smoothstep(0.0, 0.35, p) * (1.0 - smoothstep(0.7, 0.95, p));
    uv.x += wave * (0.035 * sin(uv.y * 38.0 + t * 9.0) + 0.010 * sin(uv.y * 170.0 - t * 23.0));
    uv.y += wave * 0.006 * sin(t * 5.0);
    uv = clamp(uv, 0.0, 1.0);

    // Fewer pixels, in steps, past the machine's own (three times its size, so it shows) until the flash
    float k = smoothstep(0.15, 0.75, p);
    float block = floor(mix(1.0, blocks * 3.0, k) + 0.5);
    vec2 res = area / block;
    vec2 cell = (floor(uv * res) + 0.5) / res;
    vec3 c = texture(source, cell).rgb;

    // Fewer colours, and towards the machine's
    float lum = dot(c, vec3(0.299, 0.587, 0.114));
    c = mix(c, vec3(lum), k * 0.6);
    float levels = mix(32.0, 3.0, k);
    c = floor(c * levels + 0.5) / levels;
    c = mix(c, lum * tint.rgb * 1.5, k * 0.5);

    // Scanlines, one a machine pixel
    float scan = 0.5 + 0.5 * cos(qt_TexCoord0.y * area.y * 6.2832 / max(block, 2.0));
    c *= mix(1.0, 0.7 + 0.3 * scan, k);

    // A flash, then the machine's screen
    c += vec3(1.0) * smoothstep(0.72, 0.8, p) * (1.0 - smoothstep(0.8, 0.9, p));
    vec3 now = texture(target, qt_TexCoord0).rgb;
    fragColor = vec4(mix(c, now, smoothstep(0.8, 0.95, p)), 1.0) * qt_Opacity;
}
