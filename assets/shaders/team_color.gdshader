// Team-color palette-swap shader (SPI-1436).
// Original implementation of the hue-key palette-swap technique described by
// KoBeWi's Godot Palette Swap Shader (reads/writes COLOR directly, no texture
// lookups). No third-party source is copied; MIT under this repo.
shader_type canvas_item;

// The player's team color. White (default) is a visual no-op.
uniform vec4 team_color : source_color = vec4(1.0);
// Hue of the team-color key region in the sprite (magenta). Matches TeamColors.KEY_HUE.
uniform float key_hue : hint_range(0.0, 1.0) = 0.8333;
// Half-width of the matched hue band.
uniform float hue_tolerance : hint_range(0.0, 0.5) = 0.06;
// Pixels less saturated than this are treated as non-team (hue is unstable there).
uniform float min_saturation : hint_range(0.0, 1.0) = 0.25;

vec3 rgb_to_hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

void fragment() {
	vec4 tex = COLOR;
	vec3 hsv = rgb_to_hsv(tex.rgb);
	// Circular hue distance to the key hue.
	float dh = abs(hsv.x - key_hue);
	dh = min(dh, 1.0 - dh);
	// Weight: 1 inside the band (and saturated enough), ramping to 0 at the edge.
	float hue_w = 1.0 - smoothstep(hue_tolerance, hue_tolerance * 2.0, dh);
	float sat_w = step(min_saturation, hsv.y);
	float w = hue_w * sat_w;
	// Recolor preserves the region's internal shading via the original value.
	vec3 recolored = team_color.rgb * hsv.z;
	COLOR.rgb = mix(tex.rgb, recolored, w);
}
