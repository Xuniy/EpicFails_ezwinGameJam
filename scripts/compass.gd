extends Control

## Indicateur sur le bord de l'écran : affiché uniquement lorsque la cible
## (le poulailler) sort du cadre, placé sur le bord dans sa direction.
@export var target: Node2D

const EDGE_MARGIN: float = 40.0
const ARROW_SIZE: float = 16.0
const ARROW_COLOR := Color(1.0, 0.75, 0.2)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if not is_instance_valid(target):
		return

	# Position de la cible en coordonnées écran (prend en compte la caméra et le zoom).
	var screen_pos: Vector2 = get_viewport().get_canvas_transform() * target.global_position

	# Cible visible à l'écran : pas d'indicateur.
	if Rect2(Vector2.ZERO, size).grow(-EDGE_MARGIN).has_point(screen_pos):
		return

	var center: Vector2 = size * 0.5
	var offset: Vector2 = screen_pos - center
	if offset.length_squared() < 1.0:
		return

	# Point d'intersection de la direction avec le bord (dans la marge).
	var half: Vector2 = center - Vector2.ONE * EDGE_MARGIN
	var scale_x: float = half.x / absf(offset.x) if absf(offset.x) > 0.001 else INF
	var scale_y: float = half.y / absf(offset.y) if absf(offset.y) > 0.001 else INF
	var edge: Vector2 = center + offset * minf(scale_x, scale_y)

	# Flèche orientée vers la cible.
	var direction: Vector2 = offset.normalized()
	var perpendicular: Vector2 = direction.orthogonal()
	var tip: Vector2 = edge + direction * ARROW_SIZE
	var base: Vector2 = edge - direction * ARROW_SIZE * 0.5
	var left: Vector2 = base + perpendicular * ARROW_SIZE * 0.6
	var right: Vector2 = base - perpendicular * ARROW_SIZE * 0.6

	draw_colored_polygon(PackedVector2Array([tip, left, right]), ARROW_COLOR)
