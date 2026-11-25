// The dark mine. "ambient" = how lit the whole wall is (your flame); on top of that the lighter
// glows around itself. Drawn on a chunky pixel grid with the fade in steps (pixel art, no smooth
// gradient). Numbers come from Config (LIGHT_..., WALL_DARKNESS).
shader_type canvas_item;

uniform vec2 rect_size = vec2(1280.0, 652.0);
uniform float ambient = 1.0;       // 0 = pitch dark .. 1 = the whole wall lit
uniform vec4 light0 = vec4(0.0);   // x, y, radius (px), unused  - extra light (not used right now)
uniform vec4 light1 = vec4(0.0);   // the glow around the lighter itself
uniform float darkness = 0.88;
uniform float soft = 0.45;         // part of the radius that fades out
uniform float bands = 4.0;         // steps in the fade
uniform float pixel = 6.0;         // screen px per light pixel
uniform vec4 tint = vec4(1.0, 0.6, 0.2, 0.07);

float lit_by(vec2 p, vec4 l) {
	if (l.z <= 0.0) {
		return 0.0;
	}
	float core = l.z * (1.0 - soft);
	float t = 1.0 - clamp((distance(p, l.xy) - core) / max(l.z - core, 0.001), 0.0, 1.0);
	if (bands > 0.0) {
		t = ceil(t * bands - 0.0001) / bands;
	}
	return t;
}

void fragment() {
	vec2 p = (floor(UV * rect_size / pixel) + 0.5) * pixel;
	float lit = max(ambient, max(lit_by(p, light0), lit_by(p, light1)));
	float a_dark = darkness * (1.0 - lit);
	float a_tint = tint.a * lit;
	float a = a_dark + a_tint * (1.0 - a_dark);
	vec3 rgb = a > 0.0 ? tint.rgb * a_tint / a : vec3(0.0);
	COLOR = vec4(rgb, a);
}
