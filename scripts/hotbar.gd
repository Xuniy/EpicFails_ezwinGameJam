extends Control

## Barre d'items façon Minecraft : l'item sélectionné est au centre, plus grand et opaque,
## ses voisins sont sur les côtés. Chaque case utilise Inventory_Slot_1 comme fond,
## avec le nombre d'exemplaires à l'intérieur. Le nom de l'item sélectionné s'affiche au-dessus.
@export var player: Node2D

const SLOT_TEXTURE: Texture2D = preload("res://assets/Inventory_Slot_1.png")
const SLOT_SIZE: float = 52.0
const SELECTED_SCALE: float = 2.2
const SLOT_GAP: float = 10.0
const BOTTOM_MARGIN: float = 12.0
# Zone intérieure de la case : le contour occupe les bords (32 px -> 8 px de marge).
const ICON_INSET: float = 0.25
const NAME_FONT_SIZE: int = 18
const EMPTY_TINT := Color(0.4, 0.4, 0.4, 1.0)
const COUNT_SHADOW := Color(0.0, 0.0, 0.0, 1.0)

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
	var font: Font = get_theme_default_font()

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
		# Pas de transparence : un item épuisé est seulement grisé.
		# Le centre reste toujours en couleur pleine ; les autres sont grisés si épuisés.
		var tint: Color = Color.WHITE if (is_selected or quantity > 0) else EMPTY_TINT

		draw_texture_rect(SLOT_TEXTURE, rect, false)

		var icon: Texture2D = ICONS.get(item_type)
		if icon:
			draw_texture_rect(icon, rect.grow(-slot * ICON_INSET), false, tint)

		# Compteur à l'intérieur de la case, en bas à droite (zone intérieure).
		var inner_right: float = rect.position.x + slot * (1.0 - ICON_INSET) - 2.0
		var inner_bottom: float = rect.position.y + slot * (1.0 - ICON_INSET) - 2.0
		var count_width: float = inner_right - rect.position.x
		var font_size: int = 18 if is_selected else 12
		var count_text: String = str(quantity)
		draw_string(
			font,
			Vector2(rect.position.x + 1.0, inner_bottom + 1.0),
			count_text,
			HORIZONTAL_ALIGNMENT_RIGHT,
			count_width,
			font_size,
			COUNT_SHADOW
		)
		draw_string(
			font,
			Vector2(rect.position.x, inner_bottom),
			count_text,
			HORIZONTAL_ALIGNMENT_RIGHT,
			count_width,
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
