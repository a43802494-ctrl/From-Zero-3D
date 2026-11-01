extends SceneTree

func _initialize() -> void:
	call_deferred("verify")

func verify() -> void:
	root.size = Vector2i(1600, 720)
	root.content_scale_size = Vector2i(1600, 720)
	var hud := GameHUD.new()
	root.add_child(hud)
	await process_frame
	hud.update_hud_layout()
	assert(hud.is_mobile, "Test must set FROMZERO_TEST_MOBILE=1")
	assert(hud.stick != null, "Missing joystick")
	assert(hud.root.size.x > 400, "HUD has zero width")
	assert(hud.stick.global_position.x >= 0, "Joystick off left edge")
	assert(hud.stick.global_position.y >= 0, "Joystick above screen")
	assert(hud.stick.global_position.x + hud.stick.size.x < hud.root.size.x, "Joystick off right edge")
	assert(hud.stick.global_position.y + hud.stick.size.y < hud.root.size.y, "Joystick below screen")
	assert(hud.action_button.global_position.x > hud.root.size.x * 0.5, "Action button wrongly placed")
	assert(hud.action_button.global_position.y + hud.action_button.size.y < hud.root.size.y, "Action button below screen")
	assert(hud.run_button.global_position.x > hud.root.size.x * 0.5, "Run button wrongly placed")
	var center_pos := hud.stick.global_position + hud.stick.size * 0.5
	assert(hud.stick.is_move_zone(center_pos), "The joystick cannot receive left-thumb input")
	hud.stick.center_position = center_pos
	hud.stick.update_stick(center_pos + Vector2(0, -54))
	assert(hud.stick.offset.y < -40.0, "Stick did not respond to touch")
	print("MOBILE CONTROL LAYOUT TEST: PASS size=", hud.root.size, " stick=", hud.stick.global_position, " action=", hud.action_button.global_position)
	quit(0)
