class_name RhythmGame
extends Control

## Mini-jeu de rythme pour fumer : appuyer sur Y, X, A, B au bon moment remonte le joint.
## Démarré par la croix directionnelle haut, quand le joint n'est pas plein.

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
# Ordre des voies, de gauche à droite : Y, X, A, B.
const LANE_BUTTONS := [JOY_BUTTON_Y, JOY_BUTTON_X, JOY_BUTTON_A, JOY_BUTTON_B]
const START_BUTTON: int = JOY_BUTTON_DPAD_UP
const NOTE_COUNT: int = 32
const NOTE_STEP: float = 0.45
const START_DELAY: float = 1.5
const HIT_WINDOW: float = 0.12
const FALL_SPEED: float = 320.0
const MAX_GAIN: float = 0.5
const PANEL_SIZE := Vector2(560, 440)
const RESULT_SIZE := Vector2(360, 90)
const BUTTON_SIZE: float = 14.0
const NOTE_SCALE: float = 3.0
const LANE_SPACING: float = 130.0
const HIT_LINE_OFFSET: float = 70.0
const RESULT_DURATION: float = 2.0
const FONT_SIZE: int = 24

var active: bool = false
var song_time: float = 0.0
var notes: Array = []
var result_timer: float = 0.0
var result_text: String = ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
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
	if not (event is InputEventJoypadButton) or not event.pressed:
		return

	if active:
		var lane: int = LANE_BUTTONS.find(event.button_index)
		if lane != -1:
			_try_hit(lane)
			get_viewport().set_input_as_handled()
	elif event.button_index == START_BUTTON and joint and joint.amount < 1.0:
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
	song_time = 0.0
	result_timer = 0.0
	active = true
	visible = true


func _try_hit(lane: int) -> void:
	var best: NoteData = null
	var best_dt: float = HIT_WINDOW
	for note in notes:
		if note.state != 0 or note.lane != lane:
			continue
		var dt: float = absf(note.time - song_time)
		if dt <= best_dt:
			best = note
			best_dt = dt
	if best:
		best.state = 1


func _finish() -> void:
	active = false
	var hits: int = 0
	for note in notes:
		if note.state == 1:
			hits += 1
	var ratio: float = float(hits) / notes.size()
	if joint:
		joint.amount = minf(1.0, joint.amount + ratio * MAX_GAIN)
	result_text = "Fumé : %d / %d" % [hits, notes.size()]
	result_timer = RESULT_DURATION


func _lane_x(panel: Rect2, lane: int) -> float:
	return panel.position.x + PANEL_SIZE.x * 0.5 + (lane - 1.5) * LANE_SPACING


func _draw() -> void:
	var font: Font = get_theme_default_font()
	var panel := Rect2((size - PANEL_SIZE) * 0.5, PANEL_SIZE)

	if active:
		draw_rect(panel, Color(0, 0, 0, 0.75))
		draw_rect(panel, Color.WHITE, false, 2.0)
		draw_string(
			font,
			Vector2(panel.position.x, panel.position.y + 40.0),
			"FUME ! Suis le rythme",
			HORIZONTAL_ALIGNMENT_CENTER,
			PANEL_SIZE.x,
			FONT_SIZE,
			Color.WHITE
		)

		var hit_y: float = panel.end.y - HIT_LINE_OFFSET
		var icon_size: float = BUTTON_SIZE * NOTE_SCALE

		# Cibles : une par voie, à la ligne de frappe.
		for lane in LANE_BUTTONS.size():
			var cx: float = _lane_x(panel, lane)
			draw_texture_rect(
				BUTTON_TEXTURES[lane],
				Rect2(cx - icon_size * 0.5, hit_y - icon_size * 0.5, icon_size, icon_size),
				false,
				Color(1, 1, 1, 0.35)
			)

		# Notes qui tombent vers la ligne de frappe.
		for note in notes:
			if note.state != 0:
				continue
			var y: float = hit_y - (note.time - song_time) * FALL_SPEED
			if y < panel.position.y or y > hit_y + icon_size:
				continue
			var cx: float = _lane_x(panel, note.lane)
			draw_texture_rect(
				BUTTON_TEXTURES[note.lane],
				Rect2(cx - icon_size * 0.5, y - icon_size * 0.5, icon_size, icon_size),
				false
			)

	elif result_timer > 0.0:
		var result_rect := Rect2((size - RESULT_SIZE) * 0.5, RESULT_SIZE)
		draw_rect(result_rect, Color(0, 0, 0, 0.75))
		draw_rect(result_rect, Color.WHITE, false, 2.0)
		draw_string(
			font,
			Vector2(result_rect.position.x, result_rect.position.y + RESULT_SIZE.y * 0.6),
			result_text,
			HORIZONTAL_ALIGNMENT_CENTER,
			RESULT_SIZE.x,
			FONT_SIZE,
			Color.WHITE
		)
