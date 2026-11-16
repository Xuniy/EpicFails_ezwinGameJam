@tool
class_name RhythmGame
extends Control

signal hit_succeeded
signal perfect_achieved

## Mini-jeu de rythme pour fumer : une seule ligne horizontale. Les boutons arrivent
## vers la cible ; une bonne touche au bon moment ajoute 5 s au joint (plafonné à sa durée).
## Une mauvaise touche joue le son d'échec sans remplir le joint. Démarré par la croix haut (manette) ou la touche A (clavier) quand le joint n'est pas plein.
## Voies au clavier : touches 1 2 3 4. Affichage manette ou clavier selon le dernier appareil branché.

class NoteData:
	var lane: int
	var time: float
	var state: int  # 0 = en attente, 1 = touchée, 2 = ratée


@export var joint: JointBar

@export_group("Aperçu dans l'éditeur")
@export var editor_preview: bool = true:
	set(value):
		editor_preview = value
		queue_redraw()
@export_enum("Clavier", "Manette") var preview_device: int = 0:
	set(value):
		preview_device = value
		queue_redraw()
@export var fit_frame_to_size: bool = true:
	set(value):
		fit_frame_to_size = value
		if is_node_ready():
			_layout_frame()

@export_group("Rythme")
@export_range(4, 64, 1) var note_count: int = NOTE_COUNT
@export_range(0.25, 2.0, 0.05) var note_interval: float = NOTE_STEP
@export_range(0.02, 0.3, 0.01) var hit_window: float = HIT_WINDOW
@export_range(80.0, 600.0, 10.0) var note_speed: float = NOTE_SPEED
@export_range(0.5, 5.0, 0.1) var start_delay: float = START_DELAY
@export_range(0.5, 10.0, 0.5) var seconds_per_hit: float = SECONDS_PER_HIT

const SUCCESS_SOUND = preload("res://sounds/inspire_bien.wav")
const FAILURE_SOUND = preload("res://sounds/inspire_joint_mal.wav")
const FULL_SOUND = preload("res://sounds/join_full.wav")

@onready var joint_sound: AudioStreamPlayer = $SonJoint
@onready var full_sound: AudioStreamPlayer = $SonJointPlein
@onready var frame_sprite: Sprite2D = $Encadrement
@onready var target_marker: Marker2D = $Cible

const BUTTON_TEXTURES := [
	preload("res://assets/buttons/button_y.png"),
	preload("res://assets/buttons/button_x.png"),
	preload("res://assets/buttons/button_a.png"),
	preload("res://assets/buttons/button_b.png"),
]
# Ordre des voies : Y, X, A, B (chaque note est un de ces boutons).
const LANE_BUTTONS := [JOY_BUTTON_Y, JOY_BUTTON_X, JOY_BUTTON_A, JOY_BUTTON_B]
const START_BUTTON: int = JOY_BUTTON_DPAD_UP
const START_KEY: Key = KEY_A
const KEY_LANES := [KEY_1, KEY_2, KEY_3, KEY_4]
const KEYPAD_LANES := [KEY_KP_1, KEY_KP_2, KEY_KP_3, KEY_KP_4]
const KEY_LABELS := ["1", "2", "3", "4"]
const NOTE_COUNT: int = 9
const NOTE_STEP: float = 0.6
const START_DELAY: float = 1.5
const HIT_WINDOW: float = 0.12
const NOTE_SPEED: float = 200.0   # px par seconde, de droite à gauche
const BUTTON_SIZE: float = 14.0
const NOTE_SCALE: float = 2.0
const SECONDS_PER_HIT: float = 5.0
const RESULT_DURATION: float = 2.0
const FONT_SIZE: int = 20

var active: bool = false
var song_time: float = 0.0
var notes: Array = []
var amount_at_start: float = 0.0
var result_timer: float = 0.0
var result_text: String = ""
var using_gamepad: bool = false
var successful_notes: int = 0
var wrong_inputs: int = 0


func _ready() -> void:
	resized.connect(_layout_frame)
	_layout_frame()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if Engine.is_editor_hint():
		set_process_unhandled_input(false)
		queue_redraw()
		return
	using_gamepad = not Input.get_connected_joypads().is_empty()
	visible = false


func _layout_frame() -> void:
	if fit_frame_to_size and is_instance_valid(frame_sprite) and frame_sprite.texture != null:
		frame_sprite.scale = size / frame_sprite.texture.get_size()
	queue_redraw()


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()
		return
	if active:
		song_time += delta
		for note in notes:
			if note.state == 0 and song_time > note.time + hit_window:
				note.state = 2
		if song_time > notes.back().time + hit_window + 0.3:
			_finish()
	elif result_timer > 0.0:
		result_timer -= delta
		if result_timer <= 0.0:
			visible = false
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	var is_start := false
	var lane := -1
	if event is InputEventJoypadButton:
		var pad := event as InputEventJoypadButton
		if not pad.pressed:
			return
		using_gamepad = true
		is_start = pad.button_index == START_BUTTON
		lane = LANE_BUTTONS.find(pad.button_index)
	elif event is InputEventKey:
		var key := event as InputEventKey
		if not key.pressed or key.echo:
			return
		using_gamepad = false
		is_start = key.keycode == START_KEY
		# La rangée 1–4 fonctionne aussi sur AZERTY, sans maintenir Maj.
		lane = KEY_LANES.find(key.physical_keycode)
		if lane == -1:
			lane = KEY_LANES.find(key.keycode)
		if lane == -1:
			lane = KEYPAD_LANES.find(key.keycode)
		if lane == -1:
			lane = KEYPAD_LANES.find(key.physical_keycode)
	else:
		return

	if active:
		# La même touche que pour l'ouvrir ferme le mini-jeu.
		if is_start:
			_close()
			get_viewport().set_input_as_handled()
		elif lane != -1:
			_try_hit(lane)
			get_viewport().set_input_as_handled()
	elif is_start and joint and joint.amount < 1.0:
		_start()
		get_viewport().set_input_as_handled()


