extends CharacterBody2D

@export var speed: float = 80.0
@export var health: float = 15.0
@export var damage: float = 2.0
@export var stop_distance: float = 24.0
@export var attack_distance: float = 30
@export var attack_windup: float = 0.4
@export var attack_cooldown: float = 1.0
var is_attacking: bool = false

@onready var attack_zone: Area2D = $attack_zone


# Le point à rejoindre au poulailler, donné par le spawner.
@export var default_target: Node2D

# Cible prioritaire : le joueur lorsqu'il est détecté.
var target: Node2D


func _ready() -> void:
	add_to_group("enemies")


func _physics_process(_delta: float) -> void:
	
	if is_attacking:
		velocity = Vector2.ZERO
		return
	
	var current_target: Node2D = default_target

	if is_instance_valid(target):
		current_target = target

	if not is_instance_valid(current_target):
		velocity = Vector2.ZERO
		return

	var distance := global_position.distance_to(
		current_target.global_position
	)

	if distance <= attack_distance:
		attack(current_target)
		return

	var direction := global_position.direction_to(current_target.global_position)
	velocity = direction * speed
	move_and_slide()
	
	for index in range(get_slide_collision_count()):
		var collision := get_slide_collision(index)

		if collision.get_collider() == current_target:
			attack(current_target)
			break
		
func focus_player(player: Node2D) -> void:
	target = player
	print("[Enemy] Joueur détecté : poursuite.")


func return_to_coop() -> void:
	target = null
	print("[Enemy] Joueur sorti de la zone : retour au poulailler.")


func take_damage(amount: float) -> void:
	health -= amount

	if health <= 0.0:
		queue_free()
		
func attack(victim: Node2D) -> void:
	is_attacking = true
	velocity = Vector2.ZERO

	# Oriente le coup, puis garde cette direction.
	attack_zone.global_rotation = global_position.direction_to(
		victim.global_position
	).angle()

	# Laisse au joueur le temps d'esquiver.
	await get_tree().create_timer(attack_windup).timeout

	for body in attack_zone.get_overlapping_bodies():
		if body == default_target or body == target:
			if body.has_method("take_damage"):
				body.take_damage(damage)
				print("[Fermier] Coup touché : ", body.name)

	await get_tree().create_timer(attack_cooldown).timeout
	is_attacking = false
