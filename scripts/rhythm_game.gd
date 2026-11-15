class_name RhythmGame
extends Control

## Mini-jeu de rythme pour fumer : une seule ligne horizontale. Les boutons arrivent
## vers la cible ; une bonne touche au bon moment ajoute 5 s au joint (plafonné à sa durée).
## Une mauvaise touche ne fait rien. Démarré par la croix haut (manette) ou la touche A (clavier) quand le joint n'est pas plein.
## Voies au clavier : touches 1 2 3 4. Affichage manette ou clavier selon le dernier appareil branché.

class NoteData:
	var lane: int
	var time: float
	var state: int  # 0 = en attente, 1 = touchée, 2 = ratée


@export var joint: JointBar

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
const KEY_LABELS := ["1", "2", "3", "4"]
const NOTE_COUNT: int = 16
const NOTE_STEP: float = 0.6
const START_DELAY: float = 1.5
const HIT_WINDOW: float = 0.12
const NOTE_SPEED: float = 220.0   # px par seconde, de droite à gauche
const TARGET_X: float = 90.0      # position horizontale de la cible
const LINE_Y_RATIO: float = 0.6
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


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	using_gamepad = not Input.get_connected_joypads().is_empty()
	visible = false


func _process(delta: float) -> void:
	if active:
		song_time += delta
		for note in notes:
			if note.state == 0 and song_time > note.time + HIT_WINDOW:
				note.state = 2
		if song_time > notes.back().time + HIT_WINDOW + 0.3:
			_finish()
	elif result_timer > 0.0:
		result_timer -= delta
		if result_timer <= 0.0:
			visible = false
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
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
		lane = KEY_LANES.find(key.keycode)
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
	notes.clear()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in NOTE_COUNT:
		var note := NoteData.new()
		note.lane = rng.randi_range(0, LANE_BUTTONS.size() - 1)
		note.time = START_DELAY + i * NOTE_STEP
		note.state = 0
		notes.append(note)
	amount_at_start = joint.amount
	song_time = 0.0
	result_timer = 0.0
	active = true
	visible = true


func _try_hit(lane: int) -> void:
	# Mauvais bouton ou pas au bon moment : rien ne se passe.
	var best: NoteData = null
	var best_dt: float = HIT_WINDOW
	for note in notes:
		if note.state != 0 or note.lane != lane:
			continue
		var dt: float = absf(note.time - song_time)
		if dt <= best_dt:
			best = note
			best_dt = dt
	if best == null:
		return

	best.state = 1
	# 5 secondes sur la durée du joint (plafonné à 100 %).
	joint.amount = minf(1.0, joint.amount + SECONDS_PER_HIT / joint.duration)
	# Joint plein : le mini-jeu se ferme tout seul.
	if joint.amount >= 1.0:
		_close()


func _close() -> void:
	active = false
	result_timer = 0.0
	visible = false


func _finish() -> void:
	active = false
	var gained: float = (joint.amount - amount_at_start) * joint.duration
	result_text = "Fumé : +%d s" % roundi(gained)
	result_timer = RESULT_DURATION


# Touche clavier dessinée dans un petit carré, à la place de l'icône manette.
func _draw_key_label(rect: Rect2, label: String, font: Font) -> void:
	draw_rect(rect, Color(0, 0, 0, 0.85))
	draw_rect(rect, Color.WHITE, false, 2.0)
	draw_string(font, Vector2(rect.position.x, rect.position.y + rect.size.y * 0.5 + FONT_SIZE * 0.35), label, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, FONT_SIZE, Color.WHITE)


func _draw() -> void:
	var font: Font = get_theme_default_font()
	var panel := Rect2(Vector2.ZERO, size)

	if active:
		draw_rect(panel, Color(0, 0, 0, 0.75))
		draw_rect(panel, Color.WHITE, false, 2.0)
		draw_string(
			font,
			Vector2(TARGET_X - 40.0, 30.0),
			"FUME ! Appuie au bon moment",
			HORIZONTAL_ALIGNMENT_LEFT,
			size.x - 60.0,
			FONT_SIZE,
			Color.WHITE
		)

		var line_y: float = size.y * LINE_Y_RATIO
		var icon: float = BUTTON_SIZE * NOTE_SCALE
		draw_line(Vector2(TARGET_X - 40.0, line_y), Vector2(size.x - 12.0, line_y), Color.WHITE, 2.0)
		draw_arc(Vector2(TARGET_X, line_y), icon * 0.6, 0.0, TAU, 32, Color(1, 1, 1, 0.6), 2.0)

		for note in notes:
			if note.state != 0:
				continue
			var x: float = TARGET_X + (note.time - song_time) * NOTE_SPEED
			if x < -icon or x > size.x + icon:
				continue
			var rect := Rect2(x - icon * 0.5, line_y - icon * 0.5, icon, icon)
			if using_gamepad:
				draw_texture_rect(BUTTON_TEXTURES[note.lane], rect, false)
			else:
				_draw_key_label(rect, KEY_LABELS[note.lane], font)

	elif result_timer > 0.0:
		draw_rect(panel, Color(0, 0, 0, 0.75))
		draw_rect(panel, Color.WHITE, false, 2.0)
		draw_string(
			font,
			Vector2(0.0, size.y * 0.6),
			result_text,
			HORIZONTAL_ALIGNMENT_CENTER,
			size.x,
			FONT_SIZE,
			Color.WHITE
		)
