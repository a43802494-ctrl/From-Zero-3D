extends CharacterBody3D
class_name CityPlayer

const WALK_SPEED := 5.8
const RUN_SPEED := 9.2
const ACCELERATION := 22.0
const BRAKING := 30.0
const JUMP_VELOCITY := 6.5
const GRAVITY := 18.0
const MOUSE_SENS := 0.0024
var look_sensitivity := 1.0

var touch_move := Vector2.ZERO
var filtered_touch_move := Vector2.ZERO
var look_touch_index := -1
var run_toggle := false
var control_active := false
var has_scooter := false
var fatigue_factor := 1.0
var head: Node3D
var cam: Camera3D
var held_package: Node3D
var step_timer := 0.0
var bob_clock := 0.0
var footstep_player: AudioStreamPlayer
var jump_requested := false
var move_yaw_rate := 0.0

func _ready() -> void:
	name = "FirstPersonPlayer"
	collision_layer = 2
	collision_mask = 1
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.36
	capsule.height = 1.8
	collision.shape = capsule
	collision.position.y = 0.9
	add_child(collision)
	
	head = Node3D.new()
	head.name = "Head"
	head.position.y = 1.62
	add_child(head)
	cam = Camera3D.new()
	cam.current = true
	cam.fov = 78.0
	cam.near = 0.07
	head.add_child(cam)
	
	# First-person held parcel is deliberately a 3D prop, not a UI picture.
	held_package = Node3D.new()
	held_package.position = Vector3(0.42, -0.70, -0.86)
	cam.add_child(held_package)
	var box := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.24, 0.16, 0.25)
	box.mesh = mesh
	var paper := StandardMaterial3D.new()
	paper.albedo_color = Color("c39c61")
	paper.roughness = 0.93
	box.material_override = paper
	held_package.add_child(box)
	var band := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.25, 0.17, 0.035)
	band.mesh = bm
	var tape := StandardMaterial3D.new()
	tape.albedo_color = Color("e6ca9a")
	band.material_override = tape
	held_package.add_child(band)
	held_package.visible = false
	# Removed the placeholder sphere hands: they looked like floating balls.
	# Professional hand meshes and proper animations belong in the art pass.

	footstep_player = AudioStreamPlayer.new()
	footstep_player.volume_db = -14.0
	footstep_player.stream = load("res://audio/step.ogg")
	add_child(footstep_player)

func build_first_person_arms() -> void:
	# In first person the full body is hidden; animated sleeves and hands sell the view.
	var jacket := StandardMaterial3D.new()
	jacket.albedo_color = Color("2a4560")
	jacket.roughness = 0.91
	var skin := StandardMaterial3D.new()
	skin.albedo_color = Color("d2a17b")
	skin.roughness = 0.87
	for side in [-1.0, 1.0]:
		var sleeve := MeshInstance3D.new()
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 0.11
		cylinder.bottom_radius = 0.14
		cylinder.height = 0.49
		sleeve.mesh = cylinder
		sleeve.material_override = jacket
		sleeve.position = Vector3(0.49 * side, -0.54, -0.62)
		sleeve.rotation_degrees = Vector3(28.0, 0.0, -24.0 * side)
		cam.add_child(sleeve)
		var hand := MeshInstance3D.new()
		var palm := SphereMesh.new()
		palm.radius = 0.105
		palm.height = 0.21
		hand.mesh = palm
		hand.material_override = skin
		hand.position = Vector3(0.39 * side, -0.37, -0.84)
		cam.add_child(hand)

func set_playing(enabled: bool) -> void:
	control_active = enabled
	if not enabled:
		touch_move = Vector2.ZERO
		filtered_touch_move = Vector2.ZERO
		look_touch_index = -1
	if OS.has_feature("mobile"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if enabled else Input.MOUSE_MODE_VISIBLE

func set_touch_move(value: Vector2) -> void:
    # Use a consistent dead-zone; the physics loop smooths movement independent of FPS.
    touch_move = value.limit_length(1.0) if value.length() >= 0.10 else Vector2.ZERO

func request_jump() -> void:
	jump_requested = true

func set_package(yes: bool) -> void:
	held_package.visible = yes

func _input(event: InputEvent) -> void:
	if not control_active:
		look_touch_index = -1
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		look(event.relative, MOUSE_SENS * look_sensitivity)
	elif event is InputEventScreenTouch:
		var view_size := get_viewport().get_visible_rect().size
		if event.pressed and look_touch_index == -1:
			# The entire left-hand region belongs to move; top-right panels + bottom
			# button strip are reserved for UI. A second finger can look while moving.
			if event.position.x > view_size.x * 0.52 and event.position.y > view_size.y * 0.17 and event.position.y < view_size.y * 0.82 and not (event.position.x > view_size.x * 0.75 and event.position.y > view_size.y * 0.60):
				look_touch_index = event.index
		elif not event.pressed and event.index == look_touch_index:
			look_touch_index = -1
	elif event is InputEventScreenDrag and event.index == look_touch_index:
		look(event.relative, 0.0030 * look_sensitivity)

func look(relative: Vector2, sensitivity: float) -> void:
	rotate_y(-relative.x * sensitivity)
	head.rotate_x(-relative.y * sensitivity)
	head.rotation.x = clampf(head.rotation.x, -1.35, 1.35)

func _physics_process(delta: float) -> void:
	if not control_active:
		velocity.x = move_toward(velocity.x, 0.0, ACCELERATION * delta)
		velocity.z = move_toward(velocity.z, 0.0, ACCELERATION * delta)
		if not is_on_floor():
			velocity.y -= GRAVITY * delta
		move_and_slide()
		return
	
	# Smooth the joystick input (also on diagonals), but release quickly.
	var response: float = BRAKING if touch_move.length() < 0.10 else ACCELERATION
	filtered_touch_move = filtered_touch_move.move_toward(touch_move, response * delta * 0.32)
	var d := filtered_touch_move
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): d.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): d.y += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): d.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): d.x += 1.0
	d = d.limit_length()
	# Camera-relative 360-degree locomotion (diagonals have normalized speed).
	# Screen-stick +Y is backwards and -Y is forwards, in both orientations.
	var direction := (global_transform.basis * Vector3(d.x, 0.0, d.y)).limit_length()
	var running := run_toggle or Input.is_key_pressed(KEY_SHIFT)
	var speed := (RUN_SPEED if running else WALK_SPEED) * (1.35 if has_scooter else 1.0) * fatigue_factor
	velocity.x = move_toward(velocity.x, direction.x * speed, ACCELERATION * delta)
	velocity.z = move_toward(velocity.z, direction.z * speed, ACCELERATION * delta)
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	elif Input.is_key_pressed(KEY_SPACE) or jump_requested:
		velocity.y = JUMP_VELOCITY
	jump_requested = false
	move_and_slide()
	
	var moving := d.length() > 0.1 and is_on_floor()
	if moving:
		bob_clock += delta * (13.0 if running else 9.5)
		cam.position.y = sin(bob_clock) * 0.028
		step_timer -= delta
		if step_timer <= 0.0:
			footstep_player.pitch_scale = randf_range(0.9, 1.1)
			footstep_player.play()
			step_timer = 0.34 if running else 0.48
	else:
		cam.position.y = move_toward(cam.position.y, 0.0, delta * 0.18)
		step_timer = 0.04
	if held_package.visible:
		held_package.position.y = -0.70 + sin(bob_clock) * 0.012
