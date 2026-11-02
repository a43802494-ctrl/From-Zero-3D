extends CanvasLayer
class_name GameHUD

signal play_pressed
signal settings_changed(look_value: float, high_quality: bool)
signal interact_pressed
signal run_changed(enabled: bool)
signal touch_moved(direction: Vector2)
signal pause_pressed
signal jump_pressed
signal contract_selected(tier: int)
signal contract_board_closed

var root: Control
var radar: CityRadar
var contract_panel: Control
var contract_buttons: Array[Button] = []
var contract_countdown: Label
var milestone_label: Label
var money_label: Label
var rep_label: Label
var stamina_label: Label
var objective_label: Label
var distance_label: Label
var contextual_label: Label
var toast_label: Label
var startup: Control
var pause_screen: Control
var stick: MobileStick
var run_button: Button
var action_button: Button
var message_id: int = 0
var running := false
var action_enabled := false
var is_mobile := false
var hud_top: Panel
var hud_mission: Panel
var hud_bottom: Panel
var hud_prompt: Panel
var hud_pause_button: Button
var hud_crosshair: Label
var jump_button: Button
var startup_title: Label
var startup_subtitle: Label
var startup_kicker: Label
var startup_footer: Label
var startup_play: Button
var startup_settings: Button
var startup_detail: Panel
var settings_card: PanelContainer
var pause_center: CenterContainer
var contract_card: PanelContainer
var ui_layout_size := Vector2.ZERO
var menu_identity_line: ColorRect
var settings_screen: Control
var startup_card: PanelContainer
var settings_open := false
var look_sens := 1.0
var quality_high := true
var volume_percent := 80.0


func _ready() -> void:
    is_mobile = OS.has_feature("mobile") or OS.get_environment("FROMZERO_TEST_MOBILE") == "1"
    root = Control.new()
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    # The OS may use Arabic RTL locale. Pin gamepad controls physically left/right.
    # In previous APK, automatic mirroring pushed the joystick to the RIGHT.
    root.layout_direction = Control.LAYOUT_DIRECTION_LTR
    var ui_font := SystemFont.new()
    ui_font.font_names = PackedStringArray(["Noto Naskh Arabic", "Noto Sans Arabic", "sans-serif"])
    var ui_theme := Theme.new()
    ui_theme.default_font = ui_font
    root.theme = ui_theme
    add_child(root)
    # Apply the full-rect anchors only AFTER parenting the control.
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    create_game_ui()
    create_startup()
    create_pause_menu()
    create_contract_board()
    create_settings_screen()
    load_settings()
    # Force all HUD children to inherit a fixed coordinate system regardless of
    # system locale; Arabic text is still shaped RTL by Godot's text renderer.
    for control in root.find_children("*", "Control", true, false):
        (control as Control).layout_direction = Control.LAYOUT_DIRECTION_LTR
    # No pre-parent negative offsets: every gameplay control is placed in screen coordinates.
    call_deferred("update_hud_layout")

func style(bg: Color, border: Color = Color.TRANSPARENT, corner: int = 18, border_size: int = 0) -> StyleBoxFlat:
    var s := StyleBoxFlat.new()
    s.bg_color = bg
    s.border_color = border
    s.set_corner_radius_all(corner)
    s.set_border_width_all(border_size)
    return s

