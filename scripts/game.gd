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
	hud.interact_pressed.connect(interact)
	hud.pause_pressed.connect(toggle_pause)
	hud.contract_selected.connect(accept_contract)
	hud.contract_board_closed.connect(close_contract_board)
	hud.run_changed.connect(func(yes: bool) -> void: player.run_toggle = yes)
	hud.touch_moved.connect(func(direction: Vector2) -> void: player.set_touch_move(direction))
	create_waypoint()
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
	add_child(waypoint)
	var orb := MeshInstance3D.new()
	var sphere_mesh := SphereMesh.new()
	sphere_mesh.radius = 0.4
	sphere_mesh.height = 0.8
	sphere_mesh.radial_segments = 12
	sphere_mesh.rings = 6
	orb.mesh = sphere_mesh
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color("ffd27d")
	glow.emission_enabled = true
	glow.emission = Color("ffbb62")
	glow.emission_energy_multiplier = 1.8
	orb.material_override = glow
	waypoint.add_child(orb)
	var beam := MeshInstance3D.new()
	var pillar := CylinderMesh.new()
	pillar.top_radius = 0.022
	pillar.bottom_radius = 0.022
	pillar.height = 2.8
	beam.mesh = pillar
	beam.position.y = -1.64
	beam.material_override = glow
	waypoint.add_child(beam)
	waypoint_label = Label3D.new()
	waypoint_label.text = "OBJECTIVE"
	waypoint_label.font_size = 50
	waypoint_label.pixel_size = 0.007
	waypoint_label.position.y = 0.85
	waypoint_label.modulate = Color("ffe6b7")
	waypoint_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	waypoint.add_child(waypoint_label)

func start_game() -> void:
	in_game = true
	paused = false
	player.set_playing(true)
	ambience.play()
	play_effect("res://audio/reward.ogg")
	hud.toast("Your story starts now. Find THE DEPOT and take a contract.")

func toggle_pause() -> void:
	if not in_game: return
	if contract_board_open:
		hud.show_contract_board(false)
		close_contract_board()
		return
	paused = not paused
	player.set_playing(not paused)
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
	if package_active:
		return "Deliver your parcel to " + get_point(destination_id)["title"]
	if deliveries == 0:
		return "Get your first job at THE DEPOT"
	if business_owned:
		return "Own your future. Keep earning!"
	return "Return to THE DEPOT for more work"

func _process(delta: float) -> void:
	if not in_game or paused or contract_board_open: return
	var near := ""
	var best_dist := 4.4
	for p in RiseCity.POINTS:
		var diff: Vector3 = player.global_position - p["position"]
		diff.y = 0.0
		var dist := diff.length()
		if dist < best_dist:
			best_dist = dist
			near = p["id"]
	current_poi = near
	var context_text := "Find work. Build your future."
	if near != "": context_text = interaction_text(near)
	hud.update_interaction(context_text, near != "")
	
	var objective: Dictionary = get_point(target_id())
	var target_pos: Vector3 = objective["position"]
	var distance := int(player.global_position.distance_to(target_pos))
	waypoint.position = target_pos + Vector3(0, 4.5 + sin(Time.get_ticks_msec() * 0.002) * 0.25, 0)
	waypoint.rotation.y += delta * 1.7
	waypoint_label.text = "%s  •  %dm" % [objective["title"], distance]
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
	if business_owned:
		business_clock += delta
		if business_clock >= 35.0:
			business_clock -= 35.0
			cash += 35
			reputation += 1
			save_progress()
			hud.toast("Your business earned +35 EGP!")
			play_effect("res://audio/reward.ogg")
	save_clock += delta
	if save_clock > 12.0:
		save_clock = 0.0
		save_progress()
	refresh_ui()

func interaction_text(id: String) -> String:
	match id:
		"depot":
			return "THE DEPOT · Parcel already loaded" if package_active else "THE DEPOT · Browse delivery contracts"
		"cafe":
			if package_active and destination_id == id: return "CAFE · Drop off parcel"
			return "CAFE · Meal +35 energy / 25 EGP"
		"market":
			if package_active and destination_id == id: return "MARKET · Drop off parcel"
			return "MARKET · Faster movement / 400 EGP" if not scooter_owned else "MARKET · Upgrade already owned"
		"agency":
			if package_active and destination_id == id: return "BUSINESS HUB · Drop off parcel"
			return "BUSINESS HUB · Open business / 900 EGP" if not business_owned else "BUSINESS HUB · Your business is operating"
	return "Explore"

