extends CanvasLayer

signal finished

var pages: PackedStringArray = []
var speaker_name: String = ""
var portrait: Texture2D
@export var voice_pages: Array[AudioStream] = []
@export_range(-40.0, 12.0, 1.0) var voice_volume_db: float = 3.0
var _page: int = 0
var _ready_for_press: bool = false
var _waiting_release: bool = false
var _closed: bool = false
var _held_inputs: Dictionary = {}

@onready var dialogue: Control = $Dialogue
@onready var voice: AudioStreamPlayer = $Voice


func _ready() -> void:
	voice.volume_db = voice_volume_db
	get_tree().paused = true
	dialogue.get_node("Speaker/Name").text = speaker_name
	var image: TextureRect = dialogue.get_node("Speaker/Portrait")
	image.texture = portrait
	image.visible = portrait != null
	dialogue.get_node("Box/ObjectiveIcon").hide()
	_show_page()


func _show_page() -> void:
	voice.stop()
	if pages.is_empty():
		_finish()
		return
	dialogue.get_node("Box/Text").text = pages[_page]
	dialogue.get_node("Box/Hint").text = "PC : Entrée / Espace / clic gauche · Manette : A (%d/%d)" % [_page + 1, pages.size()]
	if _page < voice_pages.size() and voice_pages[_page] != null:
		voice.stream = voice_pages[_page]
		voice.play()


func _controls_released() -> bool:
	if not _held_inputs.is_empty():
		return false
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		return false
	for key in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		if Input.is_key_pressed(key):
			return false
	for device in Input.get_connected_joypads():
		if Input.is_joy_button_pressed(device, JOY_BUTTON_A):
			return false
	return true


func _process(_delta: float) -> void:
	if _closed or not _controls_released():
		return
	if _waiting_release:
		_waiting_release = false
		_page += 1
		if _page >= pages.size():
			_finish()
		else:
			_show_page()
	_ready_for_press = true


func _input(event: InputEvent) -> void:
	if _closed:
		return
	var confirm := false
	var input_id := ""
	if event is InputEventKey:
		confirm = event.pressed and not event.echo and event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]
		if event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
			input_id = "key_%d" % event.keycode
	elif event is InputEventMouseButton:
		confirm = event.pressed and event.button_index == MOUSE_BUTTON_LEFT
		if event.button_index == MOUSE_BUTTON_LEFT:
			input_id = "mouse"
	elif event is InputEventJoypadButton:
		confirm = event.pressed and event.button_index == JOY_BUTTON_A
		if event.button_index == JOY_BUTTON_A:
			input_id = "pad_%d" % event.device
	if input_id != "":
		if event.is_pressed():
			_held_inputs[input_id] = true
		else:
			_held_inputs.erase(input_id)
	if confirm:
		get_viewport().set_input_as_handled()
		if _ready_for_press:
			_ready_for_press = false
			_waiting_release = true
			voice.stop()


func _finish() -> void:
	if _closed:
		return
	_closed = true
	voice.stop()
	get_tree().paused = false
	finished.emit()
	queue_free()
