@tool
extends Label

@export_range(24, 200, 1) var maximum_font_size: int = 144:
	set(value):
		maximum_font_size = value
		if is_node_ready():
			_fit_title()


func _ready() -> void:
	resized.connect(_fit_title)
	_fit_title()


func _fit_title() -> void:
	var font := get_theme_font("font")
	var measured := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, maximum_font_size)
	var available := (size - Vector2(32.0, 24.0)).max(Vector2.ONE)
	var factor := minf(1.0, minf(available.x / maxf(measured.x, 1.0), available.y / maxf(measured.y, 1.0)))
	add_theme_font_size_override("font_size", maxi(12, floori(maximum_font_size * factor)))
	if material is ShaderMaterial:
		material.set_shader_parameter("gradient_height", size.y)
