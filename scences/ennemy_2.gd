extends CharacterBody2D

const ITEM_SCENE = preload("res://scences/item_au_sol.tscn")
const ITEM_TYPES = ["grenade", "tp", "nuke"]
const WALK_ANIMATIONS = [
	&"walk_right", &"walk_down_right", &"walk_down", &"walk_down_left",
	&"walk_left", &"walk_up_left", &"walk_up", &"walk_up_right"
]

@export var speed: float = 80.0
@export var health: float = 15.0
@export var damage: float = 2.0
@export var attack_distance: float = 140.0
@export var dash_speed: float = 600.0
@export var dash_duration: float = 0.35
@export var attack_cooldown: float = 1.2
@export var default_target: Node2D

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_zone: Area2D = $attack_zone
@onready var attack_shape: CollisionShape2D = $attack_zone/CollisionShape2D

var target: Node2D
var is_attacking: bool = false
var dash_direction: Vector2 = Vector2.DOWN
var dash_remaining: float = 0.0
var cooldown_remaining: float = 0.0
var dead: bool = false
var dash_hits: Dictionary = {}


func _ready() -> void:
	add_to_group("enemies")


func _physics_process(delta: float) -> void:
	if dead:
		return

	cooldown_remaining = maxf(cooldown_remaining - delta, 0.0)

	if is_attacking:
		process_dash(delta)
		return

	if cooldown_remaining > 0.0:
		velocity = Vector2.ZERO
		animated_sprite.stop()
		return

	var current_target: Node2D = default_target
	if is_instance_valid(target):
		current_target = target

	if not is_instance_valid(current_target):
		velocity = Vector2.ZERO
		animated_sprite.stop()
		return

	if global_position.distance_to(current_target.global_position) <= attack_distance:
		attack(current_target)
		process_dash(delta)
		return

	var direction := global_position.direction_to(current_target.global_position)
	velocity = direction * speed
	update_animation(direction, true)
	move_and_slide()

	# Permet aussi de charger au contact d'une grande cible.
	for index in range(get_slide_collision_count()):
		if get_slide_collision(index).get_collider() == current_target:
			attack(current_target)
			break


func attack(victim: Node2D) -> void:
	if dead or is_attacking or cooldown_remaining > 0.0:
		return
	if not is_instance_valid(victim):
		return

	var direction := global_position.direction_to(victim.global_position)
	if not direction.is_zero_approx():
		dash_direction = direction
	attack_zone.global_rotation = dash_direction.angle()
	dash_hits.clear()

	# La direction reste verrouillée jusqu'à la fin de la charge.
	dash_remaining = maxf(dash_duration, 0.01)
	is_attacking = true
	velocity = dash_direction * dash_speed
	update_animation(dash_direction, true)


func process_dash(delta: float) -> void:
	var step := minf(delta, dash_remaining)
	velocity = dash_direction * dash_speed
	var collision := move_and_collide(velocity * step)
	dash_remaining -= step
	damage_in_attack_zone()

	if collision != null:
		# Les obstacles arrêtent le mouvement ; le rectangle gère les dégâts.
		finish_dash()
	elif dash_remaining <= 0.0:
		finish_dash()


func damage_in_attack_zone() -> void:
	if not is_attacking or attack_shape.disabled or not attack_zone.monitoring:
		return

	# La requête suit le rectangle immédiatement après sa rotation et son déplacement.
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = attack_shape.shape
	query.transform = attack_shape.global_transform
	query.collision_mask = attack_zone.collision_mask
	query.exclude = [get_rid()]
	var overlaps := get_world_2d().direct_space_state.intersect_shape(query, 64)

	for overlap in overlaps:
		var body = overlap["collider"]
		if not is_instance_valid(body) or body.is_queued_for_deletion():
			continue
		if body.is_in_group("enemies") or not body.has_method("take_damage"):
			continue
		var body_id: int = body.get_instance_id()
		if dash_hits.has(body_id):
			continue
		dash_hits[body_id] = true
		body.take_damage(damage)


func finish_dash() -> void:
	is_attacking = false
	dash_remaining = 0.0
	cooldown_remaining = maxf(attack_cooldown, 0.0)
	velocity = Vector2.ZERO
	update_animation(dash_direction, false)


func update_animation(direction: Vector2, moving: bool) -> void:
	if direction.is_zero_approx():
		animated_sprite.stop()
		return

	var sector := posmod(int(round(direction.angle() / (PI / 4.0))), 8)
	var animation: StringName = WALK_ANIMATIONS[sector]
	if moving:
		animated_sprite.play(animation)
	else:
		animated_sprite.animation = animation
		animated_sprite.stop()


func focus_player(player: Node2D) -> void:
	target = player


func return_to_coop() -> void:
	target = null


func take_damage(amount: float) -> void:
	if dead or is_queued_for_deletion():
		return
	health -= amount
	if health <= 0.0:
		dead = true
		drop_item()
		queue_free()


func drop_item() -> void:
	var world := get_tree().current_scene as Node2D
	if world == null:
		return
	var item = ITEM_SCENE.instantiate()
	item.item_type = ITEM_TYPES.pick_random()
	item.position = world.to_local(global_position)
	world.add_child.call_deferred(item)
