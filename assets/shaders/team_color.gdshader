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

// RGB->HSV via the standard max/min/chroma method (a mathematical algorithm,
// not a copied snippet). Returns hue in [0,1), saturation, and value.
vec3 rgb_to_hsv(vec3 color) {
	float max_c = max(color.r, max(color.g, color.b));
	float min_c = min(color.r, min(color.g, color.b));
	float chroma = max_c - min_c;
	float hue = 0.0;
	if (chroma > 0.0) {
		if (max_c == color.r) {
			hue = mod((color.g - color.b) / chroma, 6.0);
		} else if (max_c == color.g) {
			hue = (color.b - color.r) / chroma + 2.0;
		} else {
			hue = (color.r - color.g) / chroma + 4.0;
		}
		hue /= 6.0;
	}
	float saturation = max_c > 0.0 ? chroma / max_c : 0.0;
	return vec3(hue, saturation, max_c);
}

void fragment() {
	vec4 tex = COLOR;
	vec3 hsv = rgb_to_hsv(tex.rgb);
	// Circular hue distance to the key hue.
	float dh = abs(hsv.x - key_hue);
	dh = min(dh, 1.0 - dh);
	// Weight: 1 inside the band (and saturated enough), ramping to 0 at the edge.
	float hue_w = 1.0 - smoothstep(hue_tolerance, hue_tolerance * 2.0, dh);
	float sat_w = smoothstep(min_saturation * 0.5, min_saturation, hsv.y);
	float w = hue_w * sat_w;
	// Recolor preserves the region's internal shading via the original value.
	vec3 recolored = team_color.rgb * hsv.z;
	COLOR.rgb = mix(tex.rgb, recolored, w);
}
