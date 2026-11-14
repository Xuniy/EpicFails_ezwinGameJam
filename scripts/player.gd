extends CharacterBody2D

const WALK_ANIMATIONS = [
	&"walk_right", &"walk_down_right", &"walk_down", &"walk_down_left",
	&"walk_left", &"walk_up_left", &"walk_up", &"walk_up_right"
]

@export var speed: float = 300.0
@export_range(0.1, 1.0, 0.05) var dezoom_factor: float = 3

@onready var camera: Camera2D = $Camera2D
@onready var normal_zoom: Vector2 = camera.zoom
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

@export var max_health: float = 100.0
@onready var health: float = max_health

func _ready() -> void:
	$detection_ennemy.body_entered.connect(_on_enemy_entered)
	$detection_ennemy.body_exited.connect(_on_enemy_exited)


func _on_enemy_entered(body: Node2D) -> void:
	if body.is_in_group("enemies"):
		body.focus_player(self)


func _on_enemy_exited(body: Node2D) -> void:
	if body.is_in_group("enemies"):
		body.return_to_coop()


func _process(_delta: float) -> void:
	if Input.is_action_pressed("dezoom"):
		camera.zoom = normal_zoom * dezoom_factor
	else:
		camera.zoom = normal_zoom


func _physics_process(_delta: float) -> void:
	var direction := Input.get_vector(
		"gauche", "droite", "haut", "bas"
	)
	velocity = direction * speed
	move_and_slide()
	update_animation(direction)


func update_animation(direction: Vector2) -> void:
	if direction.is_zero_approx():
		# Première image de la dernière direction pour la pose au repos.
		animated_sprite.stop()
		return

	var sector := posmod(int(round(direction.angle() / (PI / 4.0))), 8)
	# Les directions droite et bas-gauche réutilisent les planches opposées.
	animated_sprite.flip_h = sector == 0 or sector == 3
	animated_sprite.play(WALK_ANIMATIONS[sector])


func take_damage(amount: float) -> void:
	if health <= 0.0:
		return

	health = clampf(health - amount, 0.0, max_health)
	print("[Player] Vie : ", health, "/", max_health)

	if health <= 0.0:
		print("[Player] Mort !")
