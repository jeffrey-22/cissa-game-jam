# Main Player class
# Has PlayerTiles as children
extends Node2D
class_name Player

# Some suitable amount of (half) distance between the two joints
const JOINT_DISPARITY = 15

# 1 space in local body position is equal to 32 px of real scale
const LOCAL_COORDINATE_SCALE = 32

# In pixels, the minimum distance from a hinting position to the actual position
# for it to be considered "locked in"
const MINIMUM_AUTOLOCK_DISTANCE = 30

# Attach directions, to make it convenient for square tiles
enum AttachDirection { UP, DOWN, LEFT, RIGHT }

func _ready():
	Globals.player_node = self
	initiate_hint_squares_update(true, true)

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
	# update node_b's local position, global position and rotation to follow node_a
	var attach_direction_vector = get_corresponding_direction_vector(attach_direction)
	node_b.local_body_position = node_a.local_body_position + attach_direction_vector
	node_b.set_rotation(node_a.rotation)
	# calculate distance between the centers of these two nodes
	var distance_between_centers = node_a.get_distance_from_sprite_center_to_certain_edge(attach_direction) +\
		node_b.get_distance_from_sprite_center_to_certain_edge(get_opposite_attach_direction(attach_direction))
	var position_difference_vector = Vector2(attach_direction_vector)
	position_difference_vector *= distance_between_centers
	position_difference_vector = position_difference_vector.rotated(node_a.rotation)
	node_b.global_transform.origin = node_a.position + position_difference_vector
	node_b.linear_velocity = node_a.linear_velocity
	node_b.angular_velocity = node_a.angular_velocity
	# add joints
	var distance_to_edge = node_a.get_distance_from_sprite_center_to_certain_edge(attach_direction)
	var joint_relative_distance_vector = Vector2(attach_direction_vector)
	var joint_position_relative_to_node_a = joint_relative_distance_vector * distance_to_edge
	var joint_position_c = joint_position_relative_to_node_a
	var joint_position_d = joint_position_relative_to_node_a
	# distort the x/y by a bit to allow two different joints
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
	# record this connection
	tile_connections.append([node_a, node_b, pin_joint_node_c, pin_joint_node_d])
	update_hint_squares(true, not(Globals.is_mouse_dragging))
	await get_tree().physics_frame
	node_b.global_transform.origin = node_a.position + position_difference_vector

# Central tile
@onready var central_player_tile_node: PlayerTile = $StartingPlayerTile:
	set(new_central_player_tile_node):
		if new_central_player_tile_node == central_player_tile_node:
			return
		central_player_tile_node.cancel_central()
		new_central_player_tile_node.promote_central()
		var local_body_position_difference = new_central_player_tile_node.local_body_position -\
			central_player_tile_node.local_body_position
		var all_children_node = get_children(false)
		for child_node in all_children_node:
			if child_node is PlayerTile:
				if child_node.is_physics_active:
					child_node.local_body_position -= local_body_position_difference
		central_player_tile_node = new_central_player_tile_node
		update_hint_squares(true, not(Globals.is_mouse_dragging))

# Connected to child_entered_tree signal
# On child entering, connect the central tile signal if it is a PlayerTile
func _on_child_entered_tree(node: Node) -> void:
	if node is PlayerTile:
		node.promote_central_request.connect(_on_promote_central_request)
		node.current_player_tile_detached.connect(_on_current_player_tile_detached)
		node.flush_connections.connect(_on_flush_connections)

# A PlayerTile receives a right click to request to become central
func _on_promote_central_request(requester_player_tile_node: PlayerTile) -> void:
	central_player_tile_node = requester_player_tile_node
	
