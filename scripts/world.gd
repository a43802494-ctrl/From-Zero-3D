extends Node3D
class_name RiseCity

# Curated neighborhood built with actual licensed Kenney 3D models (GLB) and
# a few simple collision-only/road surfaces. Run tools/fetch_models.py first.
const POINTS := [
    {"id":"depot", "title":"مكتب الشحن", "position":Vector3(-23, 0, -20), "building":Vector3(-23, 0, -31), "color":"f6b967"},
    {"id":"cafe", "title":"قهوة الحارة", "position":Vector3(23, 0, -20), "building":Vector3(23, 0, -31), "color":"ffac8e"},
    {"id":"market", "title":"سوبر ماركت", "position":Vector3(-23, 0, 20), "building":Vector3(-23, 0, 31), "color":"72dabb"},
    {"id":"agency", "title":"مكتب المشاريع", "position":Vector3(23, 0, 20), "building":Vector3(23, 0, 31), "color":"b0c7ff"},
]

var model_cache: Dictionary = {}
var palette: Dictionary = {}
var cars: Array[Dictionary] = []
var walkers: Array[Dictionary] = []
var city_sun: DirectionalLight3D
var city_environment: WorldEnvironment
var elapsed := 0.0
var fancy_materials: Dictionary = {}

func _ready() -> void:
    setup_materials()
    setup_atmosphere()
    create_streets()
    make_district()
    # Primary real-world buildings already have their own detailed architecture.
    add_street_details()
    spawn_city_life()
    spawn_animated_people()

func surface(hex_value: String, rough: float = 0.94) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = Color.html(hex_value)
    m.roughness = rough
    return m

func setup_materials() -> void:
    palette = {
        "ground": surface("637b65"),
        "asphalt": surface("292d34"),
        "pavement": surface("92938f"),
        "kerb": surface("b6b8ae"),
        "line": surface("e9dfc5"),
        "accent": surface("f5b85c"),
    }
    fancy_materials = {
        "plaster_cream": surface("a99a87",0.89),
        "plaster_sand": surface("8a8f83",0.9),
        "plaster_rust": surface("ae7d61",0.91),
        "concrete": surface("90938e",0.9),
        "dark_frame": surface("29363b",0.46),
        "aluminum": surface("536672",0.35),
        "glass": surface("244254",0.17),
        "warm_window": surface("c6a46d",0.24),
        "wood": surface("785038",0.78),
        "gold": surface("d6a65f",0.52),
        "brick": surface("8d6553",0.94),
        "shutter": surface("6a7776",0.72),
        "tile": surface("a3a99f",0.86),
    }
    (fancy_materials["glass"] as StandardMaterial3D).metallic=0.31
    (fancy_materials["aluminum"] as StandardMaterial3D).metallic=0.46
    # Tiled plaster, poured-concrete and brick albedo textures. This gives the
    # authored facades surface variation even on the GL-compatibility renderer.
    for material_name in ["plaster_cream", "plaster_sand", "plaster_rust", "brick", "concrete", "tile"]:
        var img2 := Image.create_empty(128, 128, false, Image.FORMAT_RGBA8)
        var random2 := RandomNumberGenerator.new()
        random2.seed = 100021 + material_name.hash()
        for cy in range(128):
            for cx in range(128):
                var speckle: float=random2.randf_range(0.91,1.07)
                if material_name == "brick":
                    var course: int=int(cy/19)
                    var stagger: int=16 if course%2==0 else 0
                    if cy%19 < 2 or (cx+stagger)%43 < 2:
                        speckle = 0.55
                    else:
                        speckle *= 1.0 + 0.04*sin(float(cx)*0.25)
                elif material_name == "concrete" or material_name == "tile":
                    if cx%42<2 or cy%42<2: speckle*=0.74
                img2.set_pixel(cx,cy,Color(speckle,speckle,speckle,1))
        var surface_mat: StandardMaterial3D=fancy_materials[material_name]
        surface_mat.albedo_texture=ImageTexture.create_from_image(img2)
        surface_mat.uv1_scale=Vector3(3.0,3.0,1.0)
        surface_mat.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
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

    # Prebaked neutral, tileable diffuse + normal maps; geometric sidewalk joins
    # now catch daylight without needing heavyweight shaders on Android.
    var texture_materials := {
        "asphalt": palette["asphalt"],
        "pavement": palette["pavement"],
        "concrete": fancy_materials["concrete"],
        "plaster": fancy_materials["plaster_cream"],
        "brick": fancy_materials["brick"],
    }
    for name in texture_materials.keys():
        var m: StandardMaterial3D = texture_materials[name]
        var albedo_path: String = "res://assets/textures/%s_albedo.png" % name
        var normal_path: String = "res://assets/textures/%s_normal.png" % name
        m.albedo_texture = load(albedo_path)
        m.normal_texture = load(normal_path)
        m.normal_enabled = true
        m.normal_scale = 0.6
        m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

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
    procedural.sky_top_color = Color("6e9ab8")
    procedural.sky_horizon_color = Color("ecd1a7")
    procedural.ground_horizon_color = Color("b1afa3")
    sky.sky_material = procedural
    environment.background_mode = Environment.BG_SKY
    environment.sky = sky
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
    environment.reflected_light_source = Environment.REFLECTION_SOURCE_BG
    environment.ambient_light_energy = 0.46
    environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    environment.fog_enabled = true
    environment.fog_density = 0.0016
    environment.fog_light_color = Color("bfc9c9")
    world_environment.environment = environment
    city_environment = world_environment
    add_child(world_environment)
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-47, -31, 0)
    sun.light_color = Color("ffe4c7")
    sun.light_energy = 0.96
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
    var arabic_world_font := SystemFont.new()
    arabic_world_font.font_names = PackedStringArray(["Noto Naskh Arabic", "Noto Sans Arabic", "sans-serif"])
    label3d.font = arabic_world_font
    label3d.font_size = 54
    label3d.pixel_size = 0.009
    label3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    label3d.modulate = Color.html(color)
    label3d.outline_size = 8
    label3d.position = location
    add_child(label3d)

