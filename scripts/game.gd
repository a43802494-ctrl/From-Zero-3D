extends Node3D

const SAVE_PATH := "user://fromzero_progress.json"
var world: RiseCity
var player: CityPlayer
var hud: GameHUD
var waypoint: Node3D
var waypoint_label: Label3D
var sound: AudioStreamPlayer
var ambience: AudioStreamPlayer

var cash := 120
var reputation := 0
var energy := 100.0
var deliveries := 0
var package_active := false
var awaiting_pickup := false
var last_destination_id := ""
var business_stock := 0
var destination_id := "cafe"
var scooter_owned := false
var business_owned := false
var business_clock := 0.0
var in_game := false
var paused := false
var current_poi := ""
var notification_cooldown := 0.0
var contract_board_open := false
var contract_reward := 95
var contract_seconds := 0.0
var contract_tier := 0
var save_clock := 0.0
var radar_clock := 0.0

func _ready() -> void:
    world = RiseCity.new()
    world.name = "RiseCity_Neighborhood"
    add_child(world)
    player = CityPlayer.new()
    player.position = Vector3(6, 1.2, 6)
    player.rotation.y = deg_to_rad(38)
    add_child(player)
    hud = GameHUD.new()
    add_child(hud)
    hud.play_pressed.connect(start_game)
    hud.new_game_pressed.connect(start_new_game)
    hud.interact_pressed.connect(interact)
    hud.jump_pressed.connect(func() -> void: player.request_jump())
    hud.pause_pressed.connect(toggle_pause)
    hud.contract_selected.connect(accept_contract)
    hud.contract_board_closed.connect(close_contract_board)
    hud.run_changed.connect(func(yes: bool) -> void: player.run_toggle = yes)
    hud.touch_moved.connect(func(direction: Vector2) -> void: player.set_touch_move(direction))
    hud.settings_changed.connect(func(sensitivity: float, high_quality: bool) -> void:
        player.look_sensitivity = sensitivity
        world.configure_graphics(high_quality)
    )
    player.look_sensitivity = hud.look_sens
    world.configure_graphics(hud.quality_high)
    create_waypoint()
    # Front-page uses its own aerial view; enter the body camera on Play.
    var hero_camera := Camera3D.new()
    hero_camera.name="MenuCamera"
    hero_camera.position = Vector3(36,16,43)
    hero_camera.fov = 69.0
    add_child(hero_camera)
    hero_camera.look_at(Vector3(0,2,0),Vector3.UP)
    hero_camera.make_current()
    create_audio()
    load_progress()
    refresh_ui()
    player.set_package(package_active)
    player.has_scooter = scooter_owned

func create_audio() -> void:
    sound = AudioStreamPlayer.new()
    sound.volume_db = -7.0
    add_child(sound)
    ambience = AudioStreamPlayer.new()
    ambience.stream = load("res://audio/ambience.ogg")
    ambience.volume_db = -24.0
    add_child(ambience)
    ambience.finished.connect(func() -> void: ambience.play())

func play_effect(file: String) -> void:
    sound.stream = load(file)
    sound.play()

func create_waypoint() -> void:
    waypoint = Node3D.new()
    waypoint.name = "حلقة_الهدف"
    add_child(waypoint)
    var ring := MeshInstance3D.new()
    var torus := TorusMesh.new()
    torus.inner_radius = 0.80
    torus.outer_radius = 0.94
    torus.rings = 64
    torus.ring_segments = 8
    ring.mesh = torus
    ring.position.y = 0.035
    var accent := StandardMaterial3D.new()
    accent.albedo_color=Color("ebc174")
    accent.emission_enabled=true
    accent.emission=Color("b87623")
    accent.emission_energy_multiplier=0.4
    accent.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
    accent.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
    ring.material_override=accent
    waypoint.add_child(ring)
    waypoint_label = Label3D.new()
    waypoint_label.text = ""
    waypoint_label.visible = false
    waypoint.add_child(waypoint_label)

