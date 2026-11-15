extends Control

## Barre d'items façon Minecraft : l'item sélectionné est au centre, agrandi,
## ses voisins sont sur les côtés. Chaque case utilise Inventory_Slot_1 comme fond
## et affiche le nombre d'exemplaires. Le nom de l'item sélectionné s'affiche au-dessus.
@export var player: Node2D

const SLOT_TEXTURE: Texture2D = preload("res://assets/Inventory_Slot_1.png")
const SLOT_SIZE: float = 52.0
const SELECTED_SCALE: float = 1.6
const SLOT_GAP: float = 10.0
const BOTTOM_MARGIN: float = 12.0
const ICON_INSET: float = 0.16
const NAME_FONT_SIZE: int = 18
const UNSELECTED_ALPHA: float = 0.7
const EMPTY_ALPHA: float = 0.35

const ICONS := {
	"grenade": preload("res://assets/eggrenade.png"),
	"tp": preload("res://assets/eggderpearl.png"),
	"nuke": preload("res://assets/egg_bomba.png"),
}

const DISPLAY_NAMES := {
	"grenade": "eggrenade",
	"tp": "eggder pearl",
	"nuke": "egg bomba",
}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


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

		var slot_alpha: float = 1.0 if is_selected else UNSELECTED_ALPHA
		draw_texture_rect(SLOT_TEXTURE, rect, false, Color(1, 1, 1, slot_alpha))

		var icon: Texture2D = ICONS.get(item_type)
		if icon:
			var icon_alpha: float = 1.0 if quantity > 0 else EMPTY_ALPHA
			draw_texture_rect(
				icon,
				rect.grow(-slot * ICON_INSET),
				false,
				Color(1, 1, 1, icon_alpha * slot_alpha)
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

	# Nom de l'item sélectionné, centré au-dessus de la case du milieu.
	var selected_type: String = order[selected]
	var selected_name: String = DISPLAY_NAMES.get(selected_type, selected_type)
	draw_string(
		font,
		Vector2(center_x - 100.0, base_y - big_size - 8.0),
		selected_name,
		HORIZONTAL_ALIGNMENT_CENTER,
		200.0,
		NAME_FONT_SIZE,
		Color.WHITE
	)
