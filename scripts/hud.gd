extends Control

@export_range(0.0, 1.0, 0.05) var damage_overlay_opacity: float = 0.7
@export_range(0.0, 2.0, 0.05) var damage_overlay_fade_time: float = 0.5

# Bloc de la barre de joint : 130 px de haut, dont 106 px au-dessus du joint pour la fumée.
const JOINT_SIZE := Vector2(144, 130)
const MARGIN: float = 16.0
const GAP: float = 12.0
const RHYTHM_WIDTH: float = 420.0
const RHYTHM_HEIGHT: float = 70.0
# Joint à 0 : le joueur perd ce montant de vie, à cet intervalle, tant que le joint est vide.
const EMPTY_JOINT_DAMAGE: float = 5.0
const EMPTY_JOINT_INTERVAL: float = 2.0

@onready var player = $"../../Player"
@onready var poulailler = $"../../poulailler"

@onready var health_box: VBoxContainer = $PlayerHealth
@onready var coop_health_box: VBoxContainer = $CoopHealth
@onready var player_bar: HealthBar = $PlayerHealth/vieplayer
@onready var coop_bar: HealthBar = $CoopHealth/viepoulailler
@onready var joint_bar = $JointBar
@onready var compass = $Compass
@onready var hotbar = $Hotbar
@onready var blood_overlay: TextureRect = $Sang

var _previous_player_health: float
var _damage_tween: Tween

var _empty_joint_timer: float = 0.0


func _ready() -> void:
	player_bar.max_value = player.max_health
	coop_bar.max_value = poulailler.max_health

	compass.target = poulailler
	hotbar.player = player
	_previous_player_health = player.health
	blood_overlay.modulate.a = 0.0

	_layout_hud()
	_add_rhythm_game()

	update_health_bars()


func _process(delta: float) -> void:
	_update_empty_joint_damage(delta)
	if player.health < _previous_player_health:
		show_damage_overlay()
	_previous_player_health = player.health
	update_health_bars()


func show_damage_overlay() -> void:
	if _damage_tween != null:
		_damage_tween.kill()
	blood_overlay.modulate.a = damage_overlay_opacity
	_damage_tween = create_tween()
	_damage_tween.tween_property(
		blood_overlay, "modulate:a", 0.0, damage_overlay_fade_time
	)


func update_health_bars() -> void:
	player_bar.value = player.health
	coop_bar.value = poulailler.health


# Joint vide : dégâts au joueur toutes les 2 secondes ; le compteur repart à zéro dès que le joint n'est plus vide.
func _update_empty_joint_damage(delta: float) -> void:
	if joint_bar.amount > 0.0:
		_empty_joint_timer = 0.0
		return

	_empty_joint_timer += delta
	if _empty_joint_timer >= EMPTY_JOINT_INTERVAL:
		_empty_joint_timer -= EMPTY_JOINT_INTERVAL
		player.take_damage(EMPTY_JOINT_DAMAGE)

# Joint en bas à gauche, vie du joueur en bas à droite.
func _layout_hud() -> void:
	joint_bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	joint_bar.size = JOINT_SIZE
	joint_bar.offset_left = MARGIN
	joint_bar.offset_right = MARGIN + JOINT_SIZE.x
	joint_bar.offset_top = -MARGIN - JOINT_SIZE.y
	joint_bar.offset_bottom = -MARGIN
	health_box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	health_box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	health_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	health_box.reset_size()
	health_box.offset_left = -MARGIN - health_box.size.x
	health_box.offset_right = -MARGIN
	health_box.offset_top = -MARGIN - health_box.size.y
	health_box.offset_bottom = -MARGIN
	coop_health_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	coop_health_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	coop_health_box.reset_size()
	coop_health_box.offset_left = -coop_health_box.size.x * 0.5
	coop_health_box.offset_right = coop_health_box.size.x * 0.5
	coop_health_box.offset_top = MARGIN
	coop_health_box.offset_bottom = MARGIN + coop_health_box.size.y


# Mini-jeu de rythme à côté de la barre de joint.
func _add_rhythm_game() -> void:
	var rhythm := RhythmGame.new()
	rhythm.joint = joint_bar
	rhythm.size = Vector2(RHYTHM_WIDTH, RHYTHM_HEIGHT)
	add_child(rhythm)
	rhythm.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	rhythm.offset_left = MARGIN
	rhythm.offset_right = MARGIN + RHYTHM_WIDTH
	rhythm.offset_top = -MARGIN - JOINT_SIZE.y - GAP - RHYTHM_HEIGHT
	rhythm.offset_bottom = -MARGIN - JOINT_SIZE.y - GAP