func start_new_game() -> void:
    # Explicit fresh start; continuing uses the existing saved game.
    cash = 120
    reputation = 0
    energy = 100.0
    deliveries = 0
    package_active = false
    awaiting_pickup = false
    destination_id = "cafe"
    last_destination_id = ""
    scooter_owned = false
    business_owned = false
    business_stock = 0
    business_clock = 0.0
    contract_seconds = 0.0
    contract_reward = 95
    contract_tier = 0
    player.position = Vector3(6, 1.2, 6)
    player.rotation.y = deg_to_rad(38)
    player.has_scooter = false
    player.set_package(false)
    save_progress()
    start_game()

func start_game() -> void:
    in_game = true
    paused = false
    player.set_playing(true)
    hud.set_controls_active(true)
    player.cam.make_current()
    ambience.play()
    play_effect("res://audio/reward.ogg")
    hud.toast("الحكاية بدأت! روح مكتب الشحن وخد أول شغلانة.")

func toggle_pause() -> void:
    if not in_game: return
    if contract_board_open:
        hud.show_contract_board(false)
        close_contract_board()
        return
    paused = not paused
    player.set_playing(not paused)
    hud.set_controls_active(not paused)
    hud.show_pause(paused)
    if paused: save_progress()

func _unhandled_input(event: InputEvent) -> void:
    if not in_game or contract_board_open: return
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_ESCAPE:
            toggle_pause()
        elif not paused and event.keycode == KEY_E:
            interact()

func target_id() -> String:
    if package_active: return destination_id
    return "depot"

func get_point(id: String) -> Dictionary:
    for p in RiseCity.POINTS:
        if p["id"] == id: return p
    return RiseCity.POINTS[0]

func current_objective() -> String:
    if awaiting_pickup: return "اتفق مع البائع واستلم الطرد من مكتب الشحن"
    if package_active:
        return "وصل الطلب لـ " + get_point(destination_id)["title"]
    if deliveries == 0:
        return "ابدأ أول شغلانة من مكتب الشحن"
    if business_owned:
        return "مشروعك اشتغل! كمّل ووسّع تجارتك"
    return "ارجع مكتب الشحن وخد شغلانة جديدة"

func _process(delta: float) -> void:
    if not in_game or paused or contract_board_open: return
    var near := ""
    var best_dist := 3.7
    for p in RiseCity.POINTS:
        var target: Vector3 = world.interaction_position(str(p["id"]))
        var to_target: Vector3 = target - player.global_position
        to_target.y = 0.0
        var dist := to_target.length()
        # Only offer interaction when standing by the physical counter and
        # facing generally toward the service worker, not from behind a wall.
        var forward: Vector3 = -player.global_transform.basis.z
        forward.y = 0.0
        if dist < best_dist and dist < 3.7 and forward.normalized().dot(to_target.normalized()) > 0.0:
            best_dist = dist
            near = str(p["id"])
    current_poi = near
    var context_text := "قرّب من الموظف وبُص ناحيته عشان تتفاعل"
    if near != "": context_text = interaction_text(near)
    hud.update_interaction(context_text, near != "")
    
    var objective: Dictionary = get_point(target_id())
    var target_pos: Vector3 = world.interaction_position(str(objective["id"]))
    var horizontal := player.global_position - target_pos
    horizontal.y=0.0
    var distance := int(horizontal.length())
    waypoint.position = target_pos + Vector3(0, 0.12, 0)
    waypoint.rotation.y += delta * 0.65
    waypoint.visible = distance < 19 and distance > 2
    hud.update_objective(current_objective(), distance)
    contract_seconds = maxf(-0.01, contract_seconds - delta) if package_active else 0.0
    hud.update_contract_clock(contract_seconds, contract_reward, package_active)
    radar_clock += delta
    if radar_clock >= 0.12:
        radar_clock = 0.0
        hud.update_radar(player.global_position, player.rotation.y, target_id())
    
    if player.velocity.length() > 0.8:
        energy = maxf(0.0, energy - delta * (0.64 if player.run_toggle else 0.12))
    else:
        energy = minf(100.0, energy + delta * 0.07)
    player.fatigue_factor = lerpf(0.78, 1.0, clampf(energy / 30.0, 0.0, 1.0))
    if business_owned and business_stock > 0:
        business_clock += delta
        if business_clock >= 35.0:
            business_clock = 0.0
            business_stock -= 1
            cash += 35
            reputation += 1
            save_progress()
            hud.toast("اتبيعت بضاعة بـ٣٥ جنيه • باقي %d قطع" % business_stock)
            play_effect("res://audio/reward.ogg")
    save_clock += delta
    if save_clock > 12.0:
        save_clock = 0.0
        save_progress()
    refresh_ui()

