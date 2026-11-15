extends Control

## Flèche sur le bord de l'écran lorsque le poulailler est hors champ.
@export var target: Node2D

const EDGE_MARGIN: float = 40.0
const ARROW_SIZE: float = 16.0
const ARROW_COLOR := Color(1.0, 0.75, 0.2)

var _show_arrow: bool = false
var _edge := Vector2.ZERO
var _direction := Vector2.RIGHT


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	_update_indicator()
	queue_redraw()


func _update_indicator() -> void:
	_show_arrow = false
	if not is_instance_valid(target):
		return

	# Position de la cible en coordonnées écran (prend en compte la caméra et le zoom).
	var screen_pos: Vector2 = get_viewport().get_canvas_transform() * target.global_position
	if Rect2(Vector2.ZERO, size).grow(-EDGE_MARGIN).has_point(screen_pos):
		return

	var center := size * 0.5
	var offset := screen_pos - center
	if offset.length_squared() < 1.0:
		return
	var half := (center - Vector2.ONE * EDGE_MARGIN).max(Vector2.ZERO)
	var scale_x := half.x / absf(offset.x) if absf(offset.x) > 0.001 else INF
	var scale_y := half.y / absf(offset.y) if absf(offset.y) > 0.001 else INF
	_edge = center + offset * minf(scale_x, scale_y)
	_direction = offset.normalized()
	_show_arrow = true


func _draw() -> void:
	if not _show_arrow:
		return

	# Flèche orientée vers la cible.
	var direction: Vector2 = _direction
	var perpendicular: Vector2 = direction.orthogonal()
	var tip: Vector2 = _edge + direction * ARROW_SIZE
	var base: Vector2 = _edge - direction * ARROW_SIZE * 0.5
	var left: Vector2 = base + perpendicular * ARROW_SIZE * 0.6
	var right: Vector2 = base - perpendicular * ARROW_SIZE * 0.6

	draw_colored_polygon(PackedVector2Array([tip, left, right]), ARROW_COLOR)
