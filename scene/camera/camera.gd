# Script for camera
# For now just have it be a child of the player
# in the level scene tree and follow the player around
extends Camera2D
class_name Camera

# Position smoothing speed, by default 5px/s
# Might want to speed up if the body grows larger
# As well as zoom out
@export var smoothing_speed = 5.0
@export var zoom_scale_reference = 8.0

# For now use the average position of all player tiles
func get_main_player_body_target_position() -> Vector2:
	var player_node = Globals.player_node
	return player_node.get_average_position()

func _ready() -> void:
	zoom = Vector2.ONE * 2.0

func _process(_delta: float) -> void:
	position_smoothing_speed = smoothing_speed
	#var player_node = Globals.player_node
	#var tile_count = player_node.get_usable_player_tile_count()
	#tile_count = max(tile_count, 4)
	#var zoom_scalar = zoom_scale_reference / (1.0 * tile_count)
	#zoom = zoom.lerp(Vector2.ONE * zoom_scalar, 2.0 * delta)
	position = get_main_player_body_target_position()