func interaction_text(id: String) -> String:
    match id:
        "depot":
            if awaiting_pickup: return "اتكلم مع الموظف واستلم الطرد"
            return "معاك طلبية • لازم توصلها" if package_active else "اتكلم مع الموظف واختار شغلانة"
        "cafe":
            if package_active and destination_id == id: return "القهوة: سلّم الطلب"
            return "القهوة: وجبة بـ٢٥ جنيه تزود طاقتك"
        "market":
            if package_active and destination_id == id: return "السوبر ماركت: سلّم الطلب"
            return "السوبر ماركت: سرعة أعلى بـ٤٠٠ جنيه" if not scooter_owned else "السوبر ماركت: التطوير معاك بالفعل"
        "agency":
            if package_active and destination_id == id: return "مكتب المشاريع: سلّم الطلب"
            if not business_owned: return "مكتب المشاريع: افتح مشروع بـ٩٠٠ جنيه"
            return "خلص المخزون! جدده بـ١٠٠ جنيه" if business_stock == 0 else "المشروع: فاضل %d قطع في المخزون" % business_stock
    return "اتفرج على المدينة"

func interact() -> void:
    if not in_game or paused or contract_board_open or current_poi == "": return
    match current_poi:
        "depot":
            if awaiting_pickup:
                awaiting_pickup = false
                package_active = true
                player.set_package(true)
                hud.toast("استلمت الطرد من الموظف. روح لـ%s" % get_point(destination_id)["title"])
                play_effect("res://audio/buy.ogg")
                save_progress()
            elif package_active:
                hud.toast("سلّم الطلب اللي معاك الأول!")
                play_effect("res://audio/nope.ogg")
            else:
                contract_board_open = true
                player.set_playing(false)
                hud.set_controls_active(false)
                hud.show_contract_board(true, reputation)
        "cafe", "market", "agency":
            if package_active and current_poi == destination_id:
                complete_delivery()
            elif current_poi == "cafe":
                if cash >= 25:
                    cash -= 25
                    energy = minf(100.0, energy + 35.0)
                    hud.toast("بالهنا! طاقتك رجعت.")
                    play_effect("res://audio/buy.ogg")
                    save_progress()
                else: cannot_afford()
            elif current_poi == "market":
                if scooter_owned:
                    hud.toast("إنت اشتريت تطوير السرعة قبل كده")
                elif cash >= 400:
                    cash -= 400
                    scooter_owned = true
                    player.has_scooter = true
                    hud.toast("عاش! بقيت أسرع ٣٥٪")
                    play_effect("res://audio/reward.ogg")
                    save_progress()
                else: cannot_afford()
            elif current_poi == "agency":
                if business_owned and business_stock > 0:
                    hud.toast("عندك %d قطع • لما تخلص تعالى جدد المخزون" % business_stock)
                elif business_owned and cash >= 100:
                    cash -= 100
                    business_stock = 6
                    hud.toast("اشتريت ٦ قطع بضاعة بـ١٠٠ جنيه")
                    play_effect("res://audio/buy.ogg")
                    save_progress()
                elif not business_owned and cash >= 900:
                    cash -= 900
                    business_owned = true
                    business_stock = 6
                    reputation += 35
                    hud.toast("مبروك! افتتحت مشروعك ومعاك أول ٦ قطع بضاعة!")
                    play_effect("res://audio/reward.ogg")
                    save_progress()
                else: cannot_afford()
    refresh_ui()

func close_contract_board() -> void:
    contract_board_open = false
    player.set_playing(true)
    hud.set_controls_active(true)

