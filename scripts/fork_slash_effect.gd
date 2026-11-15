extends Node2D

var swing_duration: float = 0.1
var fade_duration: float = 0.12
var elapsed: float = 0.0


func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= swing_duration + fade_duration:
		queue_free()
		return
	modulate.a = 1.0 - clampf(
		(elapsed - swing_duration) / fade_duration, 0.0, 1.0
	)
	queue_redraw()


func _draw() -> void:
	var progress := clampf(elapsed / swing_duration, 0.0, 1.0)
	if progress <= 0.0:
		return
	var start_angle := deg_to_rad(-35.0)
	var end_angle := lerpf(start_angle, deg_to_rad(35.0), progress)
	# Trois traces suivent le balayage des dents de la fourche.
	for index in range(3):
		var color := Color(1.0, 0.85, 0.5, 0.85)
		if index == 1:
			color = Color(1.0, 1.0, 0.9, 1.0)
		draw_arc(
			Vector2.ZERO, 26.0 + index * 4.0,
			start_angle, end_angle, 20, color, 1.6, true
		)
