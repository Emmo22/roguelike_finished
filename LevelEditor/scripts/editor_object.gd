extends Node2D

# Left-stick virtual mouse speed in pixels per second.
const CURSOR_SPEED := 900.0
# Deadzone below which the left stick is ignored.
const STICK_DEADZONE := 0.2

var can_place = true
@onready var level: Level = $"../../Level"
@onready var boden: TileMapLayer = $"../../Level/Room00/Boden"
@onready var waende_base: TileMapLayer = $"../../Level/Room00/Waende_base"
@onready var door: TileMapLayer = $"../../Level/Room00/door"
@onready var custom_walls: TileMapLayer = $"../../Level/Room00/CustomWalls"
@onready var cursor_sprite: Sprite2D = $Sprite2D

var current_item


# Set by _input on a controller X/Y press over the level; consumed in _process.
var _do_left := false
var _do_right := false

# Virtual cursor position in viewport space (which equals world space here: the
# editor camera sits at the viewport centre with zoom 1). Driven by the left stick,
# and snapped to the OS mouse whenever that moves — see _update_cursor().
var _cursor_pos := Vector2.ZERO
var _last_mouse := Vector2.ZERO
@onready var tab_container: TabContainer = get_node_or_null(
	"../Control/TabContainer")


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	# Fully freeze the player in the editor: PROCESS_MODE_DISABLED stops _process
	# (which reads movement input) and the state machine, so no walk animation
	# triggers when the left stick is used to move the cursor.
	PlayerManager.player.process_mode = Node.PROCESS_MODE_DISABLED
	PlayerManager.player.visible = true
	PlayerHud.visible = false

	# Draw the crosshair / item preview above all tile layers (Waende_base z=1,
	# Waende z=2, Objekte/CustomWalls z=3) so the cursor is never hidden behind a
	# wall. The editor GUI lives on a CanvasLayer, which always renders above the
	# 2D world regardless of z_index, so the palette/Start button stay reachable.
	z_index = 100

	_cursor_pos = get_viewport().get_visible_rect().size * 0.5
	_last_mouse = get_viewport().get_mouse_position()


func _process(delta: float) -> void:
	# A virtual cursor (driven by stick or real mouse) positions the crosshair;
	# everything below uses global_position, so controller and mouse share one cursor.
	_update_cursor(delta)
	global_position = _cursor_pos
	queue_redraw()

	# Real mouse OR the controller (X/Y handled in _input, which sets these flags).
	var left_click := Input.is_action_just_pressed("mb_left") or _do_left
	var right_click := Input.is_action_just_pressed("mb_right") or _do_right
	_do_left = false
	_do_right = false

	if LevelManager.skip_next_click and left_click:
		LevelManager.skip_next_click = false
		return

	if right_click and not LevelManager.place_tile:
		_try_delete_enemy()
	elif LevelManager.place_tile:
		_handle_wall_paint(left_click, right_click)
	elif current_item != null and can_place:
		if left_click:
			if _is_on_floor() and not _custom_wall_at_cursor():
				var new_item = current_item.instantiate()
				level.add_child(new_item)
				new_item.global_position = global_position
				new_item.set_physics_process(false)
				new_item.get_node("EnemyStateMachine").process_mode = Node.PROCESS_MODE_DISABLED
				cursor_sprite.texture = null
				current_item = null


func _draw() -> void:
	# Always-visible crosshair so the cursor position is clear with controller or mouse.
	# When an item is selected, the Sprite2D shows the item icon on top.
	var s := 10.0
	var gap := 3.0
	var thick := 2.0
	draw_line(Vector2(-s, 0), Vector2(-gap, 0), Color.WHITE, thick)
	draw_line(Vector2(gap, 0), Vector2(s, 0), Color.WHITE, thick)
	draw_line(Vector2(0, -s), Vector2(0, -gap), Color.WHITE, thick)
	draw_line(Vector2(0, gap), Vector2(0, s), Color.WHITE, thick)
	draw_arc(Vector2.ZERO, gap, 0, TAU, 12, Color.WHITE, thick)


