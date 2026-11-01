extends Control
class_name MobileStick
signal moved(value: Vector2)

var active_index := -1
var offset := Vector2.ZERO
var center_position := Vector2.ZERO
var max_radius := 60.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process_input(true)

func _input(event: InputEvent) -> void:
	if not visible: return
	if event is InputEventScreenTouch:
		if event.pressed and active_index == -1 and is_move_zone(event.position):
			active_index = event.index
			center_position = global_position + size * 0.5
			update_stick(event.position)
		elif not event.pressed and event.index == active_index:
			active_index = -1
			offset = Vector2.ZERO
			moved.emit(Vector2.ZERO)
			queue_redraw()
	elif event is InputEventScreenDrag and event.index == active_index:
		update_stick(event.position)

func is_move_zone(screen_pos: Vector2) -> bool:
	# An oversized LEFT-THUMB activation area makes moving on small phones easy.
	var viewport_size := get_viewport().get_visible_rect().size
	return screen_pos.x < viewport_size.x * 0.43 and screen_pos.y > viewport_size.y * 0.41

func update_stick(screen_position: Vector2) -> void:
	max_radius = maxf(45.0, size.x * 0.34)
	offset = (screen_position - center_position).limit_length(max_radius)
	moved.emit(offset / max_radius)
	queue_redraw()

func _draw() -> void:
	var c := size * 0.5
	var base_radius := minf(size.x, size.y) * 0.47
	draw_circle(c, base_radius, Color(0.04, 0.13, 0.21, 0.76), true, -1.0, true)
	draw_arc(c, base_radius - 3.0, 0.0, TAU, 72, Color(0.58, 0.88, 1.0, 0.94), 5.0, true)
	draw_circle(c + offset, 39.0, Color(0.15, 0.55, 0.76, 0.92), true, -1.0, true)
	draw_circle(c + offset, 32.0, Color(0.55, 0.90, 0.99, 0.95), true, -1.0, true)
