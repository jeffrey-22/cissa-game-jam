# Script for camera
# For now just have it be a child of the player
# in the level scene tree and follow the player around
extends Camera2D
class_name Camera

# Position smoothing speed, by default 5px/s
# Might want to speed up if the body grows larger
# As well as zoom out
@export var smoothing_speed = 5.0
# Zoom scale, might want to increase as body size increase
@export var zoom_scale = 2.0

# For now use the average position of all player tiles
func get_main_player_body_target_position() -> Vector2:
	var player_node = Globals.player_node
	return player_node.get_average_position()

func _process(_delta: float) -> void:
	position_smoothing_speed = smoothing_speed
	zoom = Vector2(zoom_scale, zoom_scale)
	position = get_main_player_body_target_position()
