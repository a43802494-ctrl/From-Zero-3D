extends CanvasLayer
class_name GameHUD

signal play_pressed
signal interact_pressed
signal run_changed(enabled: bool)
signal touch_moved(direction: Vector2)
signal pause_pressed
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
var ui_layout_size := Vector2.ZERO

func _ready() -> void:
	is_mobile = OS.has_feature("mobile") or OS.get_environment("FROMZERO_TEST_MOBILE") == "1"
	root = Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	# Apply the full-rect anchors only AFTER parenting the control.
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	create_game_ui()
	create_startup()
	create_pause_menu()
	create_contract_board()
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
	b.position = at
	b.size = extent
	b.custom_minimum_size = extent
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 22)
	b.add_theme_color_override("font_color", Color("122331") if primary else Color("f4f3ec"))
	b.add_theme_stylebox_override("normal", style(Color("f6bb65") if primary else Color("284258"), Color("fee0aa") if primary else Color("547082"), 14, 2))
	b.add_theme_stylebox_override("hover", style(Color("ffce81") if primary else Color("39546a"), Color("ffe2b7"), 14, 2))
	b.add_theme_stylebox_override("pressed", style(Color("d99a48") if primary else Color("182c3d"), Color("ffe2b7"), 14, 2))
	where.add_child(b)
	return b

func create_game_ui() -> void:
	var top := panel(root, Control.PRESET_TOP_LEFT, Vector2(21, 18), Vector2(342, 96), Color(0.055, 0.102, 0.154, 0.89), Color("546f80"))
	hud_top = top
	label("FROM ZERO  /  RISE CITY", 18, Color("f4b967"), top, Vector2(20, 10), Vector2(304, 25))
	money_label = label("120 EGP", 31, Color("fff8e9"), top, Vector2(19, 42), Vector2(230, 40))
	rep_label = label("REP 0", 17, Color("9ddacc"), top, Vector2(232, 45), Vector2(96, 32), HORIZONTAL_ALIGNMENT_RIGHT)
	var mission := panel(root, Control.PRESET_TOP_RIGHT, Vector2(-429, 18), Vector2(409, 129), Color(0.055, 0.102, 0.154, 0.89), Color("546f80"))
	hud_mission = mission
	label("YOUR NEXT MOVE", 17, Color("f4b967"), mission, Vector2(16, 7), Vector2(377, 24))
	objective_label = label("Find the delivery depot", 20, Color("f5f4eb"), mission, Vector2(16, 33), Vector2(377, 39))
	distance_label = label("", 16, Color("98d8d4"), mission, Vector2(16, 72), Vector2(377, 21))
	contract_countdown = label("", 16, Color("f6bb65"), mission, Vector2(16, 99), Vector2(377, 23))
	radar = CityRadar.new()
	radar.set_anchors_preset(Control.PRESET_CENTER_TOP)
	radar.position = Vector2(-78, 17)
	radar.size = Vector2(156, 156)
	root.add_child(radar)
	var bottom := panel(root, Control.PRESET_BOTTOM_LEFT, Vector2(22, -79), Vector2(260, 53), Color(0.055, 0.102, 0.154, 0.78))
	hud_bottom = bottom
	stamina_label = label("ENERGY  100%", 19, Color("b8e8d5"), bottom, Vector2(16, 6), Vector2(233, 40))
	var cross := label("+", 26, Color("ffffff"), root, Vector2(-13, -15), Vector2(26, 30), HORIZONTAL_ALIGNMENT_CENTER)
	hud_crosshair = cross
	cross.set_anchors_preset(Control.PRESET_CENTER)
	var prompt := panel(root, Control.PRESET_BOTTOM_RIGHT, Vector2(-425, -96), Vector2(390, 60), Color(0.055, 0.102, 0.154, 0.73), Color("43657a"))
	hud_prompt = prompt
	contextual_label = label("Explore the city", 18, Color("f7eddc"), prompt, Vector2(15, 8), Vector2(360, 41), HORIZONTAL_ALIGNMENT_RIGHT)
	toast_label = label("", 21, Color("fff4dc"), root, Vector2(-250, 142), Vector2(500, 52), HORIZONTAL_ALIGNMENT_CENTER)
	toast_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	toast_label.position = Vector2(-250, 142)
	toast_label.visible = false
	var pause_btn := make_button("II", root, Vector2(0, 0), Vector2(55, 49))
	pause_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	pause_btn.position = Vector2(-486, 137)
	hud_pause_button = pause_btn
	pause_btn.pressed.connect(func() -> void: pause_pressed.emit())
	if is_mobile:
		stick = MobileStick.new()
		root.add_child(stick)
		stick.size = Vector2(190, 190)
		stick.moved.connect(func(v: Vector2) -> void: touch_moved.emit(v))
		action_button = make_button("USE", root, Vector2(0, 0), Vector2(105, 73), true)
		action_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		action_button.position = Vector2(-142, -193)
		action_button.pressed.connect(func() -> void: interact_pressed.emit())
		run_button = make_button("RUN", root, Vector2(0, 0), Vector2(100, 59))
		run_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		run_button.position = Vector2(-258, -184)
		run_button.pressed.connect(_toggle_run)
		action_button.disabled = true
	else:
		var control_hint := label("WASD: MOVE    MOUSE: LOOK    E: USE    SHIFT: RUN", 14, Color("b9d8dd"), root, Vector2(-385, -20), Vector2(770, 22), HORIZONTAL_ALIGNMENT_CENTER)
		control_hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)