func _start() -> void:
	successful_notes = 0
	wrong_inputs = 0
	notes.clear()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in note_count:
		var note := NoteData.new()
		note.lane = rng.randi_range(0, LANE_BUTTONS.size() - 1)
		note.time = start_delay + i * note_interval
		note.state = 0
		notes.append(note)
	amount_at_start = joint.amount
	song_time = 0.0
	result_timer = 0.0
	active = true
	visible = true


func _try_hit(lane: int) -> void:
	if not active:
		return
	# Bonne touche dans la fenêtre de temps : son réussi ; sinon, son raté.
	var best: NoteData = null
	var best_dt: float = hit_window
	for note in notes:
		if note.state != 0 or note.lane != lane:
			continue
		var dt: float = absf(note.time - song_time)
		if dt <= best_dt:
			best = note
			best_dt = dt
	if best == null:
		wrong_inputs += 1
		_play_joint_sound(FAILURE_SOUND)
		return

	best.state = 1
	successful_notes += 1
	_play_joint_sound(SUCCESS_SOUND)
	# 5 secondes sur la durée du joint (plafonné à 100 %).
	var previous_amount: float = joint.amount
	joint.amount = minf(1.0, joint.amount + seconds_per_hit / joint.duration)
	if previous_amount < 1.0 and joint.amount >= 1.0:
		full_sound.play()
	hit_succeeded.emit()
	# La série continue à joint plein : un perfect exige toutes les notes.
	if successful_notes == note_count:
		_finish()


func _play_joint_sound(stream: AudioStream) -> void:
	joint_sound.stop()
	joint_sound.stream = stream
	joint_sound.play()


func _close() -> void:
	active = false
	result_timer = 0.0
	visible = false


func _finish() -> void:
	if not active:
		return
	active = false
	var gained: float = (joint.amount - amount_at_start) * joint.duration
	result_text = "Fumé : +%d s" % roundi(gained)
	result_timer = RESULT_DURATION
	if successful_notes == note_count and wrong_inputs == 0:
		result_text = "PERFECT ! Vitesse + invincibilité : 10 s"
		perfect_achieved.emit()


# Touche clavier dessinée dans un petit carré, à la place de l'icône manette.
func _draw_key_label(rect: Rect2, label: String, font: Font) -> void:
	draw_rect(rect, Color(0, 0, 0, 0.85))
	draw_rect(rect, Color.WHITE, false, 2.0)
	draw_string(font, Vector2(rect.position.x, rect.position.y + rect.size.y * 0.5 + FONT_SIZE * 0.35), label, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, FONT_SIZE, Color.WHITE)


func _draw() -> void:
	if not is_instance_valid(target_marker):
		return
	var preview := Engine.is_editor_hint() and editor_preview
	var font: Font = get_theme_default_font()
	var panel := Rect2(Vector2.ZERO, size)

	if active or preview:
		draw_rect(panel.grow(-12.0), Color(0, 0, 0, 0.65))

		var line_y: float = target_marker.position.y
		var target_x: float = target_marker.position.x
		var icon: float = BUTTON_SIZE * NOTE_SCALE
		draw_line(Vector2(maxf(24.0, target_x - 40.0), line_y), Vector2(size.x - 24.0, line_y), Color.WHITE, 2.0)
		draw_arc(Vector2(target_x, line_y), icon * 0.6, 0.0, TAU, 32, Color(1, 1, 1, 0.6), 2.0)

		if preview:
			for lane in range(4):
				var x := lerpf(target_x + icon, size.x - 24.0 - icon * 0.5, (lane + 0.5) / 4.0)
				var rect := Rect2(Vector2(x - icon * 0.5, line_y - icon * 0.5), Vector2.ONE * icon)
				if preview_device == 1:
					draw_texture_rect(BUTTON_TEXTURES[lane], rect, false)
				else:
					_draw_key_label(rect, KEY_LABELS[lane], font)
			return

		for note in notes:
			if note.state != 0:
				continue
			var x: float = target_x + (note.time - song_time) * note_speed
			if x < 24.0 + icon * 0.5 or x > size.x - 24.0 - icon * 0.5:
				continue
			var rect := Rect2(x - icon * 0.5, line_y - icon * 0.5, icon, icon)
			if using_gamepad:
				draw_texture_rect(BUTTON_TEXTURES[note.lane], rect, false)
			else:
				_draw_key_label(rect, KEY_LABELS[note.lane], font)

	elif result_timer > 0.0:
		draw_rect(panel.grow(-12.0), Color(0, 0, 0, 0.65))
		draw_string(
			font,
			Vector2(24.0, size.y * 0.6),
			result_text,
			HORIZONTAL_ALIGNMENT_CENTER,
			size.x - 48.0,
			16 if result_text.begins_with("PERFECT") else FONT_SIZE,
			Color.WHITE
		)
