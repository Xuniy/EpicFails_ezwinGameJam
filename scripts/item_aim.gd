extends Node2D

@export var min_distance: float = 40.0
@export var max_distance: float = 800.0
@export var arc_height: float = 200.0
@export var cursor_speed: float = 500.0
var distance: float = 40.0
var aim_direction := Vector2.RIGHT


func _ready() -> void:
	hide()


func _process(delta: float) -> void:
	visible = get_parent().is_item_aiming()

	if not visible:
		distance = 0.0
		return

	if get_parent().is_mouse_aiming():
		var offset: Vector2 = get_global_mouse_position() - global_position
		if offset.length() > 0.001:
			aim_direction = offset.normalized()
		distance = minf(offset.length(), max_distance)
		queue_redraw()
		return

	var aim := Input.get_vector(
		"sr_gauche", "sr_droite", "sr_haut", "sr_bas"
	)

	if not aim.is_zero_approx():
		var cursor_offset := aim_direction * distance
		cursor_offset += aim * cursor_speed * delta
		cursor_offset = cursor_offset.limit_length(max_distance)
		distance = cursor_offset.length()
		if distance > 0.0:
			aim_direction = cursor_offset / distance

	queue_redraw()

func _draw() -> void:
	# Points définis dans le monde.
	var start := global_position
	var end := start + aim_direction * distance
	var control := (start + end) * 0.5 + Vector2.UP * arc_height

	var segments := 40

	for index in range(segments):
		# Un segment dessiné, un segment vide.
		if index % 2 != 0:
			continue

		var t1 := float(index) / segments
		var t2 := float(index + 1) / segments

		var point1 := curve_point(start, control, end, t1)
		var point2 := curve_point(start, control, end, t2)

		draw_line(
			to_local(point1),
			to_local(point2),
			Color.WHITE,
			1.0
		)


func curve_point(
	start: Vector2,
	control: Vector2,
	end: Vector2,
	t: float
) -> Vector2:
	var first := start.lerp(control, t)
	var second := control.lerp(end, t)
	return first.lerp(second, t)
