extends Node3D
class_name RiseCity

# A complete code-built neighborhood. All geometries/materials are original,
# and no third-party textures or copyrighted art are required to open the project.
const POINTS := [
	{"id":"depot", "title":"THE DEPOT", "position":Vector3(-23, 0, -20), "building":Vector3(-23, 0, -31), "color":"f5af59"},
	{"id":"cafe", "title":"CAFE TWENTY4", "position":Vector3(23, 0, -20), "building":Vector3(23, 0, -31), "color":"f58c83"},
	{"id":"market", "title":"MINI MARKET", "position":Vector3(-23, 0, 20), "building":Vector3(-23, 0, 31), "color":"52d6c6"},
	{"id":"agency", "title":"BUSINESS HUB", "position":Vector3(23, 0, 20), "building":Vector3(23, 0, 31), "color":"84bdfa"},
]
var palette: Dictionary = {}
var cars: Array[Node3D] = []
var spinning_markers: Array[Node3D] = []
var walkers: Array[Dictionary] = []
var world_time := 0.0
var city_sun: DirectionalLight3D
var city_environment: WorldEnvironment

func _ready() -> void:
	materials()
	atmosphere()
	streets()
	for i in range(POINTS.size()):
		var p: Dictionary = POINTS[i]
		make_shop(p, i)
	build_skyline()
	build_props()

