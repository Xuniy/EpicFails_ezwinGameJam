extends CharacterBody2D

signal hit_received

const WALK_ANIMATIONS = [
	&"walk_right", &"walk_down_right", &"walk_down", &"walk_down_left",
	&"walk_left", &"walk_up_left", &"walk_up", &"walk_up_right"
]
const ITEM_LANCE_SCENE = preload("res://scences/item_lance.tscn")
const NUKE_SCENE = preload("res://scences/nuke.tscn")
const SOUND_EFFECT = preload("res://scripts/sound_effect.gd")
const TELEPORT_SOUND = preload("res://sounds/bruit_tp.wav")
const TELEPORT_EFFECT = preload("res://scences/teleport_effect.tscn")
const WALK_SOUND = preload("res://sounds/marche_player.wav")
const DAMAGE_SOUND = preload("res://sounds/degats_player.wav")

var walk_sound: AudioStreamPlayer2D

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
var mouse_aim_active: bool = false
var _last_mouse_position := Vector2.ZERO
var _right_was_down: bool = false
var _left_was_down: bool = false
var _left_consumed: bool = false
var _throw_trigger_held: bool = false
# Dézoom du lancer : reste actif jusqu'au relâchement du clic droit, même après validation.
var _throw_zoom_active: bool = false
var _last_throw_target := Vector2.ZERO

var selected_item: String:
	get:
		return item_order[selected_index]


@export var max_health: float = 100.0
@onready var health: float = max_health

func _ready() -> void:
	walk_sound = AudioStreamPlayer2D.new()
	walk_sound.name = "SonMarche"
	walk_sound.stream = WALK_SOUND
	add_child(walk_sound)
	$detection_ennemy.body_entered.connect(_on_enemy_entered)
	$detection_ennemy.body_exited.connect(_on_enemy_exited)
	fume.play("fume")
	_last_mouse_position = get_viewport().get_mouse_position()
	update_smoke_position()
	
# Molette lue avant l'interface : un Control ne peut pas la bloquer.
func _input(event: InputEvent) -> void:
	if event.is_action_released("tir"):
		# Une gâchette analogique doit revenir au repos pour autoriser un autre lancer.
		if not event is InputEventJoypadMotion or absf(event.axis_value) <= 0.05:
			_throw_trigger_held = false
	if event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		if click.pressed:
			if click.button_index == MOUSE_BUTTON_WHEEL_UP:
				cycle_item(-1)
			elif click.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				cycle_item(1)


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
		if _throw_trigger_held:
			return
		_throw_trigger_held = true
		if aiming_item and Input.is_action_pressed("use_item"):
			var target: Vector2 = (
				item_aim.global_position
				+ item_aim.aim_direction * item_aim.distance
			)

			use_item_at(pending_item, target)

			if items[pending_item] <= 0:
				aiming_item = false

	elif event.is_action_pressed("ui_droite"):
		cycle_item(1)
	elif event.is_action_pressed("ui_gauche"):
		cycle_item(-1)
func is_mouse_aiming() -> bool:
	return mouse_aim_active


# Visée : le stick est prioritaire ; sinon, l'arme regarde le curseur souris.
func get_aim_input() -> Vector2:
	var stick := Input.get_vector("sr_gauche", "sr_droite", "sr_haut", "sr_bas")
	if not stick.is_zero_approx() or not mouse_aim_active:
		return stick
	var offset := get_global_mouse_position() - global_position
	if offset.length() < 4.0:
		return Vector2.ZERO
	return offset.normalized()


# Tir : gâchette droite (manette) ou clic gauche (souris).
func is_firing() -> bool:
	var mouse_fire := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not _left_consumed and mouse_throw_item == ""
	return Input.is_action_pressed("tir") or mouse_fire


func cycle_item(step: int) -> void:
	selected_index = posmod(selected_index + step, item_order.size())
	if Input.is_action_pressed("use_item"):
		pending_item = selected_item
		aiming_item = items[selected_item] > 0
	if mouse_throw_item != "":
		mouse_throw_item = selected_item if items[selected_item] > 0 else ""


# Clic droit maintenu : visée au curseur, l'item part vers la souris (jusqu'à max_distance).
# Clic gauche pour lancer, relâcher le droit annule. Dézoom si le curseur sort de l'écran.
var mouse_throw_item: String = ""


func is_item_aiming() -> bool:
	return Input.is_action_pressed("use_item") or mouse_throw_item != ""


