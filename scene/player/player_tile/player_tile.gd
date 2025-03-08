# A base PlayerTile
# Handles most player interactions
# Individually assumed to be in the rightup position
# With the center at (0, 0)
# And are subject to connections etc. scripted in the player scene.
extends RigidBody2D
class_name PlayerTile

@onready var animated_sprite_node = $AnimatedSprite2D
@onready var collision_shape_node = $CollisionShape2D

# Local position in the main body space.
# Central node has (0, 0)
var local_body_position: Vector2i = Vector2i.ZERO

# 32 x 32px sprite, so half_side_length is 16
@export var half_side_length = 16 
var distance_from_sprite_center_to_left_edge = half_side_length
var distance_from_sprite_center_to_up_edge = half_side_length
var distance_from_sprite_center_to_down_edge = half_side_length
var distance_from_sprite_center_to_right_edge = half_side_length

# If is starting tile, promote to central tile on startup
@export var is_starting_tile: bool = false

# Central state: Whether this node is central tile
var is_central_tile: bool = false

# If mouse is in the detect area, controlled by signals.
# Used to update drag state.
var is_mouse_hovering

# Node position - Mouse global position
# For dragging state
var drag_offset

# Use a FSM to manage dragging states
enum DragState { 
	NORMAL, 
	NORMAL_HOVER, 
	DRAGGING, 
	AFLOAT, 
	AFLOAT_HOVER, 
	UNCOLLECTED, 
	UNCOLLECTED_HOVER 
}
# Current state. Modify through change_drag_state to manage state effects
var current_drag_state = DragState.UNCOLLECTED

func is_physics_active() -> bool:
	return current_drag_state == DragState.NORMAL or current_drag_state == DragState.NORMAL_HOVER

# To fix the joints still working when physics are disabled
signal flush_connections(changed_player_tile_node: PlayerTile)

func disable_physics() -> void:
	freeze = true
	collision_shape_node.disabled = true
	flush_connections.emit(self)
	
func enable_physics() -> void:
	freeze = false
	collision_shape_node.disabled = false
	flush_connections.emit(self)

func enter_new_drag_state(state: DragState) -> void:
	match state:
		DragState.NORMAL:
			pass
		DragState.NORMAL_HOVER:
			animated_sprite_node.scale *= 1.1
		DragState.DRAGGING:
			disable_physics()
			Globals.is_mouse_dragging = true
		DragState.AFLOAT:
			disable_physics()
		DragState.AFLOAT_HOVER:
			disable_physics()
			animated_sprite_node.scale *= 1.1
		DragState.UNCOLLECTED:
			disable_physics()
		DragState.UNCOLLECTED_HOVER:
			disable_physics()
			animated_sprite_node.scale *= 1.1

func exit_old_drag_state(state: DragState) -> void:
	match state:
		DragState.NORMAL:
			pass
		DragState.NORMAL_HOVER:
			animated_sprite_node.scale /= 1.1
		DragState.DRAGGING:
			enable_physics()
			Globals.is_mouse_dragging = false
		DragState.AFLOAT:
			enable_physics()
		DragState.AFLOAT_HOVER:
			enable_physics()
			animated_sprite_node.scale /= 1.1
		DragState.UNCOLLECTED:
			enable_physics()
		DragState.UNCOLLECTED_HOVER:
			enable_physics()
			animated_sprite_node.scale /= 1.1

# Main way to change drag state
func change_drag_state(new_state: DragState) -> void:
	if current_drag_state == new_state:
		return
	exit_old_drag_state(current_drag_state)
	enter_new_drag_state(new_state)
	current_drag_state = new_state

func _ready() -> void:
	if is_starting_tile:
		current_drag_state = DragState.NORMAL
		promote_central()
		freeze = false

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

func detach_by_chain_effect() -> void:
	change_drag_state(DragState.AFLOAT)

# Change appearance based on whether node is central
func cancel_central() -> void:
	is_central_tile = false
	animated_sprite_node.play("default_idle")

func promote_central() -> void:
	is_central_tile = true
	animated_sprite_node.play("central_idle")

signal promote_central_request(central_node: PlayerTile)

signal current_player_tile_detached(current_node: PlayerTile)

# Connected to MouseDetectArea2D
# Invoked when mouse input event occurs within the current shape
func _on_mouse_detect_area_2d_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			if not(is_central_tile) and is_physics_active():
				promote_central_request.emit(self)
				get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			match current_drag_state:
				DragState.NORMAL_HOVER:
					drag_offset = global_position - get_global_mouse_position()
					current_player_tile_detached.emit(self)
					change_drag_state(DragState.DRAGGING)
				DragState.AFLOAT_HOVER:
					drag_offset = global_position - get_global_mouse_position()
					change_drag_state(DragState.DRAGGING)
				DragState.UNCOLLECTED_HOVER:
					drag_offset = global_position - get_global_mouse_position()
					change_drag_state(DragState.DRAGGING)

# Decide if need to cancel dragging / update drag position
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and not(event.pressed):
			match current_drag_state:
				DragState.DRAGGING:
					var player_node = Globals.player_node
					var target_hint_square = player_node.find_nearest_hint_square(global_position)
					# Failed to lock onto a square
					if target_hint_square == null:
						change_drag_state(DragState.AFLOAT)
					else:
						player_node.attach_new_node_by_local_position(self, target_hint_square.local_body_position)
						change_drag_state(DragState.NORMAL)
	if event is InputEventMouseMotion and current_drag_state == DragState.DRAGGING:
		global_position = get_global_mouse_position() + drag_offset

# Decide if there are needs for state updates
func _physics_process(_delta: float) -> void:
	match current_drag_state:
		DragState.NORMAL:
			if is_mouse_hovering and not(is_central_tile):
				change_drag_state(DragState.NORMAL_HOVER)
		DragState.NORMAL_HOVER:
			if not(is_mouse_hovering) or is_central_tile:
				change_drag_state(DragState.NORMAL)
		DragState.DRAGGING:
			pass
		DragState.AFLOAT:
			if is_mouse_hovering:
				change_drag_state(DragState.AFLOAT_HOVER)
		DragState.AFLOAT_HOVER:
			if not(is_mouse_hovering):
				change_drag_state(DragState.AFLOAT)
		DragState.UNCOLLECTED:
			if is_mouse_hovering:
				change_drag_state(DragState.UNCOLLECTED_HOVER)
		DragState.UNCOLLECTED_HOVER:
			if not(is_mouse_hovering):
				change_drag_state(DragState.UNCOLLECTED)

# Connected to MouseDetectArea2D
func _on_mouse_detect_area_2d_mouse_entered() -> void:
	is_mouse_hovering = true

# Connected to MouseDetectArea2D
func _on_mouse_detect_area_2d_mouse_exited() -> void:
	is_mouse_hovering = false

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("debug_2"):
		print(str(self) + " @ local " + str(local_body_position) + " @ state " + str(current_drag_state))
