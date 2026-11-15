extends Control

@export_range(0.0, 1.0, 0.05) var damage_overlay_opacity: float = 0.7
@export_range(0.0, 2.0, 0.05) var damage_overlay_fade_time: float = 0.5

# Bloc de la barre de joint : 130 px de haut, dont 106 px au-dessus du joint pour la fumée.
const JOINT_SIZE := Vector2(144, 130)
const JOINT_VISUAL_HEIGHT: float = 24.0   # 6 lignes de joint × échelle 4
const JOINT_TOP: float = 6.0              # position du joint lui-même, près du bord haut
const MARGIN: float = 16.0
const GAP: float = 12.0
const RHYTHM_WIDTH: float = 420.0
const RHYTHM_HEIGHT: float = 70.0
# Joint à 0 : le joueur perd ce montant de vie, à cet intervalle, tant que le joint est vide.
const EMPTY_JOINT_DAMAGE: float = 5.0
const EMPTY_JOINT_INTERVAL: float = 2.0

@onready var player = $"../../Player"
@onready var poulailler = $"../../poulailler"

@onready var health_box = $VBoxContainer
@onready var player_bar: HealthBar = $VBoxContainer/vieplayer
@onready var coop_bar: HealthBar = $VBoxContainer/viepoulailler
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

	_layout_top_left()
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

# Barre de joint tout en haut à gauche, barres de vie juste en dessous.
func _layout_top_left() -> void:
	joint_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	joint_bar.size = JOINT_SIZE
	# Le joint est dessiné en bas du bloc : on remonte le bloc pour que le joint soit en haut.
	joint_bar.position = Vector2(MARGIN, JOINT_TOP - (JOINT_SIZE.y - JOINT_VISUAL_HEIGHT))
	health_box.position = Vector2(MARGIN, JOINT_TOP + JOINT_VISUAL_HEIGHT + GAP)


# Mini-jeu de rythme à côté de la barre de joint.
func _add_rhythm_game() -> void:
	var rhythm := RhythmGame.new()
	rhythm.joint = joint_bar
	rhythm.position = Vector2(MARGIN + JOINT_SIZE.x + MARGIN, JOINT_TOP)
	rhythm.size = Vector2(RHYTHM_WIDTH, RHYTHM_HEIGHT)
	add_child(rhythm)
