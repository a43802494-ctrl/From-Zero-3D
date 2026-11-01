extends Control
class_name MobileStick
signal moved(value: Vector2)

var active_index := -1
var offset := Vector2.ZERO
const MAX_RADIUS := 66.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process_input(true)

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		if event.pressed and active_index == -1 and get_global_rect().has_point(event.position):
			active_index = event.index
			update_stick(event.position)
		elif not event.pressed and active_index == event.index:
			active_index = -1
			offset = Vector2.ZERO
			moved.emit(Vector2.ZERO)
			queue_redraw()
	elif event is InputEventScreenDrag and active_index == event.index:
		update_stick(event.position)

func update_stick(screen_position: Vector2) -> void:
	var center := global_position + size * 0.5
	offset = (screen_position - center).limit_length(MAX_RADIUS)
	moved.emit(offset / MAX_RADIUS)
	queue_redraw()

func _draw() -> void:
	var center := size * 0.5
	draw_circle(center, 80.0, Color(0.08, 0.15, 0.23, 0.41), true, -1.0, true)
	draw_arc(center, 78.0, 0.0, TAU, 72, Color(0.57, 0.8, 0.93, 0.58), 2.2, true)
	draw_circle(center + offset, 33.0, Color(0.42, 0.79, 0.97, 0.49), true, -1.0, true)
	draw_circle(center + offset, 25.0, Color(0.75, 0.92, 0.98, 0.54), true, -1.0, true)