func make_district() -> void:
    # Foreground is a carefully placed group of detailed architectural GLBs.
    # These originals are unbranded, CC0, textured and scaled by scene bounds.
    var buildings := ["architecture/apartment-block", "architecture/office-building", "architecture/supermarket", "architecture/office-building"]
    for index in range(POINTS.size()):
        var poi: Dictionary = POINTS[index]
        var locator: Vector3 = poi["building"]
        var model_id: String = buildings[index]
        var pack_and_name := model_id.split("/")
        model("realworld/"+pack_and_name[0],pack_and_name[1],locator,20.0 if index == 2 else 17.0, PI if index >= 2 else 0.0)
        invisible_collision(locator + Vector3(0,6,0), Vector3(14,12,11))
        shop_label(poi["title"],poi["position"]+Vector3(0,3.3,0),poi["color"])
        build_service_desk(poi, index)
    var residential := ["apartment-block","office-building","apartment-block"]
    for i in range(9):
        var x: float = [-57.0,-41.0,41.0,57.0][i%4]
        var z: float = [-59.0,-43.0,43.0,59.0][int(i/4)%4]
        model("realworld/architecture",residential[i%3],Vector3(x,0,z),14.0 if i%3==0 else 17.0, PI if z > 0 else 0.0)
        invisible_collision(Vector3(x,5.5,z),Vector3(11,11,11))

func build_service_desk(poi: Dictionary, index: int) -> void:
    # Physical street-side interaction counter and parcel, not a beam or stick.
    var p: Vector3=poi["position"]
    var kiosk := Node3D.new()
    kiosk.name="خدمة_"+str(poi["id"])
    kiosk.position=p+Vector3(0,0,2.1 if index<2 else -2.1)
    add_child(kiosk)
    var metal: Material=fancy_materials["aluminum"]
    box(kiosk,Vector3(0,0.54,0),Vector3(2.25,1.07,0.81),fancy_materials["wood"])
    box(kiosk,Vector3(0,1.13,0),Vector3(2.55,0.16,1.03),fancy_materials["concrete"])
    box(kiosk,Vector3(0,0.83,-0.45),Vector3(2.26,0.09,0.055),metal)
    for x in [-0.67,0.54]:
        var pack:=MeshInstance3D.new()
        var cube:=BoxMesh.new();cube.size=Vector3(0.43,0.26,0.39)
        pack.mesh=cube;pack.position=Vector3(x,1.35,-0.1)
        pack.material_override=fancy_materials["plaster_sand"]
        kiosk.add_child(pack)
    var sign := Label3D.new()
    sign.text = "استلام الطلبات" if index == 0 else "تسليم الطلب"
    sign.billboard=BaseMaterial3D.BILLBOARD_ENABLED
    sign.font_size=54; sign.pixel_size=0.007
    sign.font=SystemFont.new()
    sign.position=Vector3(0,2.02,0)
    sign.modulate=Color("ffe6ad")
    sign.outline_size=5
    kiosk.add_child(sign)

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
    # Detailed, unbranded vehicles at realistic dimensions (not toy cars).
    var ids: Array[String] = ["white-sedan","red-sedan","silver-hatchback","pickup"]
    var stops: Array[Vector3] = [
        Vector3(-46,0,-5.3), Vector3(-24,0,-5.3), Vector3(29,0,-5.3),
        Vector3(47,0,5.3), Vector3(15,0,5.3), Vector3(-36,0,5.3),
    ]
    for i in range(stops.size()):
        var anchor:=model("realworld/vehicles",ids[i%ids.size()],stops[i],4.35 if ids[i%ids.size()] != "pickup" else 5.2,PI if i>2 else 0.0)
        if i in [0,3]:
            cars.append({"node":anchor,"start":anchor.position,"phase":i*2.0,"direction":1.0})