func _process(_delta: float) -> void:
	var current_size := root.size
	if current_size.x > 400 and current_size.y > 200 and current_size != ui_layout_size:
		update_hud_layout()

func place_control(control: Control, xy: Vector2, dimensions: Vector2) -> void:
	# Top-left anchors + pixel offsets are reliable on Android wide screens.
	# Negative positions set before parenting caused all controls to leave the screen.
	control.anchor_left = 0.0
	control.anchor_right = 0.0
	control.anchor_top = 0.0
	control.anchor_bottom = 0.0
	control.offset_left = xy.x
	control.offset_top = xy.y
	control.offset_right = xy.x + dimensions.x
	control.offset_bottom = xy.y + dimensions.y

func update_hud_layout() -> void:
	if root == null: return
	var v := root.size
	if v.x < 400 or v.y < 200:
		v = get_viewport().get_visible_rect().size
	if v.x < 400 or v.y < 200: return
	ui_layout_size = v
	var ui_scale := clampf(v.y / 720.0, 0.8, 1.5)
	place_control(hud_top, Vector2(20, 20), Vector2(342, 96))
	place_control(hud_mission, Vector2(v.x - 429, 20), Vector2(409, 129))
	place_control(radar, Vector2(v.x * 0.5 - 78, 20), Vector2(156, 156))
	place_control(hud_bottom, Vector2(20, v.y - 80), Vector2(260, 53))
	place_control(hud_prompt, Vector2(v.x - 425, v.y - 102), Vector2(390, 60))
	place_control(hud_crosshair, v * 0.5 - Vector2(13, 15), Vector2(26, 30))
	place_control(toast_label, Vector2(v.x * 0.5 - 250, 184), Vector2(500, 52))
	place_control(hud_pause_button, Vector2(v.x - 74, 162), Vector2(54, 49))
	if is_mobile:
		# Distinct left-thumb move and right-thumb action areas.
		var stick_side := 184.0 * ui_scale
		place_control(stick, Vector2(36, v.y - stick_side - 48), Vector2(stick_side, stick_side))
		place_control(action_button, Vector2(v.x - 160, v.y - 215), Vector2(130, 80))
		place_control(run_button, Vector2(v.x - 297, v.y - 200), Vector2(112, 70))
		# Gameplay text remains visible; unlike earlier builds, the action buttons
		# are not positioned using negative screen-space offsets.

func _toggle_run() -> void:
	running = not running
	run_button.text = "WALK" if running else "RUN"
	run_changed.emit(running)

func update_stats(cash: int, rep: int, stamina: float) -> void:
	money_label.text = "%d EGP" % cash
	rep_label.text = "REP %d" % rep
	stamina_label.text = "ENERGY  %d%%" % roundi(stamina)
	stamina_label.add_theme_color_override("font_color", Color("fb9a88") if stamina < 25.0 else Color("b8e8d5"))

func update_radar(position3d: Vector3, yaw: float, goal_id: String) -> void:
	radar.update_state(position3d, yaw, goal_id)

func update_contract_clock(remaining: float, total: int, active: bool) -> void:
	if not active:
		contract_countdown.text = "TAKE A CONTRACT AT THE DEPOT"
	elif remaining > 0.0:
		contract_countdown.text = "TIME BONUS  •  %ds LEFT  •  %d EGP BASE" % [ceili(remaining), total]
	else:
		contract_countdown.text = "LATE DELIVERY  •  %d EGP BASE" % total

