class_name HealthBar
extends Control

## Barre de vie dessinée : le cadre sert de fond, la jauge est rognée
## sur la zone exacte de la barre dans la texture (colonnes 16 à 60, lignes 5 et 6).

@export var frame: Texture2D
@export var fill: Texture2D
@export var display_scale: float = 2.0

const FILL_REGION := Rect2(16, 5, 45, 2)

var max_value: float = 100.0
var value: float = 100.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if frame:
		custom_minimum_size = frame.get_size() * display_scale


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if frame == null or fill == null:
		return

	draw_texture_rect(frame, Rect2(Vector2.ZERO, frame.get_size() * display_scale), false)

	var ratio: float = 0.0
	if max_value > 0.0:
		ratio = clampf(value / max_value, 0.0, 1.0)
	if ratio <= 0.0:
		return

	var source := Rect2(FILL_REGION.position, Vector2(FILL_REGION.size.x * ratio, FILL_REGION.size.y))
	var dest := Rect2(
		FILL_REGION.position * display_scale,
		Vector2(FILL_REGION.size.x * ratio, FILL_REGION.size.y) * display_scale
	)
	draw_texture_rect_region(fill, dest, source)
