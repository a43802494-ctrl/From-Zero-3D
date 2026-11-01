extends Node3D
class_name RiseCity

# Curated neighborhood built with actual licensed Kenney 3D models (GLB) and
# a few simple collision-only/road surfaces. Run tools/fetch_models.py first.
const POINTS := [
    {"id":"depot", "title":"THE DEPOT", "position":Vector3(-23, 0, -20), "building":Vector3(-23, 0, -31), "color":"f6b967"},
    {"id":"cafe", "title":"CAFE TWENTY4", "position":Vector3(23, 0, -20), "building":Vector3(23, 0, -31), "color":"ffac8e"},
    {"id":"market", "title":"MINI MARKET", "position":Vector3(-23, 0, 20), "building":Vector3(-23, 0, 31), "color":"72dabb"},
    {"id":"agency", "title":"BUSINESS HUB", "position":Vector3(23, 0, 20), "building":Vector3(23, 0, 31), "color":"b0c7ff"},
]

var model_cache: Dictionary = {}
var palette: Dictionary = {}
var cars: Array[Dictionary] = []
var walkers: Array[Dictionary] = []
var city_sun: DirectionalLight3D
var city_environment: WorldEnvironment
var elapsed := 0.0

func _ready() -> void:
    setup_materials()
    setup_atmosphere()
    create_streets()
    make_district()
    add_street_details()
    spawn_city_life()

func surface(hex_value: String, rough: float = 0.94) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = Color.html(hex_value)
    m.roughness = rough
    return m

func setup_materials() -> void:
    palette = {
        "ground": surface("687a68"),
        "asphalt": surface("2d3239"),
        "pavement": surface("a5aaa3"),
        "kerb": surface("cbd0c8"),
        "line": surface("e9dfc5"),
        "accent": surface("f5b85c"),
    }
    for key in ["ground", "asphalt", "pavement"]:
        var img := Image.create_empty(96, 96, false, Image.FORMAT_RGBA8)
        var rng := RandomNumberGenerator.new()
        rng.seed = [994, 927, 113][["ground", "asphalt", "pavement"].find(key)]
        for y in range(96):
            for x in range(96):
                var grain := rng.randf_range(0.88, 1.09)
                if key == "pavement" and (x % 32 < 2 or y % 32 < 2): grain *= 0.72
                if key == "asphalt": grain *= rng.randf_range(0.9, 1.12)
                img.set_pixel(x, y, Color(grain, grain, grain))
        var mat: StandardMaterial3D = palette[key]
        mat.albedo_texture = ImageTexture.create_from_image(img)
        mat.uv1_scale = Vector3(12, 12, 1)
        mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

func box(parent: Node3D, center: Vector3, dimensions: Vector3, mat: Material, solid: bool = false) -> void:
    var mesh := MeshInstance3D.new()
    var b := BoxMesh.new()
    b.size = dimensions
    mesh.mesh = b
    mesh.material_override = mat
    mesh.position = center
    parent.add_child(mesh)
    if solid:
        invisible_collision(center, dimensions)

func invisible_collision(center: Vector3, size: Vector3) -> void:
    var body := StaticBody3D.new()
    body.collision_layer = 1
    body.collision_mask = 2
    body.position = center
    add_child(body)
    var shape := CollisionShape3D.new()
    var b := BoxShape3D.new()
    b.size = size
    shape.shape = b
    body.add_child(shape)

func load_asset(pack: String, identifier: String) -> PackedScene:
    var path := "res://assets/models/%s/%s.glb" % [pack, identifier]
    if not model_cache.has(path):
        if ResourceLoader.exists(path):
            model_cache[path] = load(path)
        else:
            push_warning("Missing model: " + path + ". Run python3 tools/fetch_models.py")
            return null
    return model_cache[path] as PackedScene

func bounds_for(node: Node3D) -> AABB:
    var bounds := AABB()
    var has_bounds := false
    for found in node.find_children("*", "MeshInstance3D", true, false):
        var mi := found as MeshInstance3D
        if mi.mesh == null: continue
        var transform_to_root := node.global_transform.affine_inverse() * mi.global_transform
        var b := mi.get_aabb()
        for xi in [b.position.x, b.end.x]:
            for yi in [b.position.y, b.end.y]:
                for zi in [b.position.z, b.end.z]:
                    var vertex := transform_to_root * Vector3(xi, yi, zi)
                    if has_bounds:
                        bounds = bounds.expand(vertex)
                    else:
                        bounds = AABB(vertex, Vector3.ZERO)
                        has_bounds = true
    return bounds

