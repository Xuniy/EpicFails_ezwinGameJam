extends Node

const START_SOUND := preload("res://sounds/join_full.wav")

## Gros plan d'introduction : le monde reste figé, seule la fumée est animée.
@export var intro_zoom_multiplier: float = 4.0
@export var dezoom_duration: float = 1.2

var _starting: bool = false
var _finished: bool = false
var _normal_zoom: Vector2
var _smoke_process_mode: Node.ProcessMode
var player
var camera: Camera2D
var hud: CanvasLayer
var smoke: AnimatedSprite2D
@onready var start_screen: CanvasLayer = $StartScreen
@onready var chicken_sound: AudioStreamPlayer = $StartScreen/BruitPoulet


func _ready() -> void:
	chicken_sound.stream.loop = true
	chicken_sound.play()
	var start_button: Button = start_screen.get_node("Root/Dessins/Commencer")
	start_button.pressed.connect(_start_game)
	start_button.grab_focus()
	var world := get_parent()
	player = world.get_node("Player")
	camera = player.get_node("Camera2D")
	hud = world.get_node("UI_en_sah")
	smoke = player.get_node("AnimatedSprite2DFumee")
	_normal_zoom = player.normal_zoom
	_smoke_process_mode = smoke.process_mode

	GameState.game_over = false
	hud.hide()
	player.facing_direction = Vector2(1, 1).normalized()
	player.update_animation(Vector2.ZERO)
	player.animated_sprite.set_frame_and_progress(0, 0.0)
	smoke.process_mode = Node.PROCESS_MODE_ALWAYS
	smoke.play("fume")
	camera.zoom = _normal_zoom * maxf(intro_zoom_multiplier, 1.0)
	get_tree().paused = true
	camera.reset_smoothing()
	camera.force_update_scroll()


func _process(_delta: float) -> void:
	# La caméra doit suivre son tween même pendant la pause du monde.
	camera.force_update_scroll()


func _input(event: InputEvent) -> void:
	if _starting:
		return
	var start := false
	if event is InputEventJoypadButton:
		start = event.pressed and event.button_index in [JOY_BUTTON_A, JOY_BUTTON_START]
		if start:
			GameState.input_device = GameState.DEVICE_XBOX
	elif event is InputEventKey:
		start = event.pressed and not event.echo
		if start:
			GameState.input_device = GameState.DEVICE_KEYBOARD_MOUSE
	elif event is InputEventMouseButton:
		if event.pressed:
			GameState.input_device = GameState.DEVICE_KEYBOARD_MOUSE
	if start:
		get_viewport().set_input_as_handled()
		_start_game()


func _start_game() -> void:
	if _starting:
		return
	_starting = true
	chicken_sound.stop()
	var start_sound := AudioStreamPlayer.new()
	start_sound.name = "SonCommencer"
	start_sound.process_mode = Node.PROCESS_MODE_ALWAYS
	start_sound.stream = START_SOUND
	get_parent().add_child(start_sound)
	start_sound.finished.connect(start_sound.queue_free)
	start_sound.play()
	start_screen.hide()
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(camera, "zoom", _normal_zoom, maxf(dezoom_duration, 0.01))
	tween.tween_callback(_finish_intro)


func _finish_intro() -> void:
	camera.zoom = _normal_zoom
	camera.force_update_scroll()
	smoke.process_mode = _smoke_process_mode
	player._left_consumed = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	hud.show()
	_finished = true
	get_tree().paused = false
	get_parent().add_child.call_deferred(TutorialOverlay.new())
	queue_free()


func _exit_tree() -> void:
	if not _finished:
		# Ne pas laisser une autre scène en pause si l'introduction est quittée.
		get_tree().paused = false