func interact() -> void:
	if not in_game or paused or contract_board_open or current_poi == "": return
	match current_poi:
		"depot":
			if package_active:
				hud.toast("First, deliver your parcel!")
				play_effect("res://audio/nope.ogg")
			else:
				contract_board_open = true
				player.set_playing(false)
				hud.show_contract_board(true, reputation)
		"cafe", "market", "agency":
			if package_active and current_poi == destination_id:
				complete_delivery()
			elif current_poi == "cafe":
				if cash >= 25:
					cash -= 25
					energy = minf(100.0, energy + 35.0)
					hud.toast("Good meal! Energy restored.")
					play_effect("res://audio/buy.ogg")
					save_progress()
				else: cannot_afford()
			elif current_poi == "market":
				if scooter_owned:
					hud.toast("Speed upgrade already unlocked")
				elif cash >= 400:
					cash -= 400
					scooter_owned = true
					player.has_scooter = true
					hud.toast("FAST TRAVEL UPGRADE! Movement +35%")
					play_effect("res://audio/reward.ogg")
					save_progress()
				else: cannot_afford()
			elif current_poi == "agency":
				if business_owned:
					hud.toast("Your business is already earning for you!")
				elif cash >= 900:
					cash -= 900
					business_owned = true
					reputation += 35
					hud.toast("MILESTONE! Your first business is now open!")
					play_effect("res://audio/reward.ogg")
					save_progress()
				else: cannot_afford()
	refresh_ui()

func close_contract_board() -> void:
	contract_board_open = false
	player.set_playing(true)

func accept_contract(tier: int) -> void:
	if package_active or tier < 0 or tier > 2: return
	if not ContractEconomy.is_unlocked(tier, reputation): return
	var contract_data: Dictionary = ContractEconomy.CONTRACTS[tier]
	contract_tier = tier
	contract_reward = int(contract_data["reward"])
	contract_seconds = float(contract_data["time"])
	var options := ["cafe", "market", "agency"]
	destination_id = options[(deliveries + tier) % options.size()]
	package_active = true
	player.set_package(true)
	close_contract_board()
	hud.toast("CONTRACT ACCEPTED! Follow the beacon to " + get_point(destination_id)["title"])
	play_effect("res://audio/reward.ogg")
	save_progress()

func cannot_afford() -> void:
	hud.toast("Not enough EGP. Make more deliveries!")
	play_effect("res://audio/nope.ogg")

func complete_delivery() -> void:
	var reward: int = ContractEconomy.payout(contract_reward, contract_seconds)
	cash += reward
	reputation += 10
	deliveries += 1
	package_active = false
	player.set_package(false)
	hud.toast("CONTRACT COMPLETE! +%d EGP  •  +10 REP" % reward)
	play_effect("res://audio/reward.ogg")
	save_progress()

func refresh_ui() -> void:
	if hud != null:
		hud.update_stats(cash, reputation, energy)

func save_progress() -> void:
	var state := {
		"cash": cash, "reputation": reputation, "energy": energy,
		"deliveries": deliveries, "package_active": package_active,
		"destination_id": destination_id, "scooter_owned": scooter_owned,
		"business_owned": business_owned,
		"business_clock": business_clock,
		"contract_tier": contract_tier, "contract_reward": contract_reward,
		"contract_seconds": contract_seconds,
		"player_position": [player.position.x, player.position.y, player.position.z],
		"player_yaw": player.rotation.y
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(state))
		file.close()

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
	destination_id = str(data.get("destination_id", destination_id))
	scooter_owned = bool(data.get("scooter_owned", scooter_owned))
	business_owned = bool(data.get("business_owned", business_owned))
	business_clock = float(data.get("business_clock", business_clock))
	contract_tier = clampi(int(data.get("contract_tier", 0)), 0, 2)
	contract_reward = clampi(int(data.get("contract_reward", 95)), 95, 260)
	contract_seconds = maxf(0.0, float(data.get("contract_seconds", 0.0)))
	var pos: Array = data.get("player_position", [])
	if pos.size() == 3:
		player.position = Vector3(float(pos[0]), maxf(0.1, float(pos[1])), float(pos[2]))
	player.rotation.y = float(data.get("player_yaw", player.rotation.y))
