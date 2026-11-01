extends Control
class_name CityRadar

# Lightweight north-up 2D radar; no extra 3D viewport or GPU camera.
const MAP_SCALE := 1.12
const POI_POINTS := [
	{"id":"depot", "pos": Vector2(-23, -20), "color": Color("ffbd65")},
	{"id":"cafe", "pos": Vector2(23, -20), "color": Color("ff9184")},
	{"id":"market", "pos": Vector2(-23, 20), "color": Color("50d7c3")},
	{"id":"agency", "pos": Vector2(23, 20), "color": Color("8dc3ff")},
]
var current_position := Vector3.ZERO
var current_yaw := 0.0
var destination := "depot"

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func update_state(player_position: Vector3, yaw: float, objective_id: String) -> void:
	current_position = player_position
	current_yaw = yaw
	destination = objective_id
	queue_redraw()

func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, Color(0.045, 0.09, 0.145, 0.89), true)
	draw_rect(rect, Color("668596"), false, 1.6)
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.435
	draw_arc(center, radius, 0.0, TAU, 56, Color("608ba2", 0.55), 1.0, true)
	# World roads are aligned to X and Z. The radar stays north-up.
	var road_x := center.x - current_position.x * MAP_SCALE
	var road_y := center.y - current_position.z * MAP_SCALE
	if road_x >= 0.0 and road_x <= size.x:
		draw_rect(Rect2(road_x - 6.0, 4, 12, size.y - 8), Color("344b5b"))
	if road_y >= 0.0 and road_y <= size.y:
		draw_rect(Rect2(4, road_y - 6.0, size.x - 8, 12), Color("344b5b"))
	for item in POI_POINTS:
		var rel: Vector2 = item["pos"] - Vector2(current_position.x, current_position.z)
		var p := center + rel * MAP_SCALE
		if p.distance_to(center) > radius - 5.0:
			continue
		var dot_color: Color = item["color"]
		if item["id"] == destination:
			draw_arc(p, 7.8, 0, TAU, 24, Color("ffe3a0"), 2.2, true)
		draw_circle(p, 3.8, dot_color)
	# Arrow is the player's viewing direction, not a static dot.
	var forward := Vector2(-sin(current_yaw), -cos(current_yaw))
	var right := Vector2(-forward.y, forward.x)
	var arrow := PackedVector2Array([center + forward * 10.0, center - forward * 5.0 + right * 5.5, center - forward * 5.0 - right * 5.5])
	draw_colored_polygon(arrow, Color("ffffff"))
	draw_line(Vector2(center.x, 4), Vector2(center.x, 12), Color("e5ecef"), 1.7)
