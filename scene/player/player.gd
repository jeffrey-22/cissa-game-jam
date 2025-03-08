# Main Player class
# Has PlayerTiles as children
extends Node2D
class_name Player

# Some suitable amount of (half) distance between the two joints
const JOINT_DISPARITY = 15

# Attach directions, to make it convenient for square tiles
enum AttachDirection { UP, DOWN, LEFT, RIGHT }

func get_corresponding_direction_vector(attach_direction: AttachDirection) -> Vector2i:
	match attach_direction:
		AttachDirection.UP:
			return Vector2i.UP
		AttachDirection.DOWN:
			return Vector2i.DOWN
		AttachDirection.LEFT:
			return Vector2i.LEFT
		AttachDirection.RIGHT:
			return Vector2i.RIGHT
		_:
			return Vector2i.ZERO

func get_opposite_attach_direction(attach_direction: AttachDirection) -> AttachDirection:
	match attach_direction:
		AttachDirection.UP:
			return AttachDirection.DOWN
		AttachDirection.DOWN:
			return AttachDirection.UP
		AttachDirection.LEFT:
			return AttachDirection.RIGHT
		AttachDirection.RIGHT:
			return AttachDirection.LEFT
		_:
			return AttachDirection.LEFT	

@onready var joints_node = $Joints

# Connection between PlayerTiles, stored as: [node_a, node_b, joint_c, joint_d]
# Where node_a and node_b are connected via joint_c/d
# joint_c/d is child of node_a
var tile_connections: Array[Array] = []

# Add connection between two PlayerTile nodes,
# saving a copy in the table as well as adding joints
# Only works for square tiles
# node_a will develop joints that bring node_b to it (relative to node_a)
# as well as making them side-by-side
# Needs to be called during a physics process lapse!
# TODO: Make it less hacky, for polishing purposes
func add_tile_connection(node_a: PlayerTile, node_b: PlayerTile, attach_direction: AttachDirection) -> void:
	# Update node_b's local position, global position and rotation to follow node_a
	var attach_direction_vector = get_corresponding_direction_vector(attach_direction)
	node_b.local_body_position = node_a.local_body_position + attach_direction_vector
	node_b.rotation = node_a.rotation
	# Calculate distance between the centers of these two nodes
	var distance_between_centers = node_a.get_distance_from_sprite_center_to_certain_edge(attach_direction) +\
		node_b.get_distance_from_sprite_center_to_certain_edge(get_opposite_attach_direction(attach_direction))
	var position_difference_vector = Vector2(attach_direction_vector)
	position_difference_vector *= distance_between_centers
	position_difference_vector = position_difference_vector.rotated(node_a.rotation)
	node_b.global_transform.origin = node_a.position + position_difference_vector
	node_b.linear_velocity = node_a.linear_velocity
	node_b.angular_velocity = node_a.angular_velocity
	# Add joints
	var distance_to_edge = node_a.get_distance_from_sprite_center_to_certain_edge(attach_direction)
	var joint_relative_distance_vector = Vector2(attach_direction_vector)
	var joint_position_relative_to_node_a = joint_relative_distance_vector * distance_to_edge
	var joint_position_c = joint_position_relative_to_node_a
	var joint_position_d = joint_position_relative_to_node_a
	# Distort the x/y by a bit to allow two different joints
	if joint_position_relative_to_node_a.x == 0:
		joint_position_c.x = -JOINT_DISPARITY
		joint_position_d.x = JOINT_DISPARITY
	else:
		joint_position_c.y = -JOINT_DISPARITY
		joint_position_d.y = JOINT_DISPARITY
	var pin_joint_node_c = PinJoint2D.new()
	pin_joint_node_c.position = joint_position_c
	pin_joint_node_c.node_a = node_a.get_path()
	pin_joint_node_c.node_b = node_b.get_path()
	node_a.add_child(pin_joint_node_c)
	var pin_joint_node_d = PinJoint2D.new()
	pin_joint_node_d.position = joint_position_d
	pin_joint_node_d.node_a = node_a.get_path()
	pin_joint_node_d.node_b = node_b.get_path()
	node_a.add_child(pin_joint_node_d)
	# Record this connection
	tile_connections.append([node_a, node_b, pin_joint_node_c, pin_joint_node_d])

func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("debug_1"):
		add_tile_connection($StartingPlayerTile, $PlayerTile2, AttachDirection.UP)

# Central tile
@onready var central_player_tile_node: PlayerTile = $StartingPlayerTile:
	set(new_central_player_tile_node):
		central_player_tile_node.cancel_central()
		new_central_player_tile_node.promote_central()
		var local_body_position_difference = new_central_player_tile_node.local_body_position -\
			central_player_tile_node.local_body_position
		var all_children_node = get_children(false)
		for child_node in all_children_node:
			if child_node is PlayerTile:
				child_node.local_body_position += local_body_position_difference
		central_player_tile_node = new_central_player_tile_node
