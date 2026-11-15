extends Node2D

const BULLET_SCENE = preload("res://scences/bullet.tscn")

@export var fire_interval: float = 0.14
@export var base_flip_v: bool = true

@onready var muzzle1: Marker2D = $Sortie_balle_1
@onready var muzzle2: Marker2D = $Sortie_balle_2
@onready var weapon_sprite: AnimatedSprite2D = $arme_qui_tire
@onready var idle_sprite: Sprite2D = $arme_tire_pas

var cooldown: float = 0.0
var last_aim_direction: Vector2 = Vector2.RIGHT


func _ready() -> void:
	weapon_sprite.flip_v = true
	weapon_sprite.hide()
	idle_sprite.show()
	rotation = 0.0

func _physics_process(delta: float) -> void:
	
	if Input.is_action_pressed("use_item"):
		weapon_sprite.stop()
		weapon_sprite.hide()
		idle_sprite.show()
		rotation = 0.0

		var animation: StringName = get_parent().animated_sprite.animation

		z_index = 1 if animation in [&"walk_up", &"walk_up_left", &"walk_up_right"] else -1

		return
	var aim: Vector2 = get_parent().get_aim_input()

	if aim.length_squared() > 0.0:
		last_aim_direction = aim.normalized()

	cooldown = maxf(cooldown - delta, 0.0)
	var is_shooting: bool = get_parent().is_firing()
	var player_animation: StringName = get_parent().animated_sprite.animation

	if not aim.is_zero_approx() or is_shooting:
		idle_sprite.hide()
		weapon_sprite.show()
		global_rotation = last_aim_direction.angle()
		z_index = -1 if player_animation in [
			&"walk_up", &"walk_up_left", &"walk_up_right"
		] else 1
		weapon_sprite.flip_v = base_flip_v != (last_aim_direction.x < 0.0)
		if is_shooting:
			weapon_sprite.play("default")
			if cooldown <= 0.0:
				shoot()
				cooldown = fire_interval
		else:
			weapon_sprite.stop()
	else:
		weapon_sprite.stop()
		weapon_sprite.hide()
		idle_sprite.show()
		# Le sprite au repos conserve l'angle réglé dans la scène.
		rotation = 0.0
		# Au repos, l'arme est devant le sprite uniquement en vue de dos.
		z_index = 1 if player_animation in [
			&"walk_up", &"walk_up_left", &"walk_up_right"
		] else -1


func shoot() -> void:
	var bullet = BULLET_SCENE.instantiate()
	get_tree().current_scene.add_child(bullet)
	if (weapon_sprite.flip_v):
		bullet.global_position = muzzle2.global_position
	else :
		bullet.global_position = muzzle1.global_position
	bullet.direction = last_aim_direction
	$"../tir_balle_son".play()