func label(text_value: String, font_size: int, text_color: Color, parent: Node, at: Vector2, extent: Vector2, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
    var n := Label.new()
    n.text = text_value
    n.text_direction = Control.TEXT_DIRECTION_AUTO
    n.add_theme_font_size_override("font_size", font_size)
    n.add_theme_color_override("font_color", text_color)
    n.horizontal_alignment = align
    n.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    n.position = at
    n.size = extent
    n.mouse_filter = Control.MOUSE_FILTER_IGNORE
    parent.add_child(n)
    return n

func panel(parent: Node, anchor: int, at: Vector2, extent: Vector2, bg: Color, border: Color=Color.TRANSPARENT) -> Panel:
    var n := Panel.new()
    parent.add_child(n)
    n.set_anchors_preset(anchor)
    n.position = at
    n.size = extent
    n.add_theme_stylebox_override("panel", style(bg, border, 17, 1 if border != Color.TRANSPARENT else 0))
    n.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return n

func make_button(title: String, where: Control, at: Vector2, extent: Vector2, primary: bool = false) -> Button:
    var b := Button.new()
    b.text = title
    b.text_direction = Control.TEXT_DIRECTION_AUTO
    b.position = at
    b.size = extent
    b.custom_minimum_size = extent
    b.focus_mode = Control.FOCUS_NONE
    b.add_theme_font_size_override("font_size", 22)
    b.add_theme_color_override("font_color", Color("12212b") if primary else Color("f2f7f7"))
    b.add_theme_stylebox_override("normal", style(Color("e8ac59") if primary else Color("203443"), Color("fce6bd") if primary else Color("537082"), 13, 1))
    b.add_theme_stylebox_override("hover", style(Color("ffd08b") if primary else Color("354d60"), Color("ffe9c3"), 13, 2))
    b.add_theme_stylebox_override("pressed", style(Color("c98c3e") if primary else Color("182c3d"), Color("fff2db"), 13, 2))
    b.add_theme_stylebox_override("disabled", style(Color("33414b",0.7), Color("67727a",0.3), 13, 1))
    b.add_theme_color_override("font_disabled_color", Color("a3b1b9"))
    where.add_child(b)
    return b

func create_game_ui() -> void:
    var top := panel(root, Control.PRESET_TOP_LEFT, Vector2.ZERO, Vector2(264, 78), Color(0.023,0.052,0.080,0.90),Color("50717e"))
    hud_top = top
    label("الرصيد  •  جنيه", 13, Color("d9ab68"), top, Vector2(17,7), Vector2(232,21))
    money_label = label("120",29,Color("fff8e6"),top,Vector2(16,28),Vector2(175,40))
    rep_label = label("السمعة  0",14,Color("92d6c4"),top,Vector2(158,37),Vector2(95,23),HORIZONTAL_ALIGNMENT_RIGHT)
    var mission := panel(root,Control.PRESET_TOP_LEFT,Vector2.ZERO,Vector2(420,99),Color(0.020,0.052,0.074,0.86),Color("4d7180"))
    hud_mission = mission
    label("المهمة الحالية",13,Color("f2b86d"),mission,Vector2(15,7),Vector2(386,24))
    objective_label = label("روح مكتب الشحن واستلم أول شغلانة",18,Color("f8f8ee"),mission,Vector2(15,30),Vector2(388,31))
    distance_label = label("",14,Color("9ed4cc"),mission,Vector2(15,60),Vector2(95,27))
    contract_countdown = label("",13,Color("efcc92"),mission,Vector2(109,59),Vector2(290,27),HORIZONTAL_ALIGNMENT_RIGHT)
    radar = CityRadar.new()
    root.add_child(radar)
    radar.size = Vector2(120,120)
    var bottom := panel(root,Control.PRESET_TOP_LEFT,Vector2.ZERO,Vector2(183,42),Color(0.023,0.053,0.076,0.78))
    hud_bottom = bottom
    stamina_label = label("الطاقة  ١٠٠٪",16,Color("b9e6d7"),bottom,Vector2(12,3),Vector2(170,35))
    hud_crosshair = label("·",27,Color("ffffff"),root,Vector2.ZERO,Vector2(28,28),HORIZONTAL_ALIGNMENT_CENTER)
    var prompt := panel(root,Control.PRESET_TOP_LEFT,Vector2.ZERO,Vector2(320,49),Color(0.025,0.065,0.087,0.78),Color("3f6c77"))
    hud_prompt = prompt
    contextual_label = label("اتفرّج على المدينة",15,Color("f5eddf"),prompt,Vector2(11,4),Vector2(295,40),HORIZONTAL_ALIGNMENT_CENTER)
    toast_label = label("",19,Color("ffeac8"),root,Vector2.ZERO,Vector2(550,44),HORIZONTAL_ALIGNMENT_CENTER)
    toast_label.visible = false
    hud_pause_button = make_button("Ⅱ",root,Vector2.ZERO,Vector2(54,52))
    hud_pause_button.pressed.connect(func()->void: pause_pressed.emit())
    if is_mobile:
        stick=MobileStick.new()
        root.add_child(stick)
        stick.layout_direction=Control.LAYOUT_DIRECTION_LTR
        stick.size=Vector2(172,172)
        stick.moved.connect(func(v: Vector2)->void: touch_moved.emit(v))
        action_button = make_button("تفاعل",root,Vector2.ZERO,Vector2(102,74),true)
        action_button.pressed.connect(func()->void: interact_pressed.emit())
        action_button.disabled=true
        run_button = make_button("جري",root,Vector2.ZERO,Vector2(92,62))
        run_button.button_down.connect(func()->void: run_changed.emit(true))
        run_button.button_up.connect(func()->void: run_changed.emit(false))
        jump_button = make_button("نط",root,Vector2.ZERO,Vector2(89,52))
        jump_button.pressed.connect(func()->void: jump_pressed.emit())
    else:
        var hint := label("WASD للحركة  •  الماوس للنظر  •  Shift للجري  •  E للتفاعل",14,Color("bdd4db"),root,Vector2.ZERO,Vector2(680,26),HORIZONTAL_ALIGNMENT_CENTER)
        hint.name="DesktopHint"

func _process(_delta: float) -> void:
    if root == null: return
    var now := get_viewport().get_visible_rect().size
    if now.x > 400 and now.y > 200 and (now-ui_layout_size).length() > 1.0:
        update_hud_layout()

func place_control(control: Control, xy: Vector2, dimensions: Vector2) -> void:
    control.set_anchors_preset(Control.PRESET_TOP_LEFT)
    control.offset_left=xy.x
    control.offset_top=xy.y
    control.offset_right=xy.x+dimensions.x
    control.offset_bottom=xy.y+dimensions.y

func update_hud_layout() -> void:
    if root == null: return
    var v := get_viewport().get_visible_rect().size
    if v.x < 400 or v.y < 200: return
    ui_layout_size=v
    var k: float = clampf(v.y/720.0,0.65,1.50)
    var margin: float = maxf(14.0, v.x*0.014)
    place_control(hud_top,Vector2(margin,margin),Vector2(255,80)*k)
    place_control(hud_mission,Vector2(v.x - 425*k - margin,margin),Vector2(425,99)*k)
    place_control(radar,Vector2(v.x-134*k-margin,121*k),Vector2(120,120)*k)
    place_control(hud_bottom,Vector2(margin,106*k),Vector2(183,42)*k)
    place_control(hud_prompt,Vector2(v.x/2-160*k,v.y-60*k-margin),Vector2(320,49)*k)
    place_control(hud_crosshair,Vector2(v.x/2-14*k,v.y/2-14*k),Vector2(28,28)*k)
    place_control(toast_label,Vector2(v.x/2 - 275*k,135*k),Vector2(550,44)*k)
    place_control(hud_pause_button,Vector2(v.x-74*k-margin,226*k),Vector2(54,52)*k)
    if is_mobile:
        var joystick_diameter: float=177*k
        place_control(stick,Vector2(margin+10*k,v.y-joystick_diameter-25*k),Vector2.ONE*joystick_diameter)
        place_control(action_button,Vector2(v.x-134*k-margin,v.y-200*k),Vector2(112,68)*k)
        place_control(run_button,Vector2(v.x-258*k-margin,v.y-158*k),Vector2(96,60)*k)
        place_control(jump_button,Vector2(v.x-134*k-margin,v.y-112*k),Vector2(112,56)*k)
        # The joystick follows all size changes: its center must not remain at the old coordinates.
        if stick.active_index < 0:
            stick.center_position=stick.global_position+stick.size*0.5
    else:
        var hint := root.get_node_or_null("DesktopHint") as Control
        if hint: place_control(hint,Vector2(v.x*0.5-340*k,v.y-34*k),Vector2(680,26)*k)
    layout_main_menu(v,k,margin)
    if settings_card:
        settings_card.custom_minimum_size=Vector2(minf(v.x-32,570*k),minf(v.y-28,466*k))
    if contract_card:
        contract_card.custom_minimum_size=Vector2(minf(v.x-30,695*k),minf(v.y-20,520*k))

func _toggle_run() -> void:
    running = not running
    run_button.text = "مشي" if running else "جري"
    run_changed.emit(running)

func update_stats(cash: int, rep: int, stamina: float) -> void:
    money_label.text = "%d ج" % cash
    rep_label.text = "سمعة %d" % rep
    stamina_label.text = "الطاقة  %d%%" % roundi(stamina)
    stamina_label.add_theme_color_override("font_color", Color("fb9a88") if stamina < 25.0 else Color("b8e8d5"))

func update_radar(position3d: Vector3, yaw: float, goal_id: String) -> void:
    radar.update_state(position3d, yaw, goal_id)

func update_contract_clock(remaining: float, total: int, active: bool) -> void:
    if not active:
        contract_countdown.text = "روح مكتب الشحن واختار شغلانة"
    elif remaining > 0.0:
        contract_countdown.text = "مكافأة السرعة • %d ثانية • %d جنيه" % [ceili(remaining), total]
    else:
        contract_countdown.text = "التوصيل اتأخر • %d جنيه" % total

func update_objective(message: String, meters: int) -> void:
    objective_label.text = message
    distance_label.text = "فاضل %d متر" % meters if meters > 5 else "وصلت للمكان"

func update_interaction(message: String, ready: bool) -> void:
    contextual_label.text = ("[E]  " if ready and not is_mobile else "") + message
    action_enabled = ready
    if action_button != null:
        action_button.disabled = not ready

func toast(message: String) -> void:
    message_id += 1
    var mine := message_id
    toast_label.text = message
    toast_label.visible = true
    get_tree().create_timer(3.1).timeout.connect(func() -> void:
        if mine == message_id: toast_label.visible = false
    )

func create_startup() -> void:
    startup=Control.new()
    startup.mouse_filter=Control.MOUSE_FILTER_STOP
    root.add_child(startup)
    startup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    # Real-time city remains visible behind a two-tone cinematic scrim.
    var dark := ColorRect.new()
    dark.color=Color(0.012,0.029,0.043,0.52)
    startup.add_child(dark)
    dark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var strip := ColorRect.new()
    strip.color=Color("edb267")
    strip.name="AccentBar"
    startup.add_child(strip)
    startup_detail = panel(startup,Control.PRESET_TOP_LEFT,Vector2.ZERO,Vector2(500,570),Color(0.025,0.062,0.082,0.45))
    startup_detail.add_theme_stylebox_override("panel",style(Color(0.035,0.075,0.095,0.80),Color.TRANSPARENT,6))
    startup_kicker=label("الفصل الأول  •  بداية الحكاية",17,Color("f2b66b"),startup,Vector2.ZERO,Vector2(640,34))
    startup_title=label("من الصفر",81,Color("fff5e7"),startup,Vector2.ZERO,Vector2(730,98))
    startup_title.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
    startup_kicker.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
    startup_subtitle=label("معاك ١٢٠ جنيه... هتوصل لفين؟",23,Color("bacdd4"),startup,Vector2.ZERO,Vector2(750,46))
    startup_subtitle.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
    startup_play=make_button("ابدأ اللعب  ←",startup,Vector2.ZERO,Vector2(360,75),true)
    startup_play.add_theme_font_size_override("font_size",28)
    startup_play.pressed.connect(func()->void:
        startup.visible=false
        play_pressed.emit()
    )
    startup_settings=make_button("⚙  الإعدادات",startup,Vector2.ZERO,Vector2(360,64))
    startup_settings.pressed.connect(open_settings)
    startup_footer=label("شوارع مصر   /   شغل   /   مشاريع   /   تحديات",18,Color("96b2ba"),startup,Vector2.ZERO,Vector2(690,36))
    var v := get_viewport().get_visible_rect().size
    if v.x>400: layout_main_menu(v,clampf(v.y/720.0,0.65,1.5),maxf(14.0,v.x*0.014))

func layout_main_menu(v: Vector2, k: float, margin: float) -> void:
    if startup == null or startup_title == null: return
    var x := v.x - minf(575*k,v.x*0.55) - margin
    var y := v.y*0.14
    place_control(startup_detail,Vector2(x-25*k,margin+15*k),Vector2(minf(v.x*0.48,530*k),v.y-2*margin-30*k))
    var accent: Control = startup.get_node("AccentBar")
    place_control(accent,Vector2(x,y-4*k),Vector2(88,5)*k)
    place_control(startup_kicker,Vector2(x,y+10*k),Vector2(470,32)*k)
    place_control(startup_title,Vector2(x,y+50*k),Vector2(465,100)*k)
    place_control(startup_subtitle,Vector2(x,y+157*k),Vector2(455,44)*k)
    place_control(startup_play,Vector2(x+28*k,y+242*k),Vector2(408,69)*k)
    place_control(startup_settings,Vector2(x+28*k,y+327*k),Vector2(408,62)*k)
    place_control(startup_footer,Vector2(x,y+404*k),Vector2(468,32)*k)

func create_pause_menu() -> void:
    pause_screen = Control.new()
    pause_screen.mouse_filter = Control.MOUSE_FILTER_STOP
    pause_screen.visible = false
    root.add_child(pause_screen)
    pause_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var dim := ColorRect.new()
    dim.color = Color(0.025, 0.057, 0.085, 0.93)
    dim.set_anchors_preset(Control.PRESET_FULL_RECT)
    pause_screen.add_child(dim)
    var c := CenterContainer.new()
    c.set_anchors_preset(Control.PRESET_FULL_RECT)
    pause_screen.add_child(c)
    var col := VBoxContainer.new()
    col.add_theme_constant_override("separation", 15)
    c.add_child(col)
    var title := Label.new()
    title.text = "اللعبة متوقفة"
    title.add_theme_font_size_override("font_size", 51)
    title.add_theme_color_override("font_color", Color("f7f0df"))
    col.add_child(title)
    var resume := make_button("كمّل لعب", col, Vector2.ZERO, Vector2(340, 70), true)
    resume.pressed.connect(func() -> void: pause_pressed.emit())
    var pause_settings := make_button("⚙ الإعدادات", col, Vector2.ZERO, Vector2(340,63))
    pause_settings.pressed.connect(open_settings)
    var info := Label.new()
    info.text = "اللعبة بتحفظ تقدمك تلقائيًا."
    info.add_theme_color_override("font_color", Color("b5c9d3"))
    col.add_child(info)

func show_pause(yes: bool) -> void:
    pause_screen.visible = yes

func create_settings_screen() -> void:
    settings_screen = Control.new()
    settings_screen.visible = false
    settings_screen.mouse_filter = Control.MOUSE_FILTER_STOP
    root.add_child(settings_screen)
    settings_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var tint := ColorRect.new()
    tint.color = Color(0.008,0.022,0.036,0.94)
    settings_screen.add_child(tint)
    tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var center := CenterContainer.new()
    settings_screen.add_child(center)
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var card := PanelContainer.new()
    settings_card = card
    card.custom_minimum_size = Vector2(560,425)
    card.add_theme_stylebox_override("panel", style(Color("122635"),Color("ddae65"),22,2))
    center.add_child(card)
    var outer := MarginContainer.new()
    for side in ["left","right","top","bottom"]: outer.add_theme_constant_override("margin_"+side, 30)
    card.add_child(outer)
    var content := VBoxContainer.new()
    content.add_theme_constant_override("separation", 15)
    outer.add_child(content)
    var title := Label.new()
    title.text = "⚙  الإعدادات"
    title.add_theme_font_size_override("font_size", 34)
    title.add_theme_color_override("font_color",Color("fff5df"))
    content.add_child(title)
    var volume_lbl := Label.new()
    volume_lbl.text = "مستوى الصوت"
    volume_lbl.add_theme_font_size_override("font_size",20)
    content.add_child(volume_lbl)
    var volume_slider := HSlider.new()
    volume_slider.name = "VolumeSlider"
    volume_slider.min_value = 0
    volume_slider.max_value = 100
    volume_slider.step = 5
    volume_slider.value = volume_percent
    volume_slider.custom_minimum_size.y = 35
    content.add_child(volume_slider)
    volume_slider.value_changed.connect(func(v: float) -> void:
        volume_percent = v
        apply_settings()
    )
    var look_lbl := Label.new()
    look_lbl.text = "حساسية الكاميرا"
    look_lbl.add_theme_font_size_override("font_size",20)
    content.add_child(look_lbl)
    var sensitivity := HSlider.new()
    sensitivity.name = "LookSlider"
    sensitivity.min_value = 0.5
    sensitivity.max_value = 2.0
    sensitivity.step = 0.1
    sensitivity.value = look_sens
    sensitivity.custom_minimum_size.y = 34
    content.add_child(sensitivity)
    sensitivity.value_changed.connect(func(v: float) -> void:
        look_sens = v
        apply_settings()
    )
    var shadows := CheckButton.new()
    shadows.name = "ShadowsToggle"
    shadows.text = "ظلال وإضاءة بجودة أعلى"
    shadows.button_pressed = quality_high
    shadows.add_theme_font_size_override("font_size",18)
    content.add_child(shadows)
    shadows.toggled.connect(func(v: bool) -> void:
        quality_high = v
        apply_settings()
    )
    var back := make_button("حفظ ورجوع",content,Vector2.ZERO,Vector2(490,60),true)
    back.pressed.connect(func() -> void:
        save_settings()
        settings_screen.visible = false
        settings_open = false
    )

func open_settings() -> void:
    settings_open = true
    settings_screen.visible = true

func apply_settings() -> void:
    AudioServer.set_bus_volume_db(0, linear_to_db(maxf(0.0001,volume_percent/100.0)))
    settings_changed.emit(look_sens, quality_high)

func save_settings() -> void:
    var config := ConfigFile.new()
    config.set_value("audio","volume",volume_percent)
    config.set_value("input","look",look_sens)
    config.set_value("graphics","shadows",quality_high)
    config.save("user://settings.cfg")

func load_settings() -> void:
    var cfg := ConfigFile.new()
    if cfg.load("user://settings.cfg") == OK:
        volume_percent = float(cfg.get_value("audio","volume",80.0))
        look_sens = float(cfg.get_value("input","look",1.0))
        quality_high = bool(cfg.get_value("graphics","shadows",true))
    var sliders := settings_screen.find_children("*","HSlider",true,false)
    for item in sliders:
        if item.name == "VolumeSlider": item.value = volume_percent
        elif item.name == "LookSlider": item.value = look_sens
    var shadows := settings_screen.find_child("ShadowsToggle",true,false) as CheckButton
    if shadows: shadows.button_pressed = quality_high
    apply_settings()

func create_contract_board() -> void:
    contract_panel = Control.new()
    contract_panel.mouse_filter = Control.MOUSE_FILTER_STOP
    contract_panel.visible = false
    root.add_child(contract_panel)
    contract_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var dim := ColorRect.new()
    dim.color = Color(0.012, 0.035, 0.06, 0.90)
    dim.set_anchors_preset(Control.PRESET_FULL_RECT)
    contract_panel.add_child(dim)
    var center := CenterContainer.new()
    center.set_anchors_preset(Control.PRESET_FULL_RECT)
    contract_panel.add_child(center)
    var card := PanelContainer.new()
    contract_card = card
    card.custom_minimum_size = Vector2(660, 480)
    card.add_theme_stylebox_override("panel", style(Color("122a3a"), Color("6b8c96"), 24, 2))
    center.add_child(card)
    var margin := MarginContainer.new()
    for direction in ["left", "right", "top", "bottom"]:
        margin.add_theme_constant_override("margin_" + direction, 27)
    card.add_child(margin)
    var col := VBoxContainer.new()
    col.add_theme_constant_override("separation", 12)
    margin.add_child(col)
    var heading := Label.new()
    heading.text = "مكتب الشحن  •  الشغلانات المتاحة"
    heading.add_theme_font_size_override("font_size", 30)
    heading.add_theme_color_override("font_color", Color("ffd58c"))
    col.add_child(heading)
    var guidance := Label.new()
    guidance.text = "اختار الطلب اللي يناسبك. لو وصلت بدري، ليك مكافأة زيادة.
شغلانات أعلى بتحتاج سمعة أعلى."
    guidance.add_theme_font_size_override("font_size", 17)
    guidance.add_theme_color_override("font_color", Color("bdcdd3"))
    col.add_child(guidance)
    var descriptions := [
        "توصيل قريب  •  ٩٥ جنيه  •  ٨٠ ثانية  •  بدون شروط",
        "توصيل سريع  •  ١٦٠ جنيه  •  ٦٥ ثانية  •  سمعة ٢٠",
        "طلبية مهمة  •  ٢٦٠ جنيه  •  ٥٠ ثانية  •  سمعة ٨٠",
    ]
    for tier in range(3):
        var b := make_button(descriptions[tier], col, Vector2.ZERO, Vector2(600, 62), tier == 0)
        b.add_theme_font_size_override("font_size", 17)
        b.pressed.connect(_choose_contract.bind(tier))
        contract_buttons.append(b)
    var back := make_button("رجوع", col, Vector2.ZERO, Vector2(600, 54))
    back.pressed.connect(func() -> void:
        contract_panel.visible = false
        contract_board_closed.emit()
    )

func _choose_contract(tier: int) -> void:
    contract_panel.visible = false
    contract_selected.emit(tier)

func show_contract_board(opened: bool, reputation: int = 0) -> void:
    contract_panel.visible = opened
    if opened:
        for tier in range(3):
            var required: int = int(ContractEconomy.CONTRACTS[tier]["min_rep"])
            contract_buttons[tier].disabled = reputation < required
