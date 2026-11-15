extends CharacterBody2D
signal defeated
## Boss « Easter Bunny » : il ne fait que sauter vers sa cible.
## Chaque saut est à la fois son déplacement et son attaque : à l'atterrissage,
## tout ce qui est dans attack_zone (joueur, poulailler) prend `damage` points de dégâts.

const ITEM_SCENE = preload("res://scences/item_au_sol.tscn")
const HIT_PARTICLES = preload("res://sang_particule.tscn")
const SOUND_EFFECT = preload("res://scripts/sound_effect.gd")
const ATTACK_SOUND = preload("res://sounds/attack_renard.wav")
const DAMAGE_SOUND = preload("res://sounds/degat_renard.wav")
const DEATH_SOUND = preload("res://sounds/mort_renard.wav")
const ITEM_TYPES = ["grenade", "tp", "nuke"]

enum State { IDLE, JUMPING }

@export var max_health: float = 5000.0
@export var damage: float = 25.0                  ## dégâts infligés à chaque atterrissage
@export var max_jump_distance: float = 450.0      ## distance max parcourue par saut (px)
@export var jump_height: float = 160.0            ## hauteur visuelle du saut (px)
@export var pause_between_jumps: float = 0.35     ## temps au sol entre deux sauts (s)
@export var max_damage_per_hit: float = 1000.0    ## plafond par coup (évite que la nuke one-shot le boss). 0 = pas de plafond
@export var default_target: Node2D

## Frames de l'animation (down_jump / up_jump) : 0 = accroupi, 1..5 = en l'air, 6 = atterrissage.
@export var first_air_frame: int = 1
@export var landing_frame: int = 6

# Objet forcé à la mort (tutoriel). Vide = drop aléatoire.
var forced_drop: String = ""

@onready var health: float = max_health
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var health_bar: ProgressBar = $AnimatedSprite2D/HealthBar
@onready var jump_sound: AudioStreamPlayer2D = $SonSaut
@onready var attack_zone: Area2D = $attack_zone
@onready var attack_shape: CollisionShape2D = $attack_zone/CollisionShape2D
@onready var shadow: Sprite2D = $Ombre

var target: Node2D
var state: State = State.IDLE
var dead: bool = false
var pause_remaining: float = 0.0
var jump_velocity: Vector2 = Vector2.ZERO
var air_time: float = 0.0
var air_duration: float = 1.0
var has_landed: bool = false
var sprite_base_position: Vector2
var shadow_base_scale: Vector2


func _ready() -> void:
	add_to_group("enemies")
	health_bar.max_value = max_health
	health_bar.value = health
	# Même calques que les autres ennemis : calque 2 (touché par les balles et
	# détecté par le joueur), collisions avec le joueur/décor (1) et les ennemis (2).
	collision_layer = 2
	collision_mask = 3
	sprite_base_position = animated_sprite.position
	shadow_base_scale = shadow.scale
	animated_sprite.frame_changed.connect(_on_frame_changed)
	animated_sprite.animation_looped.connect(_on_jump_animation_finished)
	animated_sprite.animation_finished.connect(_on_jump_animation_finished)
	animated_sprite.animation = &"down_jump"
	animated_sprite.frame = 0
	animated_sprite.stop()
	pause_remaining = pause_between_jumps


func _physics_process(delta: float) -> void:
	if dead:
		return

	match state:
		State.IDLE:
			velocity = Vector2.ZERO
			pause_remaining -= delta
			if pause_remaining <= 0.0:
				start_jump()
		State.JUMPING:
			process_jump(delta)


func current_target() -> Node2D:
	if is_instance_valid(target) and not target.is_queued_for_deletion():
		return target
	if is_instance_valid(default_target):
		return default_target
	return null


func start_jump() -> void:
	var goal := current_target()
	if goal == null:
		pause_remaining = pause_between_jumps
		return

	# On vise avec la zone d'attaque (aux pieds), pas avec le centre du corps :
	# c'est elle qui doit retomber pile sur la cible.
	var feet_offset := attack_shape.global_position - global_position
	var to_goal := goal.global_position - (global_position + feet_offset)
	var direction := to_goal.normalized() if not to_goal.is_zero_approx() else Vector2.DOWN
	var distance := minf(to_goal.length(), max_jump_distance)

	# Face ou dos selon la direction du saut.
	var animation: StringName = &"down_jump" if direction.y >= 0.0 else &"up_jump"

	# Durée passée en l'air = durée des frames first_air_frame..landing_frame-1.
	air_duration = frames_duration(animation, first_air_frame, landing_frame)
	# On vise pile la cible : si elle est à portée, il atterrit dessus.
	jump_velocity = direction * (distance / maxf(air_duration, 0.01))

	air_time = 0.0
	has_landed = false
	state = State.JUMPING
	jump_sound.play()
	animated_sprite.play(animation)
	animated_sprite.frame = 0


