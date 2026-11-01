extends SceneTree

# CI test must always terminate, even when a UI assertion fails.
func _init() -> void:
    call_deferred("_run_checks")

func verify(condition: bool, reason: String) -> bool:
    if condition:
        return true
    push_error("FROM ZERO MOBILE TEST FAILED: " + reason)
    print("MOBILE TEST FAILED: " + reason)
    quit(1)
    return false

func _run_checks() -> void:
    root.size = Vector2i(1600, 720)
    root.content_scale_size = Vector2i(1600, 720)
    var hud := GameHUD.new()
    root.add_child(hud)
    await process_frame
    if not verify(hud.is_mobile, "FROMZERO_TEST_MOBILE must be set"): return
    if not verify(hud.stick != null, "Joystick not initialized"): return

    for dims in [Vector2i(1600,720), Vector2i(1280,720), Vector2i(960,540)]:
        root.size = dims
        root.content_scale_size = dims
        await process_frame
        hud.update_hud_layout()
        for button in [hud.stick, hud.action_button, hud.run_button, hud.jump_button, hud.hud_pause_button]:
            if not verify(button != null, "Missing mobile control"): return
            var p: Vector2 = button.global_position
            if not verify(p.x >= -1 and p.y >= -1, "%s starts outside viewport (%s)" % [button.name, str(p)]): return
            if not verify(p.x + button.size.x <= hud.root.size.x + 1, "%s overflows right edge" % button.name): return
            if not verify(p.y + button.size.y <= hud.root.size.y + 1, "%s overflows bottom edge" % button.name): return
        if not verify(hud.startup_play != null and hud.startup_settings != null, "Main menu buttons missing"): return
        for menu_button in [hud.startup_play, hud.startup_settings]:
            if not verify(menu_button.global_position.x >= -1, "Menu button starts offscreen"): return
            if not verify(menu_button.global_position.x + menu_button.size.x <= dims.x + 1, "Menu button ends offscreen"): return

    var center: Vector2 = hud.stick.global_position + hud.stick.size * 0.5
    var samples: Array[Vector2] = [Vector2(0,-1), Vector2(0,1), Vector2(-1,0), Vector2(1,0), Vector2(0.7,-0.7), Vector2(-0.7,-0.7), Vector2(0.7,0.7), Vector2(-0.7,0.7)]
    for direction in samples:
        hud.stick.center_position = center
        hud.stick.set_touch_point(center + direction * 45.0)
        if not verify(hud.stick.input_vector.dot(direction.normalized()) > 0.62, "Broken joystick direction %s" % str(direction)): return
    hud.stick.reset()
    if not verify(hud.stick.input_vector.is_zero_approx(), "Joystick does not release"): return
    if not verify(hud.startup.visible, "Main menu invisible"): return
    print("MOBILE 3 RESOLUTIONS + 8-WAY TOUCH + MENU: PASS")
    quit(0)