# Move the virtual cursor with the left stick (device 0). We can't use
# Input.warp_mouse() to move the OS pointer because browsers ignore it while the
# mouse is visible — so the crosshair, placement and hit-testing all follow this
# internal position instead. The real mouse still works: when it moves we snap the
# cursor to it, so controller and laptop mouse share one cursor.
func _update_cursor(delta: float) -> void:
	# Read the left stick from whichever connected gamepad is actually being used.
	# We must NOT hardcode device 0: on the web export the browser often assigns the
	# controller a non-zero index (e.g. device 1), which made get_joy_axis(0, ...)
	# return 0 and left the crosshair stuck in the centre — only the mouse moved it.
	var stick := Vector2.ZERO
	for dev in Input.get_connected_joypads():
		var s := Vector2(
			Input.get_joy_axis(dev, JOY_AXIS_LEFT_X),
			Input.get_joy_axis(dev, JOY_AXIS_LEFT_Y))
		if s.length() > stick.length():
			stick = s
	var mouse := get_viewport().get_mouse_position()
	if stick.length() >= STICK_DEADZONE:
		_cursor_pos += stick * CURSOR_SPEED * delta
	elif mouse != _last_mouse:
		_cursor_pos = mouse
	_last_mouse = mouse
	_cursor_pos = _cursor_pos.clamp(Vector2.ZERO, get_viewport().get_visible_rect().size)


# Controller buttons. We act on the UI directly instead of synthesizing mouse
# clicks, because pushed mouse events don't reliably reach Control.gui_input.
#   X  : over UI -> select item / press button; over level -> place (via flag)
#   Y  : over level -> delete (via flag)
#   RB : switch palette tab (wraps; LB is taken by the "esc" action)
func _input(event: InputEvent) -> void:
	if not (event is InputEventJoypadButton and event.pressed):
		return
	match event.button_index:
		JOY_BUTTON_X:
			_controller_primary()
		JOY_BUTTON_Y:
			if _ui_control_at(_cursor_pos) == null:
				_do_right = true
		JOY_BUTTON_RIGHT_SHOULDER:
			_cycle_tab(1)


func _controller_primary() -> void:
	# gui_get_hovered_control() tracks hover via mouse-motion events, but on the web
	# export warp_mouse() doesn't emit them — so over the palette it would wrongly
	# report null and we'd try to place instead of select. Hit-test the GUI rects
	# against the cursor position instead (the position IS correct on web).
	var ctrl := _ui_control_at(_cursor_pos)
	if ctrl == null:
		# Over the level — let _process do the placement.
		_do_left = true
		return
	# Over UI — act on it directly. Walk up to find a palette item; otherwise, if
	# it's a button (e.g. Start), press it.
	var item := _find_selectable(ctrl)
	if item != null:
		item.select()
	elif ctrl is BaseButton:
		ctrl.pressed.emit()


func _find_selectable(node: Node) -> Node:
	var n := node
	while n != null:
		if n.has_method("select"):
			return n
		n = n.get_parent()
	return null


# Topmost visible, interactable Control under `point` (viewport coords) that is a
# palette item (has select()) or a button. Manual hit-test so it works on the web
# export, where gui_get_hovered_control() doesn't update from a warped cursor.
func _ui_control_at(point: Vector2) -> Control:
	var root := get_node_or_null("../Control")
	if root == null:
		return null
	return _hit_test_ui(root, point)


func _hit_test_ui(node: Node, point: Vector2) -> Control:
	# Children are drawn front-to-back in order, so search back-to-front for the
	# topmost match.
	for i in range(node.get_child_count() - 1, -1, -1):
		var found: Control = _hit_test_ui(node.get_child(i), point)
		if found != null:
			return found
	if node is Control:
		var c := node as Control
		if c.is_visible_in_tree() and c.mouse_filter != Control.MOUSE_FILTER_IGNORE \
				and c.get_global_rect().has_point(point) \
				and (c.has_method("select") or c is BaseButton):
			return c
	return null


