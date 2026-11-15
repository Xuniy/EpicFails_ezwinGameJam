class_name OffscreenMarkers
extends Control

## Flèches sur le bord de l'écran vers les ennemis et les objets au sol qui sortent du cadre.
## Même principe que la boussole du poulailler, pour les plus proches.

const EDGE_MARGIN: float = 40.0
const ARROW_SIZE: float = 14.0
const MAX_PER_GROUP: int = 6
const ENEMY_COLOR := Color(1.0, 0.3, 0.3)
const ITEM_COLOR := Color(0.4, 0.9, 1.0)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var canvas_transform: Transform2D = get_viewport().get_canvas_transform()
	var inner: Rect2 = Rect2(Vector2.ZERO, size).grow(-EDGE_MARGIN)
	var scene := get_tree().current_scene
	var player: Node2D = scene.find_child("Player", true, false) as Node2D if scene else null
	_draw_group("enemies", ENEMY_COLOR, canvas_transform, inner, player)
	_draw_group("ground_items", ITEM_COLOR, canvas_transform, inner, player)


func _draw_group(group_name: String, color: Color, canvas_transform: Transform2D, inner: Rect2, player: Node2D) -> void:
	var nodes: Array[Node2D] = []
	for node in get_tree().get_nodes_in_group(group_name):
		var node2d := node as Node2D
		if node2d != null and not node2d.is_queued_for_deletion():
			nodes.append(node2d)
	if player != null:
		nodes.sort_custom(func(a: Node2D, b: Node2D) -> bool:
			return a.global_position.distance_to(player.global_position) < b.global_position.distance_to(player.global_position)
		)
	var drawn := 0
	for node2d in nodes:
		if drawn >= MAX_PER_GROUP:
			break
		var screen_pos: Vector2 = canvas_transform * node2d.global_position
		if inner.has_point(screen_pos):
			continue
		_draw_arrow(screen_pos, color)
		drawn += 1


# Flèche posée sur le bord, orientée vers la cible hors cadre.
func _draw_arrow(screen_pos: Vector2, color: Color) -> void:
	var center: Vector2 = size * 0.5
	var offset: Vector2 = screen_pos - center
	if offset.length_squared() < 1.0:
		return
	var half: Vector2 = center - Vector2.ONE * EDGE_MARGIN
	var scale_x: float = half.x / absf(offset.x) if absf(offset.x) > 0.001 else INF
	var scale_y: float = half.y / absf(offset.y) if absf(offset.y) > 0.001 else INF
	var edge: Vector2 = center + offset * minf(scale_x, scale_y)
	var direction: Vector2 = offset.normalized()
	var perpendicular: Vector2 = direction.orthogonal()
	var tip: Vector2 = edge + direction * ARROW_SIZE
	var base: Vector2 = edge - direction * ARROW_SIZE * 0.5
	var left: Vector2 = base + perpendicular * ARROW_SIZE * 0.6
	var right: Vector2 = base - perpendicular * ARROW_SIZE * 0.6
	draw_colored_polygon(PackedVector2Array([tip, left, right]), color)
