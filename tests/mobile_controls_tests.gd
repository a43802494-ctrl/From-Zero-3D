extends SceneTree

func _initialize() -> void:
    call_deferred("check_controls")

func check_controls() -> void:
    root.size = Vector2i(1600,720)
    root.content_scale_size = Vector2i(1600,720)
    var hud := GameHUD.new()
    root.add_child(hud)
    await process_frame
    hud.update_hud_layout()
    assert(hud.is_mobile,"Mobile test flag is required")
    assert(hud.stick != null,"No movement joystick")
    assert(hud.stick.global_position.x >= 0.0 and hud.stick.global_position.y >= 0.0,"Joystick offscreen")
    assert(hud.stick.global_position.x + hud.stick.size.x <= hud.root.size.x,"Joystick outside right edge")
    assert(hud.stick.global_position.y + hud.stick.size.y <= hud.root.size.y,"Joystick outside bottom edge")
    assert(hud.action_button.global_position.x >= hud.root.size.x*0.50,"Action button misplaced")
    assert(hud.action_button.global_position.x + hud.action_button.size.x <= hud.root.size.x,"Action button offscreen")
    assert(hud.run_button.global_position.y + hud.run_button.size.y <= hud.root.size.y,"Run button offscreen")
    var center := hud.stick.global_position + hud.stick.size*0.5
    var samples := [Vector2(0,-1),Vector2(0,1),Vector2(-1,0),Vector2(1,0),Vector2(0.7,-0.7),Vector2(-0.7,-0.7),Vector2(0.7,0.7),Vector2(-0.7,0.7)]
    for direction in samples:
        hud.stick.center_position = center
        hud.stick.set_touch_point(center + direction*50.0)
        assert(hud.stick.input_vector.dot(direction.normalized()) > 0.5,"Joystick has broken direction: %s" % str(direction))
    hud.stick.reset()
    assert(hud.stick.input_vector.is_zero_approx(),"Joystick stuck after releasing touch")
    assert(hud.startup.visible,"Main menu missing")
    var found_play := false
    var found_settings := false
    for b in hud.startup.find_children("*","Button",true,false):
        var btn := b as Button
        if "PLAY" in btn.text: found_play = true
        if "SETTINGS" in btn.text: found_settings = true
    assert(found_play and found_settings,"Play or Settings button missing from main menu")
    print("TOUCH 8-DIRECTION / LAYOUT / MENU: PASS")
    quit(0)