func accept_contract(tier: int) -> void:
    if package_active or awaiting_pickup or tier < 0 or tier > 2: return
    if not ContractEconomy.is_unlocked(tier, reputation): return
    var contract_data: Dictionary = ContractEconomy.CONTRACTS[tier]
    contract_tier = tier
    contract_reward = int(contract_data["reward"])
    contract_seconds = float(contract_data["time"])
    var options := ["cafe", "market", "agency"]
    if last_destination_id in options and options.size() > 1:
        options.erase(last_destination_id)
    destination_id = options.pick_random()
    last_destination_id = destination_id
    awaiting_pickup = true
    package_active = false
    player.set_package(false)
    close_contract_board()
    hud.toast("اتفقنا على الشغلانة. قرّب من الموظف واضغط تفاعل لاستلام الطرد.")
    play_effect("res://audio/reward.ogg")
    save_progress()

func cannot_afford() -> void:
    hud.toast("فلوسك مش مكفية، اعمل توصيلات أكتر!")
    play_effect("res://audio/nope.ogg")

func complete_delivery() -> void:
    var reward: int = ContractEconomy.payout(contract_reward, contract_seconds)
    cash += reward
    reputation += 10 if contract_seconds > 0.0 else 5
    deliveries += 1
    package_active = false
    player.set_package(false)
    hud.toast("الطلب اتسلّم! +%d جنيه • سمعة +%d" % [reward, 10 if contract_seconds > 0.0 else 5])
    play_effect("res://audio/reward.ogg")
    save_progress()

func refresh_ui() -> void:
    if hud != null:
        hud.update_stats(cash, reputation, energy)

func save_progress() -> void:
    var state := {
        "cash": cash, "reputation": reputation, "energy": energy,
        "deliveries": deliveries, "package_active": package_active,
        "awaiting_pickup": awaiting_pickup, "last_destination_id": last_destination_id,
        "business_stock": business_stock,
        "destination_id": destination_id, "scooter_owned": scooter_owned,
        "business_owned": business_owned,
        "business_clock": business_clock,
        "contract_tier": contract_tier, "contract_reward": contract_reward,
        "contract_seconds": contract_seconds,
        "player_position": [player.position.x, player.position.y, player.position.z],
        "player_yaw": player.rotation.y
    }
    var staging := SAVE_PATH + ".tmp"
    var file := FileAccess.open(staging, FileAccess.WRITE)
    if file != null:
        file.store_string(JSON.stringify(state))
        file.flush()
        file.close()
        var rename_error := DirAccess.rename_absolute(ProjectSettings.globalize_path(staging), ProjectSettings.globalize_path(SAVE_PATH))
        if rename_error != OK:
            push_warning("Saving progress failed with %d" % rename_error)

func load_progress() -> void:
    if not FileAccess.file_exists(SAVE_PATH): return
    var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
    if file == null: return
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    file.close()
    if not (parsed is Dictionary): return
    var data: Dictionary = parsed
    cash = maxi(0, int(data.get("cash", cash)))
    reputation = maxi(0, int(data.get("reputation", reputation)))
    energy = clampf(float(data.get("energy", energy)), 0.0, 100.0)
    deliveries = maxi(0, int(data.get("deliveries", deliveries)))
    package_active = bool(data.get("package_active", package_active))
    awaiting_pickup = bool(data.get("awaiting_pickup", false))
    last_destination_id = str(data.get("last_destination_id", ""))
    destination_id = str(data.get("destination_id", destination_id))
    if destination_id not in ["cafe","market","agency"]: destination_id = "cafe"
    scooter_owned = bool(data.get("scooter_owned", scooter_owned))
    business_owned = bool(data.get("business_owned", business_owned))
    business_stock = clampi(int(data.get("business_stock", 6 if business_owned else 0)), 0, 1000)
    business_clock = float(data.get("business_clock", business_clock))
    contract_tier = clampi(int(data.get("contract_tier", 0)), 0, 2)
    contract_reward = clampi(int(data.get("contract_reward", 95)), 95, 260)
    contract_seconds = maxf(0.0, float(data.get("contract_seconds", 0.0)))
    var pos: Array = data.get("player_position", [])
    if pos.size() == 3:
        player.position = Vector3(clampf(float(pos[0]), -68.0, 68.0),
                                  clampf(float(pos[1]), 0.1, 8.0),
                                  clampf(float(pos[2]), -68.0, 68.0))
    player.rotation.y = float(data.get("player_yaw", player.rotation.y))
    if awaiting_pickup and package_active:
        awaiting_pickup = false
