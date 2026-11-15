extends CharacterBody2D

const ITEM_SCENE = preload("res://scences/item_au_sol.tscn")
const HIT_PARTICLES = preload("res://sang_particule.tscn")
const FORK_SLASH = preload("res://scripts/fork_slash_effect.gd")
const SOUND_EFFECT = preload("res://scripts/sound_effect.gd")
const ATTACK_SOUND = preload("res://sounds/attack_fermier.wav")
const DAMAGE_SOUND = preload("res://sounds/degat_fermier.wav")
const DEATH_SOUND = preload("res://sounds/mort_fermier.wav")
const ITEM_TYPES = ["grenade", "tp", "nuke"]
const WALK_ANIMATIONS = [
	&"walk_right", &"walk_down_right", &"walk_down", &"walk_down_left",
	&"walk_left", &"walk_up_left", &"walk_up", &"walk_up_right"
]

@export var speed: float = 80.0
@export var health: float = 15.0
@export var damage: float = 2.0
@export var stop_distance: float = 24.0
@export var attack_distance: float = 120
@export var attack_windup: float = 0.1
@export var attack_cooldown: float = 1.0
var is_attacking: bool = false

@onready var attack_zone: Area2D = $attack_zone
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var fourche_pivot: Node2D = get_node_or_null("fourche_pivot")
@onready var fourche: Sprite2D = get_node_or_null("fourche_pivot/fourche")
@onready var fourche_stoique: Sprite2D = get_node_or_null("fourche_stoique")


# Le point à rejoindre au poulailler, donné par le spawner.
@export var default_target: Node2D

# Cible prioritaire : le joueur lorsqu'il est détecté.
var target: Node2D


func _ready() -> void:
	add_to_group("enemies")
	if fourche != null:
		fourche.hide()
	if fourche_stoique != null:
		fourche_stoique.show()
	update_fork_depth()


func _physics_process(_delta: float) -> void:
	
	if is_attacking:
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

	var distance := global_position.distance_to(
		current_target.global_position
	)

	if distance <= attack_distance:
		attack(current_target)
		return

	var direction := global_position.direction_to(current_target.global_position)
	update_animation(direction, true)
	velocity = direction * speed
	move_and_slide()
	
	for index in range(get_slide_collision_count()):
		var collision := get_slide_collision(index)

		if collision.get_collider() == current_target:
			attack(current_target)
			break
		
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
	update_fork_depth()


func update_fork_depth() -> void:
	var behind: bool = animated_sprite.animation in [
		&"walk_up", &"walk_up_left", &"walk_up_right"
	]
	var depth := -1 if behind else 1
	if fourche_pivot != null:
		fourche_pivot.z_index = depth
	if fourche_stoique != null:
		fourche_stoique.z_index = depth


func focus_player(player: Node2D) -> void:
	target = player
	print("[Enemy] Joueur détecté : poursuite.")


func return_to_coop() -> void:
	target = null
	print("[Enemy] Joueur sorti de la zone : retour au poulailler.")


func take_damage(amount: float) -> void:
	if amount <= 0.0 or health <= 0.0 or is_queued_for_deletion():
		return
	spawn_hit_particles()
	health -= amount
	SOUND_EFFECT.play_at(DEATH_SOUND if health <= 0.0 else DAMAGE_SOUND, self)

	if health <= 0.0:
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


func attack(victim: Node2D) -> void:
	is_attacking = true
	SOUND_EFFECT.play_at(ATTACK_SOUND, self)
	velocity = Vector2.ZERO
	update_animation(global_position.direction_to(victim.global_position), false)

	# Oriente le coup, puis garde cette direction.
	attack_zone.global_rotation = global_position.direction_to(
		victim.global_position
	).angle()

	if fourche_pivot != null and fourche != null:
		# Le fermier anime sa fourche pendant la préparation du coup.
		fourche_pivot.global_rotation = attack_zone.global_rotation
		var base_angle := fourche_pivot.rotation
		var slash = FORK_SLASH.new()
		slash.name = "ForkSlash"
		slash.transform = fourche_pivot.transform
		slash.z_index = fourche_pivot.z_index
		slash.swing_duration = maxf(attack_windup, 0.01)
		add_child(slash)
		fourche_pivot.rotation = base_angle - deg_to_rad(35.0)
		if fourche_stoique != null:
			fourche_stoique.hide()
		fourche.show()

		var tween := create_tween()
		tween.tween_property(
			fourche_pivot,
			"rotation",
			base_angle + deg_to_rad(35.0),
			maxf(attack_windup, 0.01)
		)
		await tween.finished

		fourche.hide()
		if fourche_stoique != null:
			fourche_stoique.show()
	else:
		# Les ennemis sans arme gardent leur pose pendant ce délai.
		await get_tree().create_timer(maxf(attack_windup, 0.01)).timeout

	for body in attack_zone.get_overlapping_bodies():
		if body == default_target or body == target:
			if body.has_method("take_damage"):
				body.take_damage(damage)
				print("[Fermier] Coup touché : ", body.name)

	await get_tree().create_timer(attack_cooldown).timeout
	is_attacking = false

func drop_item() -> void:
	var item = ITEM_SCENE.instantiate()
	item.item_type = ITEM_TYPES.pick_random()

	var world := get_tree().current_scene as Node2D

	# Position de l'ennemi, convertie dans le repère du monde.
	item.position = world.to_local(global_position)

	# Ajout différé pour éviter de modifier les collisions
	# pendant le traitement d'un impact de balle.
	world.add_child.call_deferred(item)
