extends CharacterBody2D

const WALK_ANIMATIONS = [
	&"walk_right", &"walk_down_right", &"walk_down", &"walk_down_left",
	&"walk_left", &"walk_up_left", &"walk_up", &"walk_up_right"
]
const ITEM_LANCE_SCENE = preload("res://scences/item_lance.tscn")
const NUKE_SCENE = preload("res://scences/nuke.tscn")

const ITEM_TEXTURES = {
	"grenade": preload("res://assets/eggrenade.png"),
	"tp": preload("res://assets/eggderpearl.png")
}
@export var speed: float = 300.0
@export_range(0.1, 1.0, 0.05) var dezoom_factor: float = 3

@onready var camera: Camera2D = $Camera2D
@onready var normal_zoom: Vector2 = camera.zoom
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2DPlayer
@onready var fume: AnimatedSprite2D = $AnimatedSprite2DFumee
@onready var item_aim: Node2D = $Item_Aim

var aiming_item: bool = false
var pending_item: String
var facing_direction: Vector2 = Vector2.RIGHT
@onready var smoke_points := {
	&"walk_down": $pos_fume/bas,
	&"walk_down_left": $pos_fume/bas_gauche,
	&"walk_down_right": $pos_fume/bas_gauche,
	&"walk_left": $pos_fume/gauche,
	&"walk_right": $pos_fume/gauche,
	&"walk_up": $pos_fume/haut,
	&"walk_up_left": $pos_fume/haut_gauche,
	&"walk_up_right": $pos_fume/haut_droite,
}
var items := {
	"grenade": 0,
	"tp": 0,
	"nuke": 0
}
var item_order := ["grenade", "tp", "nuke"]
var selected_index: int = 0

var selected_item: String:
	get:
		return item_order[selected_index]


@export var max_health: float = 100.0
@onready var health: float = max_health

func _ready() -> void:
	$detection_ennemy.body_entered.connect(_on_enemy_entered)
	$detection_ennemy.body_exited.connect(_on_enemy_exited)
	fume.play("fume")
	update_smoke_position()
	
func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return

	# Maintenir pour viser.
	if event.is_action_pressed("use_item"):
		if items[selected_item] > 0:
			pending_item = selected_item
			aiming_item = true
		else:
			print("Aucun exemplaire de : ", selected_item)

	elif event.is_action_released("use_item"):
		aiming_item = false

	# Appuyer sur un AUTRE bouton pour lancer.
	elif event.is_action_pressed("tir"):
		if aiming_item and Input.is_action_pressed("use_item"):
			var target: Vector2 = (
				item_aim.global_position
				+ item_aim.aim_direction * item_aim.distance
			)

			use_item_at(pending_item, target)

			if items[pending_item] <= 0:
				aiming_item = false

	elif not aiming_item:
		if event.is_action_pressed("ui_droite"):
			selected_index = posmod(
				selected_index + 1, item_order.size()
			)

		elif event.is_action_pressed("ui_gauche"):
			selected_index = posmod(
				selected_index - 1, item_order.size()
			)
func _on_enemy_entered(body: Node2D) -> void:
	if body.is_in_group("enemies"):
		body.focus_player(self)


func _on_enemy_exited(body: Node2D) -> void:
	if body.is_in_group("enemies"):
		body.return_to_coop()


func _process(_delta: float) -> void:
	var target: Vector2 = (item_aim.global_position+ item_aim.aim_direction * item_aim.distance)

	update_camera_zoom(
		target,
		Input.is_action_pressed("use_item")
	)
	



