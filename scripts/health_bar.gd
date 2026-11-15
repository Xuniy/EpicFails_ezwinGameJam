class_name HealthBar
extends Control

## Barre de vie dessinée : le cadre sert de fond, la jauge est rognée
## pour suivre la piste exacte du cadre.
## - track_region / fill_region : piste dans le cadre et zone de jauge dans la texture de remplissage
## - heart_fill / heart_region : cœur optionnel, rempli en rouge selon la vie
##   (il se vide en même temps que la barre). heart_region est en coordonnées du cadre.

@export var frame: Texture2D
@export var fill: Texture2D
@export var display_scale: float = 2.0
@export var track_region := Rect2(16, 5, 45, 2)
@export var fill_region := Rect2(16, 5, 45, 2)
@export var heart_fill: Texture2D
@export var heart_region := Rect2(0, 0, 0, 0)

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

	var ratio: float = 0.0
	if max_value > 0.0:
		ratio = clampf(value / max_value, 0.0, 1.0)

	draw_texture_rect(frame, Rect2(Vector2.ZERO, frame.get_size() * display_scale), false)

	if ratio > 0.0:
		var dest := Rect2(
			track_region.position * display_scale,
			Vector2(track_region.size.x * ratio, track_region.size.y) * display_scale
		)
		var source := Rect2(
			fill_region.position,
			Vector2(fill_region.size.x * ratio, fill_region.size.y)
		)
		draw_texture_rect_region(fill, dest, source)

	# Cœur : la partie rouge descend depuis le bas du cœur, au rythme de la barre.
	if heart_fill and heart_region.size.x > 0.0 and heart_region.size.y > 0.0:
		var heart_height: float = heart_region.size.y * ratio
		if heart_height > 0.0:
			var top: float = heart_region.position.y + heart_region.size.y - heart_height
			var heart_source := Rect2(
				heart_region.position.x, top,
				heart_region.size.x, heart_height
			)
			var heart_dest := Rect2(heart_source.position * display_scale, heart_source.size * display_scale)
			draw_texture_rect_region(heart_fill, heart_dest, heart_source)
