extends Node2D

const BULLET_SCENE = preload("res://scences/bullet.tscn")

@export var fire_interval: float = 0.14

@onready var muzzle: Marker2D = $Sortie_balle

var cooldown: float = 0.0


func _physics_process(delta: float) -> void:
	var aim := Input.get_vector(
		"sr_gauche", "sr_droite", "sr_haut", "sr_bas"
	)

	# Garde la dernière orientation quand tu relâches le stick.
	if aim.length_squared() > 0.0:
		global_rotation = aim.angle()

	cooldown = maxf(cooldown - delta, 0.0)

	if Input.is_action_pressed("tir") and cooldown <= 0.0:
		shoot()
		cooldown = fire_interval


func shoot() -> void:
	var bullet = BULLET_SCENE.instantiate()
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = muzzle.global_position
	bullet.direction = Vector2.RIGHT.rotated(global_rotation)
