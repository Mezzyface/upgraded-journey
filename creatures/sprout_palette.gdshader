shader_type canvas_item;
// Sprout Lands palette swap: every opaque pixel becomes the nearest colour of the palette texture.
// Used by creatures/sprout_palette.tres (creature variants review, docs/superpowers/specs/2026-09-28-creature-variants-review-design.md).

// hint_default_transparent: with no palette set (fresh clone before Sync) every texel is skipped, so pixels
// pass through unchanged instead of all mapping to the default white texture.
uniform sampler2D palette : filter_nearest, hint_default_transparent;

void fragment() {
	vec4 c = COLOR;
	if (c.a > 0.0) {
		ivec2 size = textureSize(palette, 0);
		vec3 best = c.rgb;
		float best_d = 1e9;
		// ponytail: plain RGB distance; switch to OKLab in this loop if colours land badly.
		for (int y = 0; y < size.y; y++) {
			for (int x = 0; x < size.x; x++) {
				vec4 p = texelFetch(palette, ivec2(x, y), 0);
				if (p.a < 0.5) {
					continue;
				}
				vec3 d = p.rgb - c.rgb;
				float dist = dot(d, d);
				if (dist < best_d) {
					best_d = dist;
					best = p.rgb;
				}
			}
		}
		c.rgb = best;
	}
	COLOR = c;
}