func flush_all_connections_and_node_activities(
	exclude_staying_node: PlayerTile = null,
	is_update_hint_squares_required: bool = true,
	need_to_set_hiding_state: bool = false,
	set_hiding_state_value: bool = true,
	should_snap_positions: bool = false
) -> void:
	var all_children_node = get_children(false)
	var is_node_staying = {}
	for child_node in all_children_node:
		if child_node is PlayerTile:
			if child_node.is_physics_active:
				is_node_staying[child_node] = false
	is_node_staying = dfs_label_as_staying(central_player_tile_node, is_node_staying)
	
	for child_node in all_children_node:
		if child_node is PlayerTile:
			if child_node.is_physics_active:
				if not(is_node_staying[child_node]) and not(child_node.is_pending_state_change)\
					and child_node != exclude_staying_node:
					child_node.detach_by_chain_effect()
	var deleting_tile_connections = tile_connections.filter(
		func(connection):
			# is connection worth deleting
			var node_a = connection[0]
			var node_b = connection[1]
			if not(is_node_staying.get(node_a, false)) or not(is_node_staying.get(node_b, false)):
				return true
			return false
	)
	for connection in deleting_tile_connections:
		var pin_joint_c = connection[2]
		var pin_joint_d = connection[3]
		pin_joint_c.queue_free()
		pin_joint_d.queue_free()
	tile_connections = tile_connections.filter(
		func(connection):
			# is connection worth staying
			var node_a = connection[0]
			var node_b = connection[1]
			if not(is_node_staying.get(node_a, false)) or not(is_node_staying.get(node_b, false)):
				return false
			return true
	)
	if is_update_hint_squares_required:
		update_hint_squares(need_to_set_hiding_state, set_hiding_state_value)
		# might be a bad idea: lock all positions
	if should_snap_positions:
		flush_all_positions()

func flush_all_positions():
	var all_children_node = get_children(false)
	for child_node in all_children_node:
		if child_node is PlayerTile:
			if child_node.is_physics_active:
				var position_difference_vector = Vector2(\
					child_node.local_body_position -
					central_player_tile_node.local_body_position
				)
				position_difference_vector = position_difference_vector.rotated(central_player_tile_node.rotation)
				position_difference_vector *= LOCAL_COORDINATE_SCALE
				child_node.global_transform.origin =\
					central_player_tile_node.position + position_difference_vector
				child_node.set_rotation(central_player_tile_node.rotation)
	
# A PlayerTile changes its physics and requests connections to be updated
func _on_flush_connections(
	changed_player_tile_node: PlayerTile,
	is_update_hint_squares_required: bool = true,
	need_to_set_hiding_state: bool = false,
	set_hiding_state_value: bool = true,
	should_snap_positions: bool = false
) -> void:
	flush_all_connections_and_node_activities(
		changed_player_tile_node,
		is_update_hint_squares_required,
		need_to_set_hiding_state,
		set_hiding_state_value,
		should_snap_positions
	)

# Return the average position of all child PlayerTiles
func get_average_position() -> Vector2:
	var position_sum = Vector2.ZERO
	var child_count = 0
	var all_children_node = get_children(false)
	for child_node in all_children_node:
		if child_node is PlayerTile:
			if child_node.is_physics_active:
				position_sum += child_node.position
				child_count += 1
	return position_sum / child_count

# Detect a node detached, detach others as a chain effect
func _on_current_player_tile_detached(detached_node: PlayerTile) -> void:
	flush_all_connections_and_node_activities(detached_node, false, true, true)
	
func dfs_label_as_staying(current_node: PlayerTile, is_node_staying: Dictionary) -> Dictionary:
	is_node_staying[current_node] = true
	for connection in tile_connections:
		var node_a = connection[0]
		var node_b = connection[1]
		if node_a == current_node and not(is_node_staying.get(node_b, true)):
			is_node_staying = dfs_label_as_staying(node_b, is_node_staying)
		if node_b == current_node and not(is_node_staying.get(node_a, true)):
			is_node_staying = dfs_label_as_staying(node_a, is_node_staying)
	return is_node_staying

@onready var hint_squares: Node2D = $HintSquares

# Have hint squares copy central position always
func _physics_process(_delta: float) -> void:
	hint_squares.set_position(central_player_tile_node.position)
	hint_squares.set_rotation(central_player_tile_node.rotation)

func update_hint_squares(need_to_set_hiding_state: bool = false, set_hiding_state_value: bool = true) -> void:
	# avoid refreshing causing flashing
	await get_tree().physics_frame
	create_hint_squares(need_to_set_hiding_state, set_hiding_state_value)

# Clear dated hint squares
func clear_hint_squares() -> void:
	var dated_hint_sqaures = hint_squares.get_children(false)
	for dated_hint_square in dated_hint_sqaures:
		dated_hint_square.queue_free()
	
