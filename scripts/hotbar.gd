extends Control

## Barre d'items façon Minecraft : l'item sélectionné est au centre, agrandi,
## ses voisins sont sur les côtés. Chaque case affiche le nombre d'exemplaires.
@export var player: Node2D

const SLOT_SIZE: float = 52.0
const SELECTED_SCALE: float = 1.6
const SLOT_GAP: float = 10.0
const BOTTOM_MARGIN: float = 12.0
const BORDER_WIDTH: float = 2.0
const SLOT_COLOR := Color(0.0, 0.0, 0.0, 0.55)
const BORDER_COLOR := Color(0.8, 0.8, 0.8, 0.9)
const SELECTED_BORDER_COLOR := Color(1.0, 0.85, 0.2)
const EMPTY_ALPHA: float = 0.35

const ICONS := {
	"grenade": preload("res://assets/eggrenade.png"),
	"tp": preload("res://assets/eggderpearl.png"),
	"nuke": preload("res://assets/egg_bomba.png"),
}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if not is_instance_valid(player):
		return

	var order: Array = player.item_order
	var count: int = order.size()
	if count == 0:
		return

	var selected: int = player.selected_index
	var base_y: float = size.y - BOTTOM_MARGIN
	var center_x: float = size.x * 0.5
	var big_size: float = SLOT_SIZE * SELECTED_SCALE
	var font: Font = ThemeDB.fallback_font

	# Ordre d'affichage : voisin de gauche, sélection (centre), voisin de droite.
	for offset in [-1, 0, 1]:
		if offset != 0 and count < 3:
			continue

		var item_type: String = order[posmod(selected + offset, count)]
		var is_selected: bool = offset == 0
		var slot: float = big_size if is_selected else SLOT_SIZE

		# Distance entre centres : demi-case centrale + demi-case latérale + espace.
		var slot_center_x: float = center_x + offset * (big_size * 0.5 + SLOT_SIZE * 0.5 + SLOT_GAP)
		var rect := Rect2(
			Vector2(slot_center_x - slot * 0.5, base_y - slot),
			Vector2(slot, slot)
		)

		var quantity: int = player.items.get(item_type, 0)

		draw_rect(rect, SLOT_COLOR)

		var icon: Texture2D = ICONS.get(item_type)
		if icon:
			var alpha: float = 1.0 if quantity > 0 else EMPTY_ALPHA
			draw_texture_rect(icon, rect.grow(-slot * 0.12), false, Color(1, 1, 1, alpha))

		draw_rect(
			rect,
			SELECTED_BORDER_COLOR if is_selected else BORDER_COLOR,
			false,
			BORDER_WIDTH
		)

		var font_size: int = 20 if is_selected else 14
		draw_string(
			font,
			Vector2(rect.position.x, rect.end.y - 4.0),
			str(quantity),
			HORIZONTAL_ALIGNMENT_RIGHT,
			rect.size.x - 6.0,
			font_size,
			Color.WHITE
		)
