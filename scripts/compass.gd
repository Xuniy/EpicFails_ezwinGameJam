extends Control

## Boussole à l'écran : une flèche pointe vers la cible (le poulailler).
@export var player: Node2D
@export var target: Node2D

const RADIUS: float = 36.0
const BACKGROUND_COLOR := Color(0.0, 0.0, 0.0, 0.5)
const RING_COLOR := Color(1.0, 1.0, 1.0, 0.8)
const ARROW_COLOR := Color(1.0, 0.75, 0.2)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2.ONE * RADIUS * 2.0


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5

	draw_circle(center, RADIUS, BACKGROUND_COLOR)
	draw_arc(center, RADIUS, 0.0, TAU, 48, RING_COLOR, 2.0)

	if not is_instance_valid(player) or not is_instance_valid(target):
		return

	var offset := target.global_position - player.global_position
	if offset.length_squared() < 1.0:
		return

	var direction := offset.normalized()
	var tip := center + direction * (RADIUS - 6.0)
	var left := center + direction.rotated(2.6) * (RADIUS * 0.45)
	var right := center + direction.rotated(-2.6) * (RADIUS * 0.45)

	draw_colored_polygon(PackedVector2Array([tip, left, right]), ARROW_COLOR)