func start_mouse_throw() -> void:
	if items[selected_item] <= 0:
		print("Aucun exemplaire de : ", selected_item)
		return
	mouse_throw_item = selected_item
	_throw_zoom_active = true


# Point visé : la souris, ramenée à la portée maximale de l'item (pas de traction).
func get_throw_target() -> Vector2:
	var origin := item_aim.global_position
	var offset := get_global_mouse_position() - origin
	if offset.length() < 1.0:
		return origin
	return origin + offset.normalized() * minf(offset.length(), item_aim.max_distance)


func cancel_mouse_throw() -> void:
	mouse_throw_item = ""
	_throw_zoom_active = false


func release_mouse_throw() -> void:
	if mouse_throw_item == "":
		return
	var item := mouse_throw_item
	var target := get_throw_target()
	mouse_throw_item = ""
	use_item_at(item, target)


func _on_enemy_entered(body: Node2D) -> void:
	if body.is_in_group("enemies"):
		body.focus_player(self)


func _on_enemy_exited(body: Node2D) -> void:
	if body.is_in_group("enemies"):
		body.return_to_coop()


func _process(delta: float) -> void:
	var target: Vector2 = (item_aim.global_position+ item_aim.aim_direction * item_aim.distance)

	if mouse_throw_item != "":
		_last_throw_target = get_throw_target()
	if _throw_zoom_active:
		target = _last_throw_target
	update_camera_zoom(
		target,
		is_item_aiming() or _throw_zoom_active,
		delta
	)
	



# Vitesse du dézoom : lissée pour éviter les à-coups quand le curseur sort de l'écran.
const ZOOM_SMOOTHNESS: float = 10.0


func update_camera_zoom(target: Vector2, aiming: bool, delta: float) -> void:
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

	camera.zoom = camera.zoom.lerp(desired_zoom, minf(1.0, delta * ZOOM_SMOOTHNESS))
	camera.force_update_scroll()




# Souris lue à chaque frame : visée au curseur et clic droit (arc).
func _update_mouse_input() -> void:
	var mouse := get_viewport().get_mouse_position()
	var stick := Input.get_vector("sr_gauche", "sr_droite", "sr_haut", "sr_bas")
	var clicking := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	if stick.length() > 0.2:
		mouse_aim_active = false
	elif mouse.distance_squared_to(_last_mouse_position) > 0.25 or clicking:
		mouse_aim_active = true
	_last_mouse_position = mouse
	var right_down := Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	if right_down != _right_was_down:
		_right_was_down = right_down
		if right_down:
			start_mouse_throw()
		else:
			cancel_mouse_throw()
	# Clic gauche pendant la visée : valide le lancer, sans tirer à l'arme.
	var left_down := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if not left_down:
		_left_consumed = false
	elif not _left_was_down and mouse_throw_item != "":
		release_mouse_throw()
		_left_consumed = true
	_left_was_down = left_down


func _physics_process(_delta: float) -> void:
	_update_mouse_input()
	var direction := Input.get_vector(
		"gauche", "droite", "haut", "bas"
	)
	velocity = direction * speed
	var previous_position := global_position
	move_and_slide()
	_update_walk_sound(not global_position.is_equal_approx(previous_position))
	update_animation(direction)


func _update_walk_sound(moving: bool) -> void:
	if moving and health > 0.0:
		if not walk_sound.playing:
			walk_sound.play()
	else:
		walk_sound.stop()


func update_animation(direction: Vector2) -> void:
	var aim := get_aim_input()
	if not aim.is_zero_approx():
		facing_direction = aim
	elif is_firing():
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

func take_damage(amount: float, show_hit_effect: bool = true) -> void:
	if health <= 0.0:
		return

	var previous_health := health
	health = clampf(health - amount, 0.0, max_health)
	if show_hit_effect and health < previous_health:
		hit_received.emit()
	if amount > 0.0 and health > 0.0:
		SOUND_EFFECT.play_at(DAMAGE_SOUND, self)
	print("[Player] Vie : ", health, "/", max_health)

	if health <= 0.0:
		walk_sound.stop()
		print("[Player] Mort !")
		EndScreen.show_end(get_tree(), "Chicken Norris est mort")
		
		
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

	var origin := global_position
	global_position = target
	var effect = TELEPORT_EFFECT.instantiate()
	get_tree().current_scene.add_child(effect)
	effect.setup(origin, target, animated_sprite)
	SOUND_EFFECT.play_at(TELEPORT_SOUND, self)
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
