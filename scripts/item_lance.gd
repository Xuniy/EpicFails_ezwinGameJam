extends Node2D

const SOUND_EFFECT = preload("res://scripts/sound_effect.gd")
const EXPLOSION_SOUND = preload("res://sounds/grenade_explo.wav")
const THROW_SOUND = preload("res://sounds/throw_bruit.wav")

@export_enum("grenade", "tp") var item_type: String = "grenade"
@export var flight_time: float = 0.6
@export var explosion_radius: float = 160.0
@export var damage: float = 40.0

var thrower: Node2D
var start: Vector2
var destination: Vector2
var control: Vector2

var elapsed: float = 0.0
var finished: bool = false
var exploded: bool = false


func _ready() -> void:
	add_to_group("projectiles")
	$explo_grenade.hide()


func launch(origin: Vector2, target: Vector2, height: float) -> void:
	start = origin
	destination = target
	control = (start + destination) * 0.5 + Vector2.UP * height
	global_position = start
	SOUND_EFFECT.play_at(THROW_SOUND, self)


func _physics_process(delta: float) -> void:
	if finished:
		return

	elapsed += delta

	var t := clampf(
		elapsed / maxf(flight_time, 0.01),
		0.0,
		1.0
	)

	var first := start.lerp(control, t)
	var second := control.lerp(destination, t)

	global_position = first.lerp(second, t)

	# Rotation visuelle pendant le lancer.
	$Sprite2D.rotation += 8.0 * delta

	if t >= 1.0:
		land()


func land() -> void:
	if finished:
		return

	finished = true

	if item_type == "tp":
		if is_instance_valid(thrower):
			thrower.teleport_to(destination)

		queue_free()
		return

	exploded = true
	SOUND_EFFECT.play_at(EXPLOSION_SOUND, self)
	$Sprite2D.hide()
	$explo_grenade.show()
	$explo_grenade.play("default")

	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.is_queued_for_deletion():
			continue

		if global_position.distance_to(enemy.global_position) <= explosion_radius:
			enemy.take_damage(damage)

	await $explo_grenade.animation_finished
	queue_free()
