# A base PlayerTile
# Handles most player interactions
# Individually assumed to be in the rightup position
# With the center at (0, 0)
# And are subject to connections etc. scripted in the player scene.
extends RigidBody2D
class_name PlayerTile

@onready var sprite_node = $Sprite2D

# Local position in the main body space.
# Central node has (0, 0)
var local_body_position: Vector2i = Vector2i.ZERO

# 32 x 32px sprite, so half_side_length is 16
@export var half_side_length = 16 
var distance_from_sprite_center_to_left_edge = half_side_length
var distance_from_sprite_center_to_up_edge = half_side_length
var distance_from_sprite_center_to_down_edge = half_side_length
var distance_from_sprite_center_to_right_edge = half_side_length

func get_distance_from_sprite_center_to_certain_edge(move_direction: Player.AttachDirection):
	match move_direction:
		Player.AttachDirection.UP:
			return distance_from_sprite_center_to_up_edge
		Player.AttachDirection.DOWN:
			return distance_from_sprite_center_to_down_edge
		Player.AttachDirection.LEFT:
			return distance_from_sprite_center_to_left_edge
		Player.AttachDirection.RIGHT:
			return distance_from_sprite_center_to_right_edge
	return 0

# Change appearance based on whether node is central
func cancel_central() -> void:
	pass

func promote_central() -> void:
	pass

# Detect if right clicked, then ask to be promoted to central
