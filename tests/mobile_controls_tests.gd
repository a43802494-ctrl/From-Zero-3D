extends SceneTree

func _initialize() -> void:
    call_deferred("check_controls")

func check_controls() -> void:
    root.size=Vector2i(1600,720)
    root.content_scale_size=Vector2i(1600,720)
    var hud:=GameHUD.new()
    root.add_child(hud)
    await process_frame
    assert(hud.is_mobile,"Mobile test flag is required")
    assert(hud.stick != null,"No joystick")
    for dims in [Vector2i(1600,720),Vector2i(1280,720),Vector2i(960,540)]:
        root.size=dims
        root.content_scale_size=dims
        await process_frame
        hud.update_hud_layout()
        for button in [hud.stick,hud.action_button,hud.run_button,hud.jump_button,hud.hud_pause_button]:
            assert(button.global_position.x>=0 and button.global_position.y>=0,"Control outside screen: %s at %s"%[button.name,str(button.global_position)])
            assert(button.global_position.x+button.size.x<=hud.root.size.x+1.0,"Control beyond right edge")
            assert(button.global_position.y+button.size.y<=hud.root.size.y+1.0,"Control beyond bottom edge")
        assert(hud.startup_play.global_position.x>=0 and hud.startup_play.global_position.x+hud.startup_play.size.x<=dims.x,"PLAY button outside viewport")
        assert(hud.startup_settings.global_position.x>=0 and hud.startup_settings.global_position.x+hud.startup_settings.size.x<=dims.x,"SETTINGS button outside viewport")
    var center:=hud.stick.global_position+hud.stick.size*0.5
    var samples: Array[Vector2]=[Vector2(0,-1),Vector2(0,1),Vector2(-1,0),Vector2(1,0),Vector2(0.7,-0.7),Vector2(-0.7,-0.7),Vector2(0.7,0.7),Vector2(-0.7,0.7)]
    for direction in samples:
        hud.stick.center_position=center
        hud.stick.set_touch_point(center+direction*45.0)
        assert(hud.stick.input_vector.dot(direction.normalized())>0.62,"Joystick direction broken: %s"%str(direction))
    hud.stick.reset()
    assert(hud.stick.input_vector.is_zero_approx(),"Touch remains after release")
    assert(hud.startup.visible,"No front page")
    assert(hud.jump_button!=null,"No jump action")
    print("MOBILE 3 RESOLUTIONS + 8-WAY TOUCH + MENU: PASS")
    quit(0)