func update_camera_zoom(target: Vector2, aiming: bool) -> void:
	var desired_zoom := normal_zoom

	if Input.is_action_pressed("dezoom"):
		desired_zoom *= dezoom_factor

	if aiming:
		camera.force_update_scroll()

		var screen_size := get_viewport().get_visible_rect().size
		var available := (screen_size * 0.5 - Vector2(100, 100)).max(
			Vector2.ONE
		)

		var offset := target - camera.get_screen_center_position()

		if not camera.ignore_rotation:
			offset = offset.rotated(-camera.global_rotation)

		# Distance de la cible au centre, exprimée en pixels écran.
		var projected := Vector2(
			absf(offset.x) * desired_zoom.x,
			absf(offset.y) * desired_zoom.y
		)

		var factor := minf(
			1.0,
			minf(
				available.x / maxf(projected.x, 0.001),
				available.y / maxf(projected.y, 0.001)
			)
		)

		desired_zoom *= factor

	camera.zoom = desired_zoom
	camera.force_update_scroll()




func _physics_process(_delta: float) -> void:
	var direction := Input.get_vector(
		"gauche", "droite", "haut", "bas"
	)
	velocity = direction * speed
	move_and_slide()
	update_animation(direction)


func update_animation(direction: Vector2) -> void:
	var aim := Input.get_vector(
		"sr_gauche", "sr_droite", "sr_haut", "sr_bas"
	)
	if not aim.is_zero_approx():
		facing_direction = aim
	elif Input.is_action_pressed("tir"):
		# Sans entrée de visée, l'arme conserve sa dernière direction.
		facing_direction = $Weapon.last_aim_direction
	elif not direction.is_zero_approx():
		facing_direction = direction

	var sector := posmod(int(round(facing_direction.angle() / (PI / 4.0))), 8)
	# Les directions droite et bas-gauche réutilisent les planches opposées.
	animated_sprite.flip_h = sector == 0 or sector == 3
	if direction.is_zero_approx():
		animated_sprite.animation = WALK_ANIMATIONS[sector]
		animated_sprite.stop()
	else:
		animated_sprite.play(WALK_ANIMATIONS[sector])
	update_smoke_position()

func take_damage(amount: float) -> void:
	if health <= 0.0:
		return

	health = clampf(health - amount, 0.0, max_health)
	print("[Player] Vie : ", health, "/", max_health)

	if health <= 0.0:
		print("[Player] Mort !")
		
		
func collect_item(item_type: String) -> bool:
	if not items.has(item_type):
		return false

	items[item_type] += 1

	print("[Item] Ramassé : ", item_type,
		" | Quantité : ", items[item_type])

	return true
	
func update_smoke_position() -> void:
	var animation := animated_sprite.animation
	var marker: Marker2D = smoke_points.get(animation)

	if marker == null:
		return

	var local_position := marker.position

	if animation in [&"walk_right", &"walk_down_left"]:
		local_position.x = -local_position.x

	fume.global_position = $pos_fume.to_global(local_position)
func teleport_to(target: Vector2) -> bool:
	var shape_node: CollisionShape2D = $player_collision
	var query := PhysicsShapeQueryParameters2D.new()

	query.shape = shape_node.shape

	var destination_transform := shape_node.global_transform
	destination_transform.origin += target - global_position
	query.transform = destination_transform

	query.collision_mask = collision_mask | 2
	query.exclude = [get_rid()]

	var obstacles := get_world_2d().direct_space_state.intersect_shape(query)

	if not obstacles.is_empty():
		return false

	global_position = target
	return true
func use_item_at(item_type: String, target: Vector2) -> void:
	if not items.has(item_type) or items[item_type] <= 0:
		return

	match item_type:
		"grenade", "tp":
			var projectile = ITEM_LANCE_SCENE.instantiate()

			projectile.item_type = item_type
			projectile.thrower = self
			projectile.get_node("Sprite2D").texture = ITEM_TEXTURES[item_type]

			get_tree().current_scene.add_child(projectile)

			projectile.launch(
				item_aim.global_position,
				target,
				item_aim.arc_height
			)

		"nuke":
			var nuke = NUKE_SCENE.instantiate()
			get_tree().current_scene.add_child(nuke)
			nuke.global_position = target

		_:
			return

	items[item_type] -= 1
