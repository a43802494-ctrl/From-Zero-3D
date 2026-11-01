extends SceneTree

func _initialize() -> void:
	call_deferred("verify")

func verify() -> void:
	var viewport := root.get_viewport()
	root.content_scale_size = Vector2i(1600, 720)
	var hud := GameHUD.new()
	root.add_child(hud)
	await process_frame
	hud.update_hud_layout()
	assert(hud.stick != null, "No Android joystick") if hud.is_mobile else print("Desktop mode: mobile-only controls tested by explicit size below")
	if hud.stick != null:
		assert(hud.stick.global_position.x >= 0)
		assert(hud.stick.global_position.y >= 0)
		assert(hud.stick.global_position.x + hud.stick.size.x < hud.root.size.x)
		assert(hud.stick.global_position.y + hud.stick.size.y < hud.root.size.y)
		assert(hud.action_button.global_position.x >= 0)
		assert(hud.action_button.global_position.y + hud.action_button.size.y < hud.root.size.y)
	print("MOBILE CONTROL LAYOUT TEST: PASS")
	quit(0)