func material(hex: String, metallic: float = 0.0, rough: float = 0.78, emission: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color.html(hex)
	m.metallic = metallic
	m.roughness = rough
	if emission:
		m.emission_enabled = true
		m.emission = Color.html(hex)
		m.emission_energy_multiplier = 0.9
	return m

# Deterministic low-cost surface textures. Every pixel is generated here; no external assets.
func surface_texture(kind: String, texture_seed: int) -> ImageTexture:
	var img := Image.create_empty(96, 96, false, Image.FORMAT_RGBA8)
	var noise := RandomNumberGenerator.new()
	noise.seed = texture_seed
	for y in range(96):
		for x in range(96):
			var grain := noise.randf_range(-0.095, 0.095)
			var strength := 0.91 + grain
			if kind == "pavement":
				if x % 32 < 2 or y % 32 < 2: strength -= 0.24
			elif kind == "brick":
				var offset := 24 if int(y / 16) % 2 == 1 else 0
				if y % 16 < 2 or (x + offset) % 48 < 2: strength -= 0.29
			elif kind == "asphalt":
				strength += noise.randf_range(-0.13, 0.12)
			elif kind == "grass":
				if noise.randf() > 0.92: strength += 0.18
			img.set_pixel(x, y, Color(clampf(strength, 0.24, 1.0), clampf(strength, 0.24, 1.0), clampf(strength, 0.24, 1.0), 1.0))
	return ImageTexture.create_from_image(img)

func apply_surface(name: String, kind: String, texture_seed: int, repeat_count: float) -> void:
	var m: StandardMaterial3D = palette[name]
	m.albedo_texture = surface_texture(kind, texture_seed)
	m.uv1_scale = Vector3(repeat_count, repeat_count, 1.0)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

func materials() -> void:
	palette = {
		"asphalt": material("2c3949"), "sidewalk": material("75818a"),
		"concrete": material("c3b9ab"), "white": material("f1dfcb"),
		"dark": material("202f41", 0.14), "metal": material("677e8e", 0.7, 0.33),
		"glass": material("3c7791", 0.42, 0.12), "gold": material("f5b95b", 0.12, 0.48, true),
		"green": material("449475"), "tree": material("32694e"),
		"cream": material("e0d8c9"), "grass": material("57785d"),
		"stripe": material("f4eadc"), "brick": material("be7868"),
		"clay": material("d69d74"), "peach": material("f5af8a"),
		"blue": material("6da5bf"), "navy": material("43586f"),
		"black": material("1a2936"), "red": material("e77a6b"),
	}
	apply_surface("asphalt", "asphalt", 7423, 9.0)
	apply_surface("sidewalk", "pavement", 8315, 3.0)
	apply_surface("brick", "brick", 9571, 2.0)
	apply_surface("concrete", "stucco", 1462, 3.0)
	apply_surface("grass", "grass", 7428, 10.0)
	apply_surface("cream", "stucco", 5461, 2.0)

func box(parent: Node3D, pos: Vector3, dims: Vector3, mat: Material, solid: bool = false) -> MeshInstance3D:
	var mesh_node := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = dims
	mesh_node.mesh = shape
	mesh_node.material_override = mat
	mesh_node.position = pos
	parent.add_child(mesh_node)
	if solid:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 2
		body.position = pos
		parent.add_child(body)
		var col := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = dims
		col.shape = bs
		body.add_child(col)
	return mesh_node

func column(parent: Node3D, pos: Vector3, radius: float, height: float, mat: Material, sides: int = 10) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = sides
	node.mesh = mesh
	node.material_override = mat
	node.position = pos
	parent.add_child(node)
	return node

func sphere(parent: Node3D, pos: Vector3, scale_value: Vector3, mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radial_segments = 10
	mesh.rings = 5
	node.mesh = mesh
	node.material_override = mat
	node.position = pos
	node.scale = scale_value
	parent.add_child(node)
	return node

func atmosphere() -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("465e80")
	sky_mat.sky_horizon_color = Color("e5b18e")
	sky_mat.ground_bottom_color = Color("374456")
	sky_mat.ground_horizon_color = Color("d0a48a")
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_BG
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color("b1adab")
	env.fog_density = 0.006
	environment.environment = env
	city_environment = environment
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42.0, -38.0, 0.0)
	sun.light_color = Color("ffe1b6")
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 75
	city_sun = sun
	add_child(sun)

func streets() -> void:
	box(self, Vector3(0, -0.6, 0), Vector3(220, 1, 220), palette["grass"], true)
	# Pedestrian roads and two crossing avenues.
	box(self, Vector3(0, -0.075, 0), Vector3(220, 0.13, 15), palette["asphalt"])
	box(self, Vector3(0, -0.06, 0), Vector3(15, 0.13, 220), palette["asphalt"])
	box(self, Vector3(0, -0.025, 0), Vector3(27, 0.055, 27), palette["concrete"])
	box(self, Vector3(0, -0.005, 0), Vector3(23, 0.025, 23), palette["sidewalk"])
	for i in range(-9, 10):
		if abs(i) < 2: continue
		box(self, Vector3(i * 10, 0.01, 0), Vector3(4.0, 0.012, 0.24), palette["stripe"])
		box(self, Vector3(0, 0.01, i * 10), Vector3(0.24, 0.012, 4.0), palette["stripe"])
	for x in [-47.0, -16.0, 16.0, 47.0]:
		for z in [-53.0, 53.0]:
			box(self, Vector3(x, 0.01, z), Vector3(22.0, 0.18, 8), palette["concrete"])
	for z in [-39.0, 39.0]:
		for x in [-55.0, 55.0]:
			box(self, Vector3(x, 0.01, z), Vector3(7.0, 0.18, 24.0), palette["concrete"])
	for z in [-10.5, 10.5]:
		for x in [-9.0, -7.6, -6.2, -4.8, 4.8, 6.2, 7.6, 9.0]:
			box(self, Vector3(x, 0.047, z), Vector3(0.8, 0.012, 2.1), palette["stripe"])
	for x in [-10.5, 10.5]:
		for z in [-9.0, -7.6, -6.2, -4.8, 4.8, 6.2, 7.6, 9.0]:
			box(self, Vector3(x, 0.047, z), Vector3(2.1, 0.012, 0.8), palette["stripe"])
	# Signature sculpture in center of city.
	column(self, Vector3(0, 0.3, 0), 2.3, 0.6, palette["concrete"], 20)
	column(self, Vector3(0, 1.3, 0), 0.33, 1.8, palette["metal"], 14)
	sphere(self, Vector3(0, 2.55, 0), Vector3(1.0, 1.0, 1.0), palette["gold"])
	box(self, Vector3(0, 0.63, 0), Vector3(1.8, 0.24, 1.8), palette["dark"])

func sign(parent: Node3D, txt: String, pos: Vector3, flip: bool = false, scale3d: float = 0.007) -> void:
	var lb := Label3D.new()
	lb.text = txt
	lb.font_size = 64
	lb.pixel_size = scale3d
	lb.outline_size = 6
	lb.modulate = Color("fff0d6")
	lb.position = pos
	lb.rotation.y = PI if flip else 0.0
	parent.add_child(lb)

func make_shop(point: Dictionary, idx: int) -> void:
	var root := Node3D.new()
	root.position = point["building"]
	add_child(root)
	var back := (idx > 1)
	var front_z := -7.0 if back else 7.0
	var accent := material(point["color"], 0.1, 0.46, true)
	var wall_mat: Material = [palette["clay"], palette["brick"], palette["blue"], palette["navy"]][idx]
	box(root, Vector3(0, 3.1, 0), Vector3(15.5, 6.2, 14), wall_mat, true)
	box(root, Vector3(0, 6.4, 0), Vector3(16.7, 0.42, 15.2), palette["dark"])
	box(root, Vector3(0, 5.2, front_z + (0.1 if not back else -0.1)), Vector3(14.0, 1.3, 0.24), palette["dark"])
	box(root, Vector3(0, 4.51, front_z + (0.21 if not back else -0.21)), Vector3(11.8, 0.085, 0.12), accent)
	var pane_z := front_z + (0.085 if not back else -0.085)
	for x in [-5.0, -2.6, 2.6, 5.0]:
		box(root, Vector3(x, 2.5, pane_z), Vector3(1.85, 3.0, 0.1), palette["glass"])
		box(root, Vector3(x, 2.5, pane_z + (0.075 if not back else -0.075)), Vector3(0.06, 3.2, 0.08), palette["metal"])
	box(root, Vector3(0, 1.75, pane_z), Vector3(2.35, 3.6, 0.12), palette["dark"])
	box(root, Vector3(0, 1.95, pane_z + (0.075 if not back else -0.075)), Vector3(1.9, 3.0, 0.075), palette["glass"])
	box(root, Vector3(0, 0.13, pane_z + (0.3 if not back else -0.3)), Vector3(3.1, 0.18, 1.0), palette["sidewalk"])
	for x in [-7.0, 7.0]:
		box(root, Vector3(x, 2.5, pane_z), Vector3(0.22, 5.3, 0.35), palette["cream"])
	for x in [-4.3, 4.3]:
		column(root, Vector3(x, 6.75, 0), 0.43, 0.65, accent, 8)
	# Built-in label is geometry inside the world, not a flat screenshot.
	sign(root, point["title"], Vector3(0, 5.4, pane_z + (0.25 if not back else -0.25)), back, 0.0065)
	# Floor signs, interaction light and tactile colored floor tile.
	var tile_pos: Vector3 = point["position"]
	box(self, tile_pos + Vector3(0, 0.02, 0), Vector3(4.8, 0.06, 3.9), palette["sidewalk"])
	column(self, tile_pos + Vector3(0, 0.08, 0), 1.0, 0.12, accent, 24)
	var interact_beacon := Node3D.new()
	interact_beacon.position = tile_pos + Vector3(0, 2.65, 0)
	add_child(interact_beacon)
	var b := sphere(interact_beacon, Vector3.ZERO, Vector3(0.36, 0.36, 0.36), accent)
	b.rotation.z = PI * 0.25
	spinning_markers.append(interact_beacon)
	# Store-specific exterior props.
	if idx == 0:
		for i in range(3):
			box(self, tile_pos + Vector3(-6.0 + i*1.1, 0.48, -1.7), Vector3(1.0, 0.95, 1.0), palette["clay"])
	elif idx == 1:
		for s in [-1, 1]:
			column(self, tile_pos + Vector3(s*5.4, 0.63, 2.1), 0.65, 0.16, palette["white"])
			column(self, tile_pos + Vector3(s*5.4, 0.26, 2.1), 0.1, 0.5, palette["metal"])
	elif idx == 2:
		for i in range(3):
			box(self, tile_pos + Vector3(-5.5 + 1.25*i, 0.45, 1.4), Vector3(0.9, 0.9, 0.9), palette["green"])
	else:
		box(self, tile_pos + Vector3(5.9, 1.8, 0), Vector3(1.9, 3.6, 0.4), palette["black"])

func build_skyline() -> void:
	var skyline_fronts: Array[Transform3D] = []
	var skyline_sides: Array[Transform3D] = []
	var seeded := RandomNumberGenerator.new()
	seeded.seed = 245104
	for i in range(37):
		var angle: float = TAU * float(i) / 37.0
		var radius: float = seeded.randf_range(78.0, 105.0)
		var x: float = cos(angle) * radius
		var z: float = sin(angle) * radius
		if abs(x) < 19.0 or abs(z) < 19.0: continue
		var height: float = seeded.randf_range(13.0, 39.0)
		var width: float = seeded.randf_range(9.0, 18.0)
		var depth: float = seeded.randf_range(8.0, 17.0)
		var cl: Material = [palette["cream"], palette["navy"], palette["brick"], palette["blue"], palette["concrete"]][i % 5]
		box(self, Vector3(x, height*0.5, z), Vector3(width, height, depth), cl, true)
		box(self, Vector3(x, height + 0.2, z), Vector3(width+0.6, 0.35, depth+0.6), palette["dark"])
		var floors := int(height / 3.0)
		for f in range(1, floors):
			for side in [-1.0, 1.0]:
				for bx in [-0.32, 0.0, 0.32]:
					skyline_fronts.append(Transform3D(Basis(), Vector3(x+width*bx, f*3.05+1.1, z+depth*0.505*side)))
		for f in range(1, floors):
			for side in [-1.0, 1.0]:
				skyline_sides.append(Transform3D(Basis(), Vector3(x+width*0.505*side, f*3.05+1.1, z)))
	# Batch the skyline glass into just TWO draw calls instead of hundreds.
	window_batch(skyline_fronts, Vector3(1.35, 1.45, 0.08))
	window_batch(skyline_sides, Vector3(0.08, 1.45, 2.3))
	# Nearby color-coordinated apartments; a different façade from the 4 shops.
	for x in [-49.0, 49.0]:
		for z in [-35.0, 35.0]:
			var height := 17.0 if x < 0 else 21.0
			box(self, Vector3(x, height*0.5, z), Vector3(15.0, height, 14.0), palette["cream"] if z < 0 else palette["navy"], true)
			for floor_i in range(1, int(height/3.2)):
				for win_x in [-5.0, -1.7, 1.7, 5.0]:
					box(self, Vector3(x+win_x, floor_i*3.2+0.85, z+7.06), Vector3(1.55, 1.8, 0.1), palette["glass"])
			box(self, Vector3(x, height+0.18, z), Vector3(15.4, 0.35, 14.4), palette["dark"])


func window_batch(transforms: Array[Transform3D], size3d: Vector3) -> void:
	if transforms.is_empty(): return
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	var shape := BoxMesh.new()
	shape.size = size3d
	batch.mesh = shape
	batch.instance_count = transforms.size()
	for i in range(transforms.size()):
		batch.set_instance_transform(i, transforms[i])
	var node := MultiMeshInstance3D.new()
	node.multimesh = batch
	node.material_override = palette["glass"]
	add_child(node)

func pedestrian(pos: Vector3, outfit: Material, index: int) -> void:
	var person := Node3D.new()
	person.position = pos
	add_child(person)
	box(person, Vector3(0, 1.17, 0), Vector3(0.64, 1.03, 0.35), outfit)
	column(person, Vector3(0, 0.48, 0), 0.23, 0.22, palette["dark"], 8)
	sphere(person, Vector3(0, 1.97, 0), Vector3(0.31, 0.35, 0.3), palette["clay"])
	box(person, Vector3(0, 2.28, 0), Vector3(0.56, 0.14, 0.54), palette["dark"])
	var limb_nodes: Array[Node3D] = []
	for side in [-1.0, 1.0]:
		var arm := Node3D.new()
		arm.position = Vector3(side*0.42, 1.59, 0)
		person.add_child(arm)
		box(arm, Vector3(0,-0.37,0), Vector3(0.18, 0.72, 0.22), outfit)
		limb_nodes.append(arm)
		var leg := Node3D.new()
		leg.position = Vector3(side*0.18, 0.76, 0)
		person.add_child(leg)
		box(leg, Vector3(0,-0.35,0), Vector3(0.22, 0.73, 0.23), palette["navy"])
		box(leg, Vector3(0,-0.68,-0.09), Vector3(0.27, 0.14, 0.35), palette["black"])
		limb_nodes.append(leg)
	walkers.append({"node": person, "origin": pos, "limbs": limb_nodes, "phase": float(index)*1.3, "axis": index%2})

func tree(pos: Vector3, variation: int = 0) -> void:
	column(self, pos + Vector3(0, 1.38, 0), 0.24, 2.75, palette["clay"], 9)
	sphere(self, pos + Vector3(0, 3.6, 0), Vector3(1.65, 1.4, 1.65), palette["tree"])
	sphere(self, pos + Vector3(-0.73, 3.04, 0.36), Vector3(0.95, 0.93, 0.9), palette["green"])
	sphere(self, pos + Vector3(0.7, 3.19, -0.23), Vector3(1.0, 0.91, 0.98), palette["tree"])

func streetlight(pos: Vector3) -> void:
	column(self, pos + Vector3(0, 2.9, 0), 0.11, 5.8, palette["metal"], 9)
	box(self, pos + Vector3(0.61, 5.7, 0), Vector3(1.3, 0.12, 0.14), palette["metal"])
	box(self, pos + Vector3(1.13, 5.58, 0), Vector3(0.8, 0.17, 0.5), palette["gold"])
	var lt := OmniLight3D.new()
	lt.position = pos + Vector3(1.13, 5.4, 0)
	lt.light_color = Color("ffba7c")
	lt.light_energy = 1.0
	lt.omni_range = 9.0
	lt.shadow_enabled = false
	add_child(lt)

func trash_can(pos: Vector3) -> void:
	column(self, pos + Vector3(0, 0.55, 0), 0.39, 1.1, palette["metal"], 10)
	column(self, pos + Vector3(0, 1.12, 0), 0.44, 0.10, palette["dark"], 10)

func bench(pos: Vector3) -> void:
	box(self, pos + Vector3(0, 0.46, 0), Vector3(2.4, 0.21, 0.8), palette["clay"])
	box(self, pos + Vector3(0, 0.95, 0.33), Vector3(2.4, 0.9, 0.16), palette["clay"])
	for x in [-0.9,0.9]:
		box(self, pos+Vector3(x, 0.25, 0), Vector3(0.16, 0.5, 0.7), palette["black"])

func car(pos: Vector3, shade: Material) -> void:
	var root := Node3D.new()
	root.position = pos
	add_child(root)
	box(root, Vector3(0, 0.67, 0), Vector3(3.9, 0.78, 1.85), shade)
	box(root, Vector3(-0.18, 1.26, 0), Vector3(2.1, 0.74, 1.65), palette["glass"])
	for x in [-1.27, 1.2]:
		for z in [-0.88, 0.88]:
			var wheel := column(root, Vector3(x, 0.32, z), 0.35, 0.26, palette["black"], 12)
			wheel.rotation.x = PI / 2.0
	for z in [-0.6, 0.6]:
		box(root, Vector3(1.99, 0.66, z), Vector3(0.08, 0.21, 0.25), palette["gold"])
	cars.append(root)

func build_props() -> void:
	for x in [-15.0, 15.0]:
		for z in [-15.0, 15.0]:
			tree(Vector3(x, 0, z))
	for x in [-64.0, -45.0, 45.0, 64.0]:
		for z in [-13.0, 13.0]:
			tree(Vector3(x, 0, z))
	for x in [-12.5, 12.5]:
		for z in [-48.0, 48.0]:
			tree(Vector3(x, 0, z))
	for v in [-50.0, -14.0, 14.0, 50.0]:
		streetlight(Vector3(v, 0, -10.7))
		streetlight(Vector3(v, 0, 10.7))
	trash_can(Vector3(8, 0, 12))
	trash_can(Vector3(-8, 0, -12))
	bench(Vector3(-6.5, 0, -11.0))
	bench(Vector3(6.5, 0, 11.0))
	car(Vector3(-55, 0, 5.8), palette["red"])
	car(Vector3(73, 0, -5.8), palette["peach"])
	# Lively pedestrians turn the neighborhood into a place, not an empty level.
	var outfits := [palette["peach"],palette["green"],palette["blue"],palette["clay"],palette["red"]]
	var locations := [Vector3(-18,0,-12),Vector3(18,0,-12),Vector3(-19,0,12),Vector3(18,0,12),Vector3(-8,0,17),Vector3(8,0,-17)]
	for i in range(locations.size()):
		pedestrian(locations[i], outfits[i % outfits.size()], i)
	# A stylized delivery motorbike by the depot.
	var m := Node3D.new()
	m.position = Vector3(-28.3, 0, -19.0)
	add_child(m)
	box(m, Vector3(0,0.92,0), Vector3(1.45,0.34,0.56), palette["peach"])
	column(m, Vector3(-0.55,0.4,0), 0.39,0.25,palette["black"])
	column(m, Vector3(0.55,0.4,0), 0.39,0.25,palette["black"])
	box(m, Vector3(0.31,1.18,0), Vector3(0.5,0.13,0.63), palette["dark"])

# Quality presets use one master sun and one environment: no expensive extra viewports.
func configure_graphics(high_quality: bool) -> void:
	if city_sun != null:
		city_sun.shadow_enabled = high_quality
	if city_environment != null and city_environment.environment != null:
		city_environment.environment.fog_enabled = high_quality

func _process(delta: float) -> void:
	world_time += delta
	for index in range(cars.size()):
		var vehicle: Node3D = cars[index]
		var direction := 1.0 if index == 0 else -1.0
		vehicle.position.x += delta * direction * (6.0 if index == 0 else 4.5)
		if vehicle.position.x > 104.0: vehicle.position.x = -104.0
		if vehicle.position.x < -104.0: vehicle.position.x = 104.0
	for walker in walkers:
		var person: Node3D = walker["node"]
		var phase: float = walker["phase"]
		var oscillation := sin(world_time*0.57 + phase)
		var pos: Vector3 = walker["origin"]
		if walker["axis"] == 0:
			person.position = pos + Vector3(oscillation*3.0, 0, 0)
		else:
			person.position = pos + Vector3(0, 0, oscillation*3.0)
		if walker["axis"] == 0:
			person.rotation.y = PI * 0.5 if cos(world_time * 0.57 + phase) > 0 else -PI * 0.5
		else:
			person.rotation.y = PI if cos(world_time * 0.57 + phase) > 0 else 0.0
		var limbs: Array = walker["limbs"]
		for n in range(limbs.size()):
			var limb: Node3D = limbs[n]
			limb.rotation.x = sin(world_time*4.0 + phase + (PI if n>=2 else 0.0))*(0.31 if n%2==0 else -0.34)
	for i in range(spinning_markers.size()):
		var beacon: Node3D = spinning_markers[i]
		beacon.rotation.y += delta * 0.65
		beacon.position.y = 2.65 + sin(world_time * 2.25 + i) * 0.15