func process_jump(delta: float) -> void:
	var frame := animated_sprite.frame
	var airborne := frame >= first_air_frame and frame < landing_frame

	if airborne:
		air_time += delta
		# En l'air, il passe au-dessus de tout : pas de collision, sinon le corps du
		# joueur le bloquerait avant qu'il ne retombe dessus. Comme il ne se
		# déplace qu'en l'air, il ne peut jamais rester coincé dans un obstacle ;
		# à l'atterrissage, c'est le joueur qui est repoussé hors du boss.
		velocity = jump_velocity
		global_position += jump_velocity * delta
		# Hauteur visuelle : seul le sprite monte, la hitbox et l'ombre restent au sol.
		var t := clampf(air_time / maxf(air_duration, 0.01), 0.0, 1.0)
		var height := sin(t * PI) * jump_height
		animated_sprite.position = sprite_base_position + Vector2(0.0, -height)
		shadow.scale = shadow_base_scale * lerpf(1.0, 0.6, height / maxf(jump_height, 1.0))
	else:
		velocity = Vector2.ZERO
		animated_sprite.position = sprite_base_position
		shadow.scale = shadow_base_scale


func _on_frame_changed() -> void:
	if state == State.JUMPING and not has_landed and animated_sprite.frame == landing_frame:
		land()


func land() -> void:
	has_landed = true
	animated_sprite.position = sprite_base_position
	shadow.scale = shadow_base_scale
	SOUND_EFFECT.play_at(ATTACK_SOUND, self)
	damage_in_attack_zone()


func _on_jump_animation_finished() -> void:
	if state != State.JUMPING:
		return
	if not has_landed:
		land()
	# Fin du saut : on reste sur la pose d'atterrissage puis on repart.
	animated_sprite.stop()
	animated_sprite.frame = landing_frame
	state = State.IDLE
	pause_remaining = pause_between_jumps


func damage_in_attack_zone() -> void:
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = attack_shape.shape
	query.transform = attack_shape.global_transform
	query.collision_mask = attack_zone.collision_mask
	query.exclude = [get_rid()]
	var hit_ids := {}
	for overlap in get_world_2d().direct_space_state.intersect_shape(query, 64):
		var body = overlap["collider"]
		if not is_instance_valid(body) or body.is_queued_for_deletion():
			continue
		if body.is_in_group("enemies") or not body.has_method("take_damage"):
			continue
		if hit_ids.has(body.get_instance_id()):
			continue
		hit_ids[body.get_instance_id()] = true
		body.take_damage(damage)


func frames_duration(animation: StringName, from_frame: int, to_frame: int) -> float:
	var frames := animated_sprite.sprite_frames
	var fps := frames.get_animation_speed(animation) * absf(animated_sprite.speed_scale)
	if fps <= 0.0:
		return 1.0
	var total := 0.0
	for i in range(from_frame, mini(to_frame, frames.get_frame_count(animation))):
		total += frames.get_frame_duration(animation, i)
	return total / fps


func focus_player(player: Node2D) -> void:
	target = player


func return_to_coop() -> void:
	target = null


func take_damage(amount: float) -> void:
	if dead or is_queued_for_deletion() or amount <= 0.0:
		return
	if max_damage_per_hit > 0.0:
		amount = minf(amount, max_damage_per_hit)
	spawn_hit_particles()
	health -= amount
	health_bar.value = maxf(0.0, health)
	SOUND_EFFECT.play_at(DEATH_SOUND if health <= 0.0 else DAMAGE_SOUND, self)
	if health <= 0.0:
		dead = true
		drop_item()
		defeated.emit()
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
	var item = ITEM_SCENE.instantiate()
	item.item_type = forced_drop if forced_drop != "" else ITEM_TYPES.pick_random()
	item.position = world.to_local(global_position)
	world.add_child.call_deferred(item)
