shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float intensity : hint_range(0.0, 2.0) = 0.0;
uniform float effect_time = -1.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	float animation_time = effect_time >= 0.0 ? effect_time : TIME;
	vec2 wave = vec2(
		sin(uv.y * 18.0 + animation_time * 2.4),
		cos(uv.x * 15.0 + animation_time * 1.8)
	) * 0.003 * intensity;
	vec2 shift = vec2(0.0025 * intensity, 0.0);
	vec3 color;
	color.r = texture(screen_texture, uv + wave + shift).r;
	color.g = texture(screen_texture, uv + wave).g;
	color.b = texture(screen_texture, uv + wave - shift).b;
	float tint = (sin(animation_time * 2.0) * 0.5 + 0.5) * 0.12 * intensity;
	color = mix(color, color.gbr, tint);
	COLOR = vec4(clamp(color, vec3(0.0), vec3(1.0)), 1.0);
}
