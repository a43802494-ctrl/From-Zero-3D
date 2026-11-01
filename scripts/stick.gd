extends Control
class_name MobileStick

signal moved(value: Vector2)

var active_index := -1
var offset := Vector2.ZERO
var center_position := Vector2.ZERO
var max_radius := 65.0
var input_vector := Vector2.ZERO

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_process_input(true)
    center_position = global_position + size * 0.5

func _input(event: InputEvent) -> void:
    if not visible or not is_inside_tree(): return
    if event is InputEventScreenTouch:
        if event.pressed and active_index == -1 and is_move_zone(event.position):
            active_index = event.index
            center_position = global_position + size*0.5
            set_touch_point(event.position)
        elif not event.pressed and event.index == active_index:
            reset()
    elif event is InputEventScreenDrag and event.index == active_index:
        set_touch_point(event.position)
    # Mouse input allows verification in the Godot desktop editor.
    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        if event.pressed and active_index == -1 and is_move_zone(event.position):
            active_index = -100
            center_position = global_position + size*0.5
            set_touch_point(event.position)
        elif not event.pressed and active_index == -100:
            reset()
    elif event is InputEventMouseMotion and active_index == -100:
        set_touch_point(event.position)

func reset() -> void:
    active_index = -1
    offset = Vector2.ZERO
    input_vector = Vector2.ZERO
    moved.emit(Vector2.ZERO)
    queue_redraw()

func is_move_zone(screen_pos: Vector2) -> bool:
    var viewport := get_viewport().get_visible_rect().size
    # Bottom-left quarter reserved for movement. The right half is camera.
    return screen_pos.x >= 0 and screen_pos.x < viewport.x * 0.43 and screen_pos.y > viewport.y * 0.40 and screen_pos.y <= viewport.y

func set_touch_point(screen_pos: Vector2) -> void:
    max_radius = clampf(minf(size.x, size.y) * 0.33, 42.0, 88.0)
    offset = (screen_pos - center_position).limit_length(max_radius)
    input_vector = offset / max_radius
    if input_vector.length() < 0.13: input_vector = Vector2.ZERO
    moved.emit(input_vector)
    queue_redraw()

func _draw() -> void:
    var c := size*0.5
    var radius := minf(size.x,size.y)*0.45
    draw_circle(c, radius, Color(0.016,0.045,0.08,0.63))
    draw_arc(c, radius, 0.0, TAU, 72, Color(0.82,0.88,0.87,0.45), 3.0,true)
    draw_circle(c, radius*0.55, Color(0.17,0.24,0.29,0.28))
    draw_circle(c + offset, radius*0.42, Color(0.91,0.67,0.30,0.92))
    draw_circle(c + offset, radius*0.28, Color(0.99,0.91,0.76,0.93))
