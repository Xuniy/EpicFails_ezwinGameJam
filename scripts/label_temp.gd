extends Label

@onready var player = $"../../../../Player"


func _process(_delta: float) -> void:
	if player == null:
		return

	var lines: Array[String] = []

	for item_type in player.items:
		var quantity: int = player.items[item_type]

		if quantity > 0:
			lines.append("%s ×%d" % [
				item_type.capitalize(),
				quantity
			])

	text = "\n".join(lines)
	text += "\n> Sélection : " + player.selected_item.capitalize()

	if lines.is_empty():
		text = "Aucun item"
