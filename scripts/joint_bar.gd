class_name JointBar
extends Control

## Joint qui se consume : la braise rouge recule vers la gauche à vitesse constante,
## et le joint est entièrement consumé après `duration` secondes.
## La fumée sort de la braise, avec les images de fume.png (animation du joueur).

@export var joint_texture: Texture2D
@export var smoke_texture: Texture2D
@export var duration: float = 45.0
@export var display_scale: float = 4.0
## Échelle de la fumée, relative à display_scale : chaque pixel de fumée est ×3.
@export var smoke_scale_factor: float = 3.0

const JOINT_REGION := Rect2(0, 13, 32, 6)  # zone du joint dans joint_bar.png
# Unité qui se déplace : la frontière marron (diagonale, colonnes 25 à 28 selon la ligne)
# + la braise rouge jusqu'au bord droit. La colonne 25 est le point le plus à gauche de la frontière.
const EMBER_COLUMN: float = 25.0
const EMBER_WIDTH: float = 7.0             # 32 - EMBER_COLUMN
const SMOKE_FRAME_SIZE: int = 8
# Dans chaque image de fume.png, la fumée occupe les colonnes 0 à 3 : son centre est en colonne 2.
const SMOKE_CONTENT_CENTER: float = 2.0
const SMOKE_FRAME_COUNT: int = 6
const SMOKE_FPS: float = 5.0

## 1.0 = joint entier, 0.0 = entièrement consumé.
var amount: float = 1.0
var smoke: AnimatedSprite2D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	smoke = AnimatedSprite2D.new()
	smoke.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	smoke.centered = false
	smoke.scale = Vector2.ONE * display_scale * smoke_scale_factor
	smoke.sprite_frames = _build_smoke_frames()
	smoke.animation = &"fume"
	add_child(smoke)
	smoke.play()


func _build_smoke_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.add_animation(&"fume")
	frames.set_animation_loop(&"fume", true)
	frames.set_animation_speed(&"fume", SMOKE_FPS)
	for i in SMOKE_FRAME_COUNT:
		var frame := AtlasTexture.new()
		frame.atlas = smoke_texture
		frame.region = Rect2(i * SMOKE_FRAME_SIZE, 0, SMOKE_FRAME_SIZE, SMOKE_FRAME_SIZE)
		frames.add_frame(&"fume", frame)
	return frames


func _process(delta: float) -> void:
	if duration > 0.0:
		amount = maxf(0.0, amount - delta / duration)

	_update_smoke()
	queue_redraw()


func _joint_top() -> float:
	return size.y - JOINT_REGION.size.y * display_scale


func _ember_x() -> float:
	# Position de la braise en pixels de texture : elle suit la fin du papier restant.
	return EMBER_COLUMN * amount


func _update_smoke() -> void:
	if smoke == null:
		return

	smoke.visible = amount > 0.0
	# Centre la fumée sur l'unité braise, et pose sa base sur le haut du joint.
	var smoke_px: float = display_scale * smoke_scale_factor
	var ember_center_x: float = (_ember_x() + EMBER_WIDTH * 0.5) * display_scale
	smoke.position = Vector2(
		ember_center_x - SMOKE_CONTENT_CENTER * smoke_px,
		_joint_top() - SMOKE_FRAME_SIZE * smoke_px
	)


func _draw() -> void:
	if joint_texture == null or amount <= 0.0:
		return

	var top: float = _joint_top()
	var ember_x: float = _ember_x()

	# Papier restant : de la gauche jusqu'à la braise.
	draw_texture_rect_region(
		joint_texture,
		Rect2(0.0, top, ember_x * display_scale, JOINT_REGION.size.y * display_scale),
		Rect2(JOINT_REGION.position.x, JOINT_REGION.position.y, ember_x, JOINT_REGION.size.y)
	)

	# Ligne marron + braise rouge : bougent ensemble, à la fin du papier restant.
	var ember_src := Rect2(
		EMBER_COLUMN,
		JOINT_REGION.position.y,
		EMBER_WIDTH,
		JOINT_REGION.size.y
	)
	draw_texture_rect_region(
		joint_texture,
		Rect2(ember_x * display_scale, top, ember_src.size.x * display_scale, ember_src.size.y * display_scale),
		ember_src
	)