# Architectural pass: actual commercial and residential GLB shells are given
# authored shopfront geometry (framed glazing, shutters, upper floors, fascia,
# balconies and clear pedestrian streets). Every visible feature is 3D.
func add_street_architecture() -> void:
    var frontage_labels := ["مكتب الشحن", "قهوة الحارة", "سوبر ماركت", "مكتب المشاريع"]
    var front_tones := ["plaster_cream", "plaster_rust", "plaster_sand", "plaster_cream"]
    for n in range(4):
        var point: Dictionary=POINTS[n]
        var center: Vector3=point["building"]
        var road_sign := -1.0 if center.z < 0 else 1.0
        var front_z := center.z - road_sign * 6.4
        create_shop_front(center.x,front_z,road_sign,frontage_labels[n],front_tones[n],n)
    for i in range(10):
        var x: float = [-60.0,-42.0,42.0,60.0][i%4]
        var z: float = [-59.0,-39.0,39.0,59.0][int(i/4)%4]
        add_residential_facade(Vector3(x,0,z),i)
    make_urban_furniture()

func create_shop_front(x: float, front_z: float, side: float, title: String, wall_name: String, index: int) -> void:
    var wall: Material=fancy_materials[wall_name]
    var shell := Node3D.new()
    shell.position=Vector3(x,0,front_z)
    add_child(shell)
    # On-screen facade is the inhabited ground-floor base of a real GLB building.
    box(shell,Vector3(0,4.55,0),Vector3(12.5,4.8,0.35),wall)
    box(shell,Vector3(0,0.38,0),Vector3(12.8,0.76,0.65),fancy_materials["brick"])
    for bay in range(-2,3):
        var bx := float(bay)*2.27
        box(shell,Vector3(bx,2.10,-side*0.20),Vector3(2.03,2.6,0.10),fancy_materials["dark_frame"])
        box(shell,Vector3(bx,2.1,-side*0.265),Vector3(1.81,2.34,0.06),fancy_materials["glass"])
        box(shell,Vector3(bx,2.03,-side*0.307),Vector3(0.045,2.30,0.036),fancy_materials["aluminum"])
        box(shell,Vector3(bx,2.78,-side*0.310),Vector3(1.82,0.05,0.035),fancy_materials["aluminum"])
    box(shell,Vector3(0,3.53,-side*0.38),Vector3(12.5,0.88,0.14),fancy_materials["dark_frame"])
    # Painted signage is a world-space 3D label; never painted on the screen HUD.
    var sign := Label3D.new()
    sign.text=title
    var sign_font := SystemFont.new()
    sign_font.font_names = PackedStringArray(["Noto Naskh Arabic", "Noto Sans Arabic", "sans-serif"])
    sign.font=sign_font
    sign.position=Vector3(0,3.56,-side*0.48)
    sign.font_size=64
    sign.pixel_size=0.0088
    sign.modulate=Color("f5e0bd")
    sign.outline_size=3
    sign.rotation.y=PI if side < 0 else 0.0
    shell.add_child(sign)
    box(shell,Vector3(0,3.07,-side*1.05),Vector3(12.3,0.14,1.48),fancy_materials["gold"])
    for f in range(2):
        var y:=5.15+float(f)*2.1
        box(shell,Vector3(0,y+0.85,0),Vector3(12.7,0.14,0.56),fancy_materials["concrete"])
        for window in range(4):
            var wx:float=(float(window)-1.5)*2.93
            box(shell,Vector3(wx,y,-side*0.215),Vector3(1.65,1.44,0.13),fancy_materials["dark_frame"])
            box(shell,Vector3(wx,y,-side*0.30),Vector3(1.42,1.20,0.06),fancy_materials["glass"])
            box(shell,Vector3(wx,y,-side*0.35),Vector3(0.047,1.2,0.044),fancy_materials["aluminum"])
            box(shell,Vector3(wx,y-0.9,-side*0.51),Vector3(2.2,0.1,0.55),fancy_materials["concrete"])
    box(shell,Vector3(0,7.67,0),Vector3(13.1,0.2,0.8),fancy_materials["plaster_cream"])
    # Trim, lamp, and door-specific street furniture.
    for col in [-5.9,5.9]:
        box(shell,Vector3(col,2.26,-side*0.54),Vector3(0.19,3.9,0.3),fancy_materials["aluminum"])
    if index%2==0:
        box(shell,Vector3(4.35,0.84,-side*1.25),Vector3(1.2,1.35,0.65),fancy_materials["wood"])