func _cycle_tab(dir: int) -> void:
	if tab_container == null or tab_container.get_tab_count() == 0:
		return
	var count := tab_container.get_tab_count()
	tab_container.current_tab = (tab_container.current_tab + dir + count) % count


func _handle_wall_paint(left_click: bool, right_click: bool) -> void:
	var paint_cell = custom_walls.local_to_map(custom_walls.to_local(global_position))

	if left_click:
		if _is_on_floor() and not _enemy_on_cell(paint_cell):
			var below = paint_cell + Vector2i(0, 1)
			var is_above_ceiling = custom_walls.get_cell_atlas_coords(below) == Vector2i(4, 0)
			var is_on_ceiling = custom_walls.get_cell_atlas_coords(paint_cell) == Vector2i(4, 0)
			if is_above_ceiling or is_on_ceiling:
				custom_walls.set_cell(paint_cell, 0, Vector2i(4, 0))
			else:
				custom_walls.set_cell(paint_cell, 0, Vector2i(randi_range(0, 3), 0))
				_place_ceiling(paint_cell)

	elif right_click:
		var above = paint_cell + Vector2i(0, -1)
		var below = paint_cell + Vector2i(0, 1)
		var is_ceiling = custom_walls.get_cell_atlas_coords(paint_cell) == Vector2i(4, 0)
		custom_walls.erase_cell(paint_cell)
		if is_ceiling:
			custom_walls.erase_cell(below)
			_enforce_ceiling(below + Vector2i(0, 1))
			_enforce_wall(above)
		else:
			if custom_walls.get_cell_atlas_coords(above) == Vector2i(4, 0):
				custom_walls.erase_cell(above)
			_enforce_wall(above + Vector2i(0, -1))


func _place_ceiling(wall_cell: Vector2i) -> void:
	var above = wall_cell + Vector2i(0, -1)
	custom_walls.set_cell(above, 0, Vector2i(4, 0))


func _enforce_ceiling(cell: Vector2i) -> void:
	var src = custom_walls.get_cell_source_id(cell)
	var coords = custom_walls.get_cell_atlas_coords(cell)
	if src == -1 or coords == Vector2i(4, 0):
		return
	var above = cell + Vector2i(0, -1)
	if custom_walls.get_cell_atlas_coords(above) != Vector2i(4, 0):
		custom_walls.set_cell(above, 0, Vector2i(4, 0))


func _enforce_wall(cell: Vector2i) -> void:
	if custom_walls.get_cell_atlas_coords(cell) != Vector2i(4, 0):
		return
	var below = cell + Vector2i(0, 1)
	if custom_walls.get_cell_source_id(below) == -1:
		custom_walls.set_cell(below, 0, Vector2i(randi_range(0, 3), 0))


func _try_delete_enemy() -> void:
	for child in level.get_children():
		if child is Enemy and child.global_position.distance_to(global_position) < 32.0:
			child.queue_free()
			return


func _custom_wall_at_cursor() -> bool:
	var cell = custom_walls.local_to_map(custom_walls.to_local(global_position))
	return custom_walls.get_cell_source_id(cell) != -1


func _enemy_on_cell(cell: Vector2i) -> bool:
	for child in level.get_children():
		if child is Enemy:
			var ecell = custom_walls.local_to_map(custom_walls.to_local(child.global_position))
			if ecell == cell:
				return true
	return false


func _is_on_floor() -> bool:
	var cursor_pos = global_position
	var boden_cell = boden.local_to_map(boden.to_local(cursor_pos))
	var wall_cell = waende_base.local_to_map(waende_base.to_local(cursor_pos))
	var door_cell = door.local_to_map(door.to_local(cursor_pos))
	return boden.get_cell_source_id(boden_cell) != -1 \
		and waende_base.get_cell_source_id(wall_cell) == -1 \
		and door.get_cell_source_id(door_cell) == -1