func update_objective(message: String, meters: int) -> void:
	objective_label.text = message
	distance_label.text = "%dm AWAY" % meters if meters > 5 else "YOU'RE HERE"

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
	startup = Control.new()
	startup.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(startup)
	startup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shadow := ColorRect.new()
	shadow.color = Color(0.027, 0.063, 0.098, 0.91)
	shadow.set_anchors_preset(Control.PRESET_FULL_RECT)
	startup.add_child(shadow)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	startup.add_child(center)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(620, 520)
	card.add_theme_stylebox_override("panel", style(Color("102739"), Color("507b87"), 27, 2))
	center.add_child(card)
	var margins := MarginContainer.new()
	margins.add_theme_constant_override("margin_left", 47)
	margins.add_theme_constant_override("margin_right", 47)
	margins.add_theme_constant_override("margin_top", 33)
	margins.add_theme_constant_override("margin_bottom", 33)
	card.add_child(margins)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	margins.add_child(content)
	var tag := Label.new()
	tag.text = "THE CITY IS YOURS  •  FIRST-PERSON LIFE SIM"
	tag.add_theme_font_size_override("font_size", 16)
	tag.add_theme_color_override("font_color", Color("f8bd69"))
	content.add_child(tag)
	var title := Label.new()
	title.text = "FROM ZERO"
	title.add_theme_font_size_override("font_size", 68)
	title.add_theme_color_override("font_color", Color("f7f0df"))
	content.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "RISE CITY  /  CHAPTER ONE"
	subtitle.add_theme_font_size_override("font_size", 20)
	subtitle.add_theme_color_override("font_color", Color("8dced2"))
	content.add_child(subtitle)
	var separator := HSeparator.new()
	content.add_child(separator)
	var story := Label.new()
	story.text = "One city. 120 pounds. Nothing to lose.\n\nTake your first delivery, earn your first paycheck,\nupgrade your ride, and open your first business.\nEvery empire starts with a single decision."
	story.add_theme_font_size_override("font_size", 19)
	story.add_theme_color_override("font_color", Color("cadce0"))
	content.add_child(story)
	var button := make_button("ENTER THE CITY  >", content, Vector2.ZERO, Vector2(520, 65), true)
	button.pressed.connect(func() -> void:
		startup.visible = false
		play_pressed.emit()
	)
	var hint := Label.new()
	hint.text = "AN ORIGINAL GODOT 3D ANDROID GAME"
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color("83a4b2"))
	content.add_child(hint)

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
	title.text = "CITY PAUSED"
	title.add_theme_font_size_override("font_size", 51)
	title.add_theme_color_override("font_color", Color("f7f0df"))
	col.add_child(title)
	var resume := make_button("BACK TO THE CITY", col, Vector2.ZERO, Vector2(340, 70), true)
	resume.pressed.connect(func() -> void: pause_pressed.emit())
	var info := Label.new()
	info.text = "Progress saves automatically after each transaction."
	info.add_theme_color_override("font_color", Color("b5c9d3"))
	col.add_child(info)

func show_pause(yes: bool) -> void:
	pause_screen.visible = yes

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
	heading.text = "THE DEPOT  /  CONTRACT BOARD"
	heading.add_theme_font_size_override("font_size", 30)
	heading.add_theme_color_override("font_color", Color("ffd58c"))
	col.add_child(heading)
	var guidance := Label.new()
	guidance.text = "Choose a delivery. Beat the clock for a bonus.
Higher-tier contracts require reputation."
	guidance.add_theme_font_size_override("font_size", 17)
	guidance.add_theme_color_override("font_color", Color("bdcdd3"))
	col.add_child(guidance)
	var descriptions := [
		"LOCAL RUN    •    95 EGP    •    80 SEC    •    REP 0",
		"EXPRESS      •    160 EGP  •    65 SEC    •    REP 20",
		"PRIORITY     •    260 EGP  •    50 SEC    •    REP 80",
	]
	for tier in range(3):
		var b := make_button(descriptions[tier], col, Vector2.ZERO, Vector2(600, 62), tier == 0)
		b.add_theme_font_size_override("font_size", 17)
		b.pressed.connect(_choose_contract.bind(tier))
		contract_buttons.append(b)
	var back := make_button("NOT NOW", col, Vector2.ZERO, Vector2(600, 54))
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