func model(pack: String, identifier: String, location: Vector3, target_width: float, heading: float = 0.0) -> Node3D:
    var prefab := load_asset(pack, identifier)
    if prefab == null: return Node3D.new()
    var holder := Node3D.new()
    holder.position = location
    holder.rotation.y = heading
    add_child(holder)
    var scene := prefab.instantiate() as Node3D
    if scene == null: return holder
    holder.add_child(scene)
    var b := bounds_for(scene)
    var raw_width := maxf(b.size.x, b.size.z)
    var scale_factor := target_width / maxf(raw_width, 0.01)
    scene.scale = Vector3.ONE * scale_factor
    scene.position = Vector3(-b.get_center().x * scale_factor, -b.position.y * scale_factor, -b.get_center().z * scale_factor)
    return holder

func setup_atmosphere() -> void:
    var world_environment := WorldEnvironment.new()
    var environment := Environment.new()
    var sky := Sky.new()
    var procedural := ProceduralSkyMaterial.new()
    procedural.sky_top_color = Color("6794bd")
    procedural.sky_horizon_color = Color("eecba8")
    procedural.ground_horizon_color = Color("adb6aa")
    sky.sky_material = procedural
    environment.background_mode = Environment.BG_SKY
    environment.sky = sky
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
    environment.reflected_light_source = Environment.REFLECTION_SOURCE_BG
    environment.ambient_light_energy = 0.85
    environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    environment.fog_enabled = true
    environment.fog_density = 0.005
    environment.fog_light_color = Color("bfc9c9")
    world_environment.environment = environment
    city_environment = world_environment
    add_child(world_environment)
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-47, -31, 0)
    sun.light_color = Color("ffdfb5")
    sun.light_energy = 1.25
    sun.shadow_enabled = true
    sun.directional_shadow_max_distance = 65
    city_sun = sun
    add_child(sun)

func create_streets() -> void:
    box(self, Vector3(0, -0.67, 0), Vector3(148, 1.3, 148), palette["ground"], true)
    box(self, Vector3(0, -0.02, 0), Vector3(148, 0.045, 16), palette["asphalt"])
    box(self, Vector3(0, -0.02, 0), Vector3(16, 0.045, 148), palette["asphalt"])
    for x in [-57.0,-33.0,-9.0,9.0,33.0,57.0]:
        if abs(x) < 10: continue
        for z in [-50.0,50.0]:
            box(self, Vector3(x, 0.05, z), Vector3(20, 0.12, 8), palette["pavement"])
    for z in [-51.0, -27.0, 27.0, 51.0]:
        for x in [-50.0,50.0]:
            box(self, Vector3(x, 0.07, z), Vector3(9, 0.13, 20), palette["pavement"])
    for i in range(-6,7):
        if i in [-1,0,1]: continue
        box(self, Vector3(i*10.0, 0.008, 0), Vector3(4.6, 0.009, 0.22), palette["line"])
        box(self, Vector3(0, 0.008, i*10.0), Vector3(0.22, 0.009, 4.6), palette["line"])
    for side in [-1.0,1.0]:
        for k in range(5):
            box(self, Vector3(side*10.0, 0.035, -4.0 + float(k)*2.0), Vector3(2.0, 0.008, 0.8), palette["line"])
            box(self, Vector3(-4.0 + float(k)*2.0, 0.035, side*10.0), Vector3(0.8, 0.008, 2.0), palette["line"])

func shop_label(txt: String, location: Vector3, color: String) -> void:
    var label3d := Label3D.new()
    label3d.text = txt
    label3d.font_size = 54
    label3d.pixel_size = 0.009
    label3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    label3d.modulate = Color.html(color)
    label3d.outline_size = 8
    label3d.position = location
    add_child(label3d)

