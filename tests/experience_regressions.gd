extends SceneTree

func _initialize() -> void:
    call_deferred("run_checks")

func verify(ok: bool, explanation: String) -> bool:
    if ok: return true
    push_error("EXPERIENCE REGRESSION: " + explanation)
    quit(1)
    return false

func run_checks() -> void:
    root.size = Vector2i(1280,720)
    root.content_scale_size = Vector2i(1280,720)
    var hud := GameHUD.new()
    root.add_child(hud)
    await process_frame
    if not verify(hud.toast_panel != null, "toast background missing"): return
    if not verify(hud.toast_label.get_parent() == hud.toast_panel, "toast isn't on contrast panel"): return
    hud.toast("تجربة الكتابة على خلفية فاتحة")
    if not verify(hud.toast_panel.visible, "notification is not visible"): return
    if not verify(hud.toast_label.text.contains("الكتابة"), "notification text missing"): return
    var player := CityPlayer.new()
    root.add_child(player)
    await process_frame
    if not verify(player.footstep_player != null and player.footstep_player.stream != null, "new footstep sound missing"): return
    player.set_footstep_volume(0.0)
    if not verify(player.footstep_volume == 0.0, "can't mute footsteps"): return
    player.set_footstep_volume(0.22)
    if not verify(player.footstep_volume > 0.0 and player.footstep_volume < 0.3, "quiet default not available"): return
    print("HUD CONTRAST + SOFT FOOTSTEPS: PASS")
    quit(0)