func add_residential_facade(center: Vector3, number: int) -> void:
    # Frontal balconies break the repetitive white-box silhouette of the asset pack.
    var side := -1.0 if center.z < 0 else 1.0
    var front := center.z-side*6.1
    var wall_material: Material=fancy_materials[["plaster_sand","plaster_cream","plaster_rust"][number%3]]
    box(self,Vector3(center.x,4.5,front),Vector3(9.65,8.1,0.38),wall_material)
    for level in range(3):
        var y:=1.8+float(level)*2.15
        for w in [-2.45,2.45]:
            box(self,Vector3(center.x+w,y,front-side*0.24),Vector3(1.63,1.6,0.11),fancy_materials["dark_frame"])
            box(self,Vector3(center.x+w,y,front-side*0.32),Vector3(1.41,1.37,0.07),fancy_materials["glass"])
            box(self,Vector3(center.x+w,y,front-side*0.36),Vector3(0.06,1.35,0.07),fancy_materials["aluminum"])
        box(self,Vector3(center.x,y-1.04,front-side*0.77),Vector3(8.5,0.16,1.05),fancy_materials["concrete"])
        for j in range(9):
            var bx:=center.x-3.9+float(j)*0.97
            box(self,Vector3(bx,y-0.69,front-side*1.25),Vector3(0.06,0.55,0.06),fancy_materials["dark_frame"])
        box(self,Vector3(center.x,y-0.42,front-side*1.25),Vector3(8.4,0.07,0.07),fancy_materials["dark_frame"])

func make_urban_furniture() -> void:
    # Pedestrian zebra crossings, diagonal parking bays, median strips.
    for road_side in [-1.0,1.0]:
        for index in range(9):
            var mark:=float(index-4)*1.35
            box(self,Vector3(mark,0.042,road_side*11.7),Vector3(0.78,0.018,4.1),palette["line"])
            box(self,Vector3(road_side*11.7,0.043,mark),Vector3(4.1,0.018,0.78),palette["line"])
    for i in range(18):
        var side:float= -1.0 if i%2==0 else 1.0
        var z:= -55.0+float(int(i/2))*12.0
        box(self,Vector3(side*8.2,0.05,z),Vector3(0.17,0.12,6.0),fancy_materials["concrete"])
    for i in range(9):
        var x:float=-54.0+float(i)*13.6
        box(self,Vector3(x,0.055,7.35),Vector3(6.0,0.018,0.14),palette["line"])

func spawn_animated_people() -> void:
    # Fully textured, skinned real-world human models with authored animation.
    var actors: Array[String] = ["sam-walk", "harper-walk", "maya-locomotion", "sam-walk", "harper-walk"]
    var positions: Array[Vector3] = [Vector3(-24,0,-19.0),Vector3(22,0,-19.0),Vector3(-24,0,19.0),Vector3(22,0,19.0),Vector3(0,0,17)]
    for i in range(actors.size()):
        var anchor:=model("realworld/people",actors[i],positions[i],0.78 if i==2 else 0.81,0.0)
        var all_players:=anchor.find_children("*","AnimationPlayer",true,false)
        if not all_players.is_empty():
            var animation_player:=all_players[0] as AnimationPlayer
            var clips:=animation_player.get_animation_list()
            if not clips.is_empty():
                var chosen: String = clips[0]
                for clip in clips:
                    var lower:=clip.to_lower()
                    if "idle" in lower or "relaxed" in lower:
                        chosen=clip
                        break
                animation_player.play(chosen)
                animation_player.speed_scale=0.9
        if i == 4:
            walkers.append({"node":anchor,"origin":positions[i],"phase":1.0,"axis":0})

func configure_graphics(high_quality: bool) -> void:
    if city_sun: city_sun.shadow_enabled = high_quality
    if city_environment and city_environment.environment:
        city_environment.environment.fog_enabled = high_quality

func _process(delta: float) -> void:
    elapsed += delta
    for car in cars:
        var n: Node3D = car["node"]
        var a: Vector3 = car["start"]
        n.position = a + Vector3(sin(elapsed*0.13 + car["phase"])*2.0, 0, 0)
    for npc in walkers:
        var actor: Node3D = npc["node"]
        var origin: Vector3 = npc["origin"]
        var t := elapsed*1.25 + float(npc["phase"])
        actor.position = origin + Vector3(sin(t)*2.5 if npc["axis"] == 0 else 0.0, 0.0, sin(t)*2.5 if npc["axis"] == 1 else 0.0)
        actor.rotation.y = PI/2 if cos(t) >= 0 else -PI/2
        actor.scale.y = 1.0