func make_district() -> void:
    var shops := ["building-a", "building-b", "building-f", "building-i"]
    for index in range(POINTS.size()):
        var p: Dictionary = POINTS[index]
        model("city-kit-commercial", shops[index], p["building"], 16.5, 0.0 if index < 2 else PI)
        invisible_collision(p["building"] + Vector3(0, 5, 0), Vector3(13.5, 10, 10.5))
        shop_label(p["title"], p["position"] + Vector3(0, 4.4, 0), p["color"])
        model("city-kit-commercial", "detail-awning" if index % 2 == 0 else "detail-awning-wide", p["position"] + Vector3(0, 2.4, 0), 3.2, PI if index < 2 else 0)
    var commercial := ["building-c","building-d","building-e","building-g","building-h","building-j","building-k","building-l","building-m","building-n"]
    var index := 0
    for x in [-60.0,-42.0,42.0,60.0]:
        for z in [-59.0,-39.0,39.0,59.0]:
            var id: String = commercial[index % commercial.size()]
            model("city-kit-commercial", id, Vector3(x,0,z), 14.0, PI if z > 0 else 0.0)
            invisible_collision(Vector3(x, 6, z), Vector3(12,12,12))
            index += 1
    var homes := ["building-type-a","building-type-c","building-type-e","building-type-i","building-type-m","building-type-q"]
    for side in [-1.0,1.0]:
        for i in range(5):
            var name_id: String = homes[(i + (0 if side > 0 else 2)) % homes.size()]
            var pos := Vector3(side * 68, 0, -52.0 + i * 24.0)
            model("city-kit-suburban", name_id, pos, 10.5, PI/2 if side > 0 else -PI/2)

func add_street_details() -> void:
    for side in [-1.0,1.0]:
        for k in range(-3,4):
            if k == 0: continue
            var value := float(k)*17.0
            model("city-kit-roads", "light-curved", Vector3(side*10.5,0,value), 1.4, PI if side < 0 else 0)
            model("city-kit-suburban", "tree-large" if k%2==0 else "tree-small", Vector3(side*14.0,0,value+5), 5.0)
        model("city-kit-roads", "traffic-light", Vector3(side*9.3, 0, side*9.3), 1.9, PI * (0.5 if side > 0 else 1.5))
    var benches := [Vector3(-12,0,-20),Vector3(12,0,-20),Vector3(-12,0,25),Vector3(12,0,25)]
    for p in benches:
        model("nature-kit", "plant-bushlarge", p, 3.1)
    for idx in range(8):
        var p := Vector3(-12.5 + (idx%4)*8.5, 0, -12.5 if idx < 4 else 12.5)
        model("city-kit-suburban", "planter", p, 2.0)
    for point in POINTS:
        model("city-kit-roads", "dumpster", point["position"]+Vector3(5,0,4), 1.5)

func spawn_city_life() -> void:
    var car_ids := ["taxi", "sedan", "delivery", "van", "hatchback-sports", "suv", "truck"]
    for i in range(12):
        var x := -48.0 + float(i%6)*19.0
        var z := -5.4 if i < 6 else 5.4
        var car_node := model("car-kit", car_ids[i % car_ids.size()], Vector3(x,0,z), 3.2, 0 if i < 6 else PI)
        if i < 4:
            cars.append({"node":car_node,"start":car_node.position,"phase":float(i)*3.0,"direction":1.0 if i % 2==0 else -1.0})
    var people := ["character-male-a","character-male-b","character-male-c","character-female-a","character-female-b","character-female-c"]
    for i in range(12):
        var side := -1.0 if i%2 == 0 else 1.0
        var pos := Vector3(-43+float(i%6)*16.0, 0, side * (15.0 + float(i%3)*4))
        var npc := model("mini-characters", people[i%people.size()], pos, 0.95, PI/2)
        walkers.append({"node":npc,"origin":pos,"phase":float(i)*0.83,"axis":i%2})

func configure_graphics(high_quality: bool) -> void:
    if city_sun: city_sun.shadow_enabled = high_quality
    if city_environment and city_environment.environment:
        city_environment.environment.fog_enabled = high_quality

func _process(delta: float) -> void:
    elapsed += delta
    for car in cars:
        var n: Node3D = car["node"]
        var a: Vector3 = car["start"]
        n.position = a + Vector3(sin(elapsed*0.22 + car["phase"])*5.0, 0, 0)
    for npc in walkers:
        var actor: Node3D = npc["node"]
        var origin: Vector3 = npc["origin"]
        var t := elapsed*1.25 + float(npc["phase"])
        actor.position = origin + Vector3(sin(t)*2.5 if npc["axis"] == 0 else 0.0, 0.0, sin(t)*2.5 if npc["axis"] == 1 else 0.0)
        actor.rotation.y = PI/2 if cos(t) >= 0 else -PI/2
        actor.scale.y = 1.0 + sin(t*6.0)*0.022
