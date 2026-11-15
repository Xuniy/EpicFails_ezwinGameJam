extends Node2D

@export var explosion_radius: float = 250.0
@export var fall_height: float = 700.0
@export var fall_time: float = 0.2

@onready var zone: AnimatedSprite2D = $zone_largage
@onready var bomb: Sprite2D = $egg_bomba
@onready var explo: AnimatedSprite2D = $explosion
@onready var flash: ColorRect = $Flash/White

var falling: bool = false
var elapsed: float = 0.0
var exploded: bool = false


func _ready() -> void:
	flash.hide()
	explo.frame_changed.connect(_update_flash)
	explo.hide()
	bomb.hide()
	bomb.position = Vector2(0.0, -fall_height)
	bomb.z_index = 10

	# Cinq images à une image par seconde, sans boucle.s
	zone.sprite_frames.set_animation_speed("nuke_largage", 2.0)
	zone.sprite_frames.set_animation_loop("nuke_largage", false)

	zone.animation_finished.connect(_on_zone_finished)
	zone.play("nuke_largage")


func _on_zone_finished() -> void:
	# La dernière image reste au sol pendant la chute.
	bomb.show()
	falling = true


func _physics_process(delta: float) -> void:
	if not falling:
		return

	elapsed += delta

	var t := clampf(
		elapsed / maxf(fall_time, 0.01),
		0.0,
		1.0
	)

	# La bombe accélère vers le point d'impact.
	bomb.position.y = -fall_height * (1.0 - t * t)

	if t >= 1.0:
		falling = false
		explode()


func explode() -> void:
	if exploded:
		return

	exploded = true
	bomb.hide()
	zone.hide()
	explo.show()
	explo.play("explosion")
	explo.set_frame_and_progress(0, 0.0)
	_update_flash()

	for enemy in $explosion_zone.get_overlapping_bodies():
		if not enemy.is_in_group("enemies"):
			continue

		if enemy.is_queued_for_deletion():
			continue

		enemy.take_damage(enemy.health)

	await explo.animation_finished
	queue_free()


func _update_flash() -> void:
	flash.visible = exploded and explo.frame < 2
	flash.color.a = 1.0 if explo.frame == 0 else 0.5
