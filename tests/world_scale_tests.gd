extends SceneTree

func _initialize() -> void:
    call_deferred("verify_world")

func check(ok: bool, label: String) -> bool:
    if ok: return true
    push_error("WORLD QA FAILED: " + label)
    quit(1)
    return false

func verify_world() -> void:
    var world := RiseCity.new()
    root.add_child(world)
    await process_frame
    for npc_name in ["بائع_الشحن","بائع_القهوة","موظفة_السوبرماركت","صاحب_المشاريع","مارة"]:
        var actor := world.get_node_or_null(npc_name) as Node3D
        if not check(actor != null, "NPC missing: " + npc_name): return
        var height: float = float(actor.get_meta("scaled_height", 0.0))
        if not check(height > 1.60 and height < 1.90, "NPC too small / large: %s, height=%.2fm" % [npc_name,height]): return
    for vendor_name in ["بائع_الشحن","بائع_القهوة","موظفة_السوبرماركت","صاحب_المشاريع"]:
        var staff := world.get_node(vendor_name) as Node3D
        if not check(staff.find_children("*", "StaticBody3D", true, false).size() >= 1,
                     "Vendor without collision: " + vendor_name): return
    if not check(world.cars.size() == 2, "Traffic should contain two active vehicles"): return
    print("WORLD NPC HEIGHT 1.6-1.9m + PHYSICAL VENDORS + TRAFFIC: PASS")
    quit(0)
