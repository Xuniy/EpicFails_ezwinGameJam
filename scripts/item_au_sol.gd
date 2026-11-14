extends Area2D
const ICONS = {
	"grenade": preload("res://assets/eggrenade.png"),
	"tp": preload("res://assets/eggderpearl.png"),
	"nuke": preload("res://assets/egg_bomba.png")
}



@export_enum("grenade", "tp", "nuke") var item_type: String = "grenade"
@export var icon: Texture2D


func _ready() -> void:
	$Sprite2D.texture = ICONS.get(item_type)
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if is_queued_for_deletion():
		return

	if body.has_method("collect_item"):
		if body.collect_item(item_type):
			queue_free()
