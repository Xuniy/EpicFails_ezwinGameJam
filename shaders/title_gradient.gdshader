shader_type canvas_item;
render_mode unshaded;

uniform vec4 top_color : source_color = vec4(1.0, 0.96, 0.65, 1.0);
uniform vec4 bottom_color : source_color = vec4(1.0, 0.32, 0.08, 1.0);
uniform float gradient_height = 140.0;
varying float label_y;

void vertex() {
	label_y = VERTEX.y;
}

void fragment() {
	vec4 glyph = texture(TEXTURE, UV) * COLOR;
	float blend = smoothstep(0.15, 0.85, label_y / max(gradient_height, 1.0));
	vec3 tint = mix(top_color.rgb, bottom_color.rgb, blend);
	COLOR = vec4(glyph.rgb * tint, glyph.a);
}
