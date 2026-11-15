extends CharacterBody2D

const ITEM_SCENE = preload("res://scences/item_au_sol.tscn")
const HIT_PARTICLES = preload("res://sang_particule.tscn")
const DASH_EFFECT = preload("res://scences/fox_dash_effect.tscn")
const SOUND_EFFECT = preload("res://scripts/sound_effect.gd")
const ATTACK_SOUND = preload("res://sounds/attack_renard.wav")
const DAMAGE_SOUND = preload("res://sounds/degat_renard.wav")
const DEATH_SOUND = preload("res://sounds/mort_renard.wav")
# Dix issues équiprobables : TP 30 %, grenade 20 %, nuke 10 %, rien 40 %.
const ITEM_TYPES = ["tp", "tp", "tp", "grenade", "grenade", "nuke", "", "", "", ""]
const WALK_ANIMATIONS = [
	&"walk_right", &"walk_down_right", &"walk_down", &"walk_down_left",
	&"walk_left", &"walk_up_left", &"walk_up", &"walk_up_right"
]

@export var speed: float = 80.0
@export var health: float = 10.0
@export_range(-40.0, 0.0, 1.0) var sound_volume_db: float = -6.0

# Objet forcé à la mort (tutoriel). Vide = drop aléatoire.
var forced_drop: String = ""
@export var damage: float = 2.0
@export var attack_distance: float = 140.0
@export var dash_speed: float = 600.0
@export var dash_duration: float = 0.35
@export var dash_windup: float = 0.4
@export var attack_cooldown: float = 1.2
@export var default_target: Node2D
@export var player_only: bool = false

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_zone: Area2D = $attack_zone
@onready var attack_shape: CollisionShape2D = $attack_zone/CollisionShape2D

var target: Node2D
var is_attacking: bool = false
var is_preparing: bool = false
var windup_remaining: float = 0.0
var _dash_target: Node2D
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

	if is_preparing:
		velocity = Vector2.ZERO
		windup_remaining -= delta
		if windup_remaining <= 0.0:
			start_dash()
		return

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
	if dead or is_attacking or is_preparing or cooldown_remaining > 0.0:
		return
	if not is_instance_valid(victim):
		return

	_dash_target = victim
	is_preparing = true
	windup_remaining = maxf(dash_windup, 0.0)
	velocity = Vector2.ZERO
	update_animation(global_position.direction_to(victim.global_position), false)
	if windup_remaining <= 0.0:
		start_dash()


func start_dash() -> void:
	is_preparing = false
	windup_remaining = 0.0
	if not is_instance_valid(_dash_target) or _dash_target.is_queued_for_deletion():
		finish_dash()
		return

	var direction := global_position.direction_to(_dash_target.global_position)
	if not direction.is_zero_approx():
		dash_direction = direction
	attack_zone.global_rotation = dash_direction.angle()
	dash_hits.clear()

	# La direction reste verrouillée jusqu'à la fin de la charge.
	dash_remaining = maxf(dash_duration, 0.01)
	is_attacking = true
	SOUND_EFFECT.play_at(ATTACK_SOUND, self, sound_volume_db)
	velocity = dash_direction * dash_speed
	update_animation(dash_direction, true)
	spawn_dash_effect()


func spawn_dash_effect() -> void:
	var world := get_tree().current_scene as Node2D
	if world == null:
		return
	var effect := DASH_EFFECT.instantiate() as Node2D
	effect.source = self
	effect.direction = dash_direction
	effect.position = world.to_local(global_position)
	world.add_child(effect)


func process_dash(delta: float) -> void:
	if not is_attacking:
		return
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
		if player_only and body != default_target:
			continue
		var body_id: int = body.get_instance_id()
		if dash_hits.has(body_id):
			continue
		dash_hits[body_id] = true
		body.take_damage(damage)


func finish_dash() -> void:
	is_attacking = false
	is_preparing = false
	windup_remaining = 0.0
	_dash_target = null
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
	if dead or is_queued_for_deletion() or amount <= 0.0:
		return
	spawn_hit_particles()
	health -= amount
	SOUND_EFFECT.play_at(DEATH_SOUND if health <= 0.0 else DAMAGE_SOUND, self, sound_volume_db)
	if health <= 0.0:
		dead = true
		drop_item()
		queue_free()


func spawn_hit_particles() -> void:
	var world := get_tree().current_scene as Node2D
	if world == null:
		return
	var effect := HIT_PARTICLES.instantiate() as GPUParticles2D
	effect.position = world.to_local(global_position)
	world.add_child(effect)
	effect.restart()


func drop_item() -> void:
	var world := get_tree().current_scene as Node2D
	if world == null:
		return
	var item_type: String = forced_drop if forced_drop != "" else ITEM_TYPES.pick_random()
	if item_type == "":
		return
	var item = ITEM_SCENE.instantiate()
	item.item_type = item_type
	item.position = world.to_local(global_position)
	world.add_child.call_deferred(item)