# Create hint squares
func create_hint_squares(need_to_set_hiding_state: bool = false, set_hiding_state_value: bool = true) -> void:
	var occupied_coordinates = {}
	var all_children_node = get_children(false)
	for child_node in all_children_node:
		if child_node is PlayerTile:
			if child_node.is_physics_active:
				occupied_coordinates[child_node.local_body_position] = true
	# clear dated ones
	clear_hint_squares()
	# populate with new ones
	for child_node in all_children_node:
		if child_node is PlayerTile:
			if child_node.is_physics_active:
				for expand_direction in AttachDirection.values():
					var new_local_body_position = child_node.local_body_position +\
						get_corresponding_direction_vector(expand_direction)
					if occupied_coordinates.get(new_local_body_position, false):
						continue
					occupied_coordinates[new_local_body_position] = true
					attempt_to_create_hint_square_at(
						new_local_body_position * LOCAL_COORDINATE_SCALE,
						child_node.rotation,
						new_local_body_position,
						need_to_set_hiding_state,
						set_hiding_state_value
					)

var hint_square_scene = preload("res://scene/player/hint_square.tscn")

# Create a single hint square at position
func attempt_to_create_hint_square_at(
	created_position: Vector2, 
	_copy_rotation: float, 
	copy_local_position: Vector2i,
	need_to_set_hiding_state: bool = false,
	set_hiding_state_value: bool = true
):
	var hint_square_instance: HintSquare = hint_square_scene.instantiate()
	hint_squares.add_child(hint_square_instance)
	hint_square_instance.local_body_position = copy_local_position
	hint_square_instance.position = created_position
	if need_to_set_hiding_state:
		hint_square_instance.is_hiding = set_hiding_state_value
	# hint_square_instance.rotate(copy_rotation)

# Find nearest hint square. If no hint squares are available return null
func find_nearest_hint_square(global_search_position) -> HintSquare:
	var all_hint_square = hint_squares.get_children(false)
	var return_value = null
	var closest_distance = 0
	for hint_square in all_hint_square:
		if hint_square.is_obstructed or hint_square.is_hiding:
			continue
		var distance_to_search_position = hint_square.global_position.distance_to(global_search_position)
		if return_value == null:
			closest_distance = distance_to_search_position
			return_value = hint_square
		elif distance_to_search_position < closest_distance:
			closest_distance = distance_to_search_position
			return_value = hint_square
	# if found hint square is too far, discard it
	if closest_distance > MINIMUM_AUTOLOCK_DISTANCE:
		return_value = null
	return return_value

# Attach a new node
func attach_new_node_by_local_position(new_player_tile_node, local_body_position) -> void:
	new_player_tile_node.local_body_position = local_body_position
	# find all main body children nodes that share an edge with this new tile
	var all_children_node = get_children(false)
	var local_body_position_to_player_tile_lookup = {}
	for child_node in all_children_node:
		if child_node is PlayerTile:
			if child_node.is_physics_active:
				local_body_position_to_player_tile_lookup[child_node.local_body_position] = child_node
	for attaching_direction in AttachDirection.values():
		var sourcing_direction = get_opposite_attach_direction(attaching_direction)
		var sourcing_local_body_position = get_corresponding_direction_vector(sourcing_direction)
		sourcing_local_body_position += local_body_position
		var sourcing_player_tile_node = local_body_position_to_player_tile_lookup.get(sourcing_local_body_position, null)
		if sourcing_player_tile_node != null:
			add_tile_connection(sourcing_player_tile_node, new_player_tile_node, attaching_direction)

func show_hint_squares():
	var all_hint_square = hint_squares.get_children()
	for hint_square in all_hint_square:
		hint_square.is_hiding = false
	
func hide_hint_squares():
	var all_hint_square = hint_squares.get_children()
	for hint_square in all_hint_square:
		hint_square.is_hiding = true

# Called when all children node ready, on detecting is_dragging change
# Create hint squares
func initiate_hint_squares_update(need_to_set_hiding_state: bool = true, set_hiding_state_value: bool = true):
	update_hint_squares(need_to_set_hiding_state, set_hiding_state_value)

# Returns null if no player tile is connected.
# Otherwise, return the ref of the node with the highest y coordinate
func get_highest_connected_player_tile() -> PlayerTile:
	var all_children_node = get_children(false)
	var return_value = null
	var highest_y_coordinate = 0
	for child_node in all_children_node:
		if child_node is PlayerTile:
			if child_node.is_physics_active:
				if return_value == null:
					highest_y_coordinate = child_node.position.y
					return_value = child_node
				elif child_node.position.y < highest_y_coordinate:
					highest_y_coordinate = child_node.position.y
					return_value = child_node
	return return_value
	
func get_connected_player_tile_count() -> int:
	var all_children_node = get_children(false)
	var count = 0
	for child_node in all_children_node:
		if child_node is PlayerTile:
			if child_node.is_physics_active:
				count += 1
	return count
	
