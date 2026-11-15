class_name HealthBar
extends Control

## Barre de vie dessinée : le cadre sert de fond, la jauge est rognée
## pour suivre la piste exacte du cadre.
## - track_region : zone de la piste dans le cadre (coordonnées de la texture du cadre)
## - fill_region  : zone de la jauge dans la texture de remplissage (même taille que la piste)

@export var frame: Texture2D
@export var fill: Texture2D
@export var display_scale: float = 2.0
@export var track_region := Rect2(16, 5, 45, 2)
@export var fill_region := Rect2(16, 5, 45, 2)

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

	var dest := Rect2(
		track_region.position * display_scale,
		Vector2(track_region.size.x * ratio, track_region.size.y) * display_scale
	)
	var source := Rect2(
		fill_region.position,
		Vector2(fill_region.size.x * ratio, fill_region.size.y)
	)
	draw_texture_rect_region(fill, dest, source)
