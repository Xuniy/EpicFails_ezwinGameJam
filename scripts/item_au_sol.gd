extends Area2D
const ICONS = {
	"grenade": preload("res://assets/eggrenade.png"),
	"tp": preload("res://assets/eggderpearl.png"),
	"nuke": preload("res://assets/egg_bomba.png")
}



@export_enum("grenade", "tp", "nuke") var item_type: String = "grenade"
@export var icon: Texture2D
@export var bob_height: float = 3.0
@export var bob_speed: float = 3.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var resting_y: float = sprite.position.y

var bob_time: float = 0.0


func _ready() -> void:
	sprite.texture = ICONS.get(item_type)
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	bob_time += delta
	sprite.position.y = resting_y + sin(bob_time * bob_speed) * bob_height


func _on_body_entered(body: Node2D) -> void:
	if is_queued_for_deletion():
		return

	if body.has_method("collect_item"):
		if body.collect_item(item_type):
			queue_free()
