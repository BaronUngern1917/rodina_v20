extends Node3D

var state := "menu"
var toilet_progress := 0
var targets_left := 5
var message_time := 0.0
var menu_open := true
var range_started := false
var door_unlocked := false
var toilet_exit_unlocked := false
var buryat_has_issued_weapon := false
var muzzle_time := 0.0

@onready var player: CharacterBody3D = $Player
@onready var camera: Camera3D = $Player/Head/Camera3D

var ui: CanvasLayer
var objective: Label
var prompt: Label
var message: Label
var ammo_label: Label
var health_bar: ProgressBar
var stamina_bar: ProgressBar
var toilet_panel: Panel
var toilet_bar: ProgressBar
var crosshair: Label
var menu: Panel
var shout_player: AudioStreamPlayer
var menu_music_player: AudioStreamPlayer
var fork_task_voice_player: AudioStreamPlayer
var fork_clean_player: AudioStreamPlayer

const TEXT_OUTLINE_COLOR := Color(0.03, 0.03, 0.03, 0.95)
const TEXT_OUTLINE_SIZE := 5

func _ready():
    add_to_group("game")
    make_environment()
    build_world()
    build_ui()
    setup_audio()
    player.process_mode = Node.PROCESS_MODE_DISABLED
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func make_environment():
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color("#71806b")
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color("#8d9987")
    env.ambient_light_energy = 0.65
    env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    $WorldEnvironment.environment = env

func mat(color: Color, roughness := 0.9):
    var m := StandardMaterial3D.new()
    m.albedo_color = color
    m.roughness = roughness
    return m

func mesh_box(parent: Node, pos: Vector3, size: Vector3, color: Color, collision := true):
    var n := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size
    n.mesh = mesh
    n.position = pos
    n.material_override = mat(color)
    parent.add_child(n)
    if collision:
        var body := StaticBody3D.new()
        body.position = pos
        var shape := CollisionShape3D.new()
        var bs := BoxShape3D.new()
        bs.size = size
        shape.shape = bs
        body.add_child(shape)
        parent.add_child(body)
    return n

func mesh_cylinder(parent: Node, pos: Vector3, radius: float, height: float, color: Color):
    var n := MeshInstance3D.new()
    var mesh := CylinderMesh.new()
    mesh.top_radius = radius
    mesh.bottom_radius = radius
    mesh.height = height
    n.mesh = mesh
    n.position = pos
    n.material_override = mat(color)
    parent.add_child(n)
    return n

func add_box_collider(parent: Node, pos: Vector3, size: Vector3):
    var body := StaticBody3D.new()
    body.position = pos
    var shape := CollisionShape3D.new()
    var box := BoxShape3D.new()
    box.size = size
    shape.shape = box
    body.add_child(shape)
    parent.add_child(body)

func create_door(parent: Node, name: String, pos: Vector3, width: float, color: Color, locked := false, action := "Открыть дверь", target := "yard", height := 3.0) -> StaticBody3D:
    # Door origin is the hinge/jamb, not the center of the panel.
    var door := StaticBody3D.new()
    door.name = name
    door.position = pos
    door.set_script(load("res://scripts/Door.gd"))
    door.action_text = action
    door.target_state = target
    door.locked = locked
    parent.add_child(door)

    var door_visual := load("res://assets/props/_door._old._wood.glb").instantiate() as Node3D
    door_visual.name = "DoorVisual"
    # The imported leaf is authored in centimeters and its hinge sits at x=-338.
    # Normalize its bounds to this opening while keeping the script's right-jamb pivot.
    var source_bounds := AABB(Vector3(-401.4499, -57.0523, -6.419769), Vector3(63.77362, 150.5001, 12.84376))
    door_visual.scale = Vector3(width / source_bounds.size.x, height / source_bounds.size.y, 0.18 / source_bounds.size.z)
    door_visual.position = Vector3(
        -source_bounds.end.x * door_visual.scale.x,
        -source_bounds.get_center().y * door_visual.scale.y,
        -source_bounds.get_center().z * door_visual.scale.z
    )
    door.add_child(door_visual)

    var cs := CollisionShape3D.new()
    cs.name = "CollisionShape3D"
    var bs := BoxShape3D.new()
    bs.size = Vector3(width, height, 0.18)
    cs.shape = bs
    cs.position = Vector3(-width * 0.5, 0, 0)
    door.add_child(cs)
    return door

func build_world():
    build_ground()
    build_fence()
    build_barracks()
    build_yard()
    build_armory()
    build_range()
    build_truck(Vector3(13, 0.55, -104))
    build_forest()

func build_ground():
    # Tile the supplied terrain over the existing safety floor.  The floor's
    # collision stays in Main.tscn, so the new visual surface cannot create holes.
    var terrain_scene := load("res://assets/props/low_poly_dirt_ground.glb") as PackedScene
    if terrain_scene == null:
        return
    var tile_spacing_x := 28.67
    var tile_scale_x := tile_spacing_x / 27.016
    var tile_spacing_z := 38.0
    var tile_scale_z := tile_spacing_z / 37.834
    for row in range(5):
        for column in range(3):
            var terrain := terrain_scene.instantiate() as Node3D
            terrain.name = "DirtGround_%02d_%02d" % [row, column]
            terrain.scale = Vector3(tile_scale_x, 1.0, tile_scale_z)
            terrain.position = Vector3((float(column) - 1.0) * tile_spacing_x + 0.797, -1.02, -101.0 + row * tile_spacing_z - 0.507)
            add_child(terrain)

func build_fence():
    var fence_scene: PackedScene = load("res://assets/props/wooden_fences__low_poly.glb") as PackedScene
    if fence_scene == null:
        return
    var fence: Node3D = Node3D.new()
    fence.name = "PerimeterFence"
    add_child(fence)

    var segment_length := 5.872
    var half_width := 42.5
    var front_z := 68.0
    var back_z := -118.0
    var horizontal_count: int = max(1, roundi((half_width * 2.0) / segment_length))
    var horizontal_spacing := (half_width * 2.0) / float(horizontal_count)
    for z in [back_z, front_z]:
        for index in range(horizontal_count):
            var center_x := -half_width + horizontal_spacing * (float(index) + 0.5)
            add_fence_segment(fence, fence_scene, Vector3(center_x, 0.0, z), 0.0, horizontal_spacing / segment_length)

    var side_length := front_z - back_z
    var side_count: int = max(1, roundi(side_length / segment_length))
    var side_spacing := side_length / float(side_count)
    for x in [-half_width, half_width]:
        for index in range(side_count):
            var center_z := back_z + side_spacing * (float(index) + 0.5)
            add_fence_segment(fence, fence_scene, Vector3(x, 0.0, center_z), PI * 0.5, side_spacing / segment_length)

func add_fence_segment(parent: Node3D, fence_scene: PackedScene, center: Vector3, yaw: float, segment_scale: float):
    var segment := Node3D.new()
    segment.position = center
    segment.rotation.y = yaw
    parent.add_child(segment)

    var visual := fence_scene.instantiate() as Node3D
    visual.name = "FenceVisual"
    visual.scale = Vector3(segment_scale, 1.0, 1.0)
    visual.position = Vector3(1.421 * segment_scale, 0.06, -0.001)
    segment.add_child(visual)

    var body := StaticBody3D.new()
    body.name = "FenceCollision"
    # The visual origin is offset by the imported mesh, but the collider is
    # centered on the corrected panel position above.
    body.position = Vector3(0.0, 0.971, 0.0)
    var shape := CollisionShape3D.new()
    var box := BoxShape3D.new()
    box.size = Vector3(segment_length_for_scale(segment_scale), 1.942, 0.16)
    shape.shape = box
    body.add_child(shape)
    segment.add_child(body)

func segment_length_for_scale(segment_scale: float) -> float:
    return 5.872 * segment_scale

func build_barracks():
    var b := Node3D.new()
    b.name = "Barracks"
    add_child(b)

    # Use the furnished full barracks at its authored proportions (about 6 x 9 m).
    # The original stretched shell and its hidden-but-active colliders are removed.
    var barracks_visual := load("res://assets/props/small_barracks.glb").instantiate() as Node3D
    barracks_visual.name = "BarracksFullModel"
    barracks_visual.scale = Vector3.ONE
    barracks_visual.position = Vector3(0, 0.06, 20.3)
    var built_in_door := barracks_visual.find_child("door_low_003", true, false)
    if built_in_door:
        built_in_door.visible = false
    var ground_disc := barracks_visual.find_child("Circle", true, false)
    if ground_disc:
        ground_disc.visible = false
    b.add_child(barracks_visual)

    # Wall colliders follow the model's ~5.7 x 9.4 m footprint. The south
    # doorway (at z ~= 16) remains a real opening for the interactive leaf.
    add_box_collider(b, Vector3(-1.68, 2.55, 16.03), Vector3(2.24, 5.1, 0.22))
    add_box_collider(b, Vector3(2.23, 2.55, 16.03), Vector3(1.14, 5.1, 0.22))
    add_box_collider(b, Vector3(-2.86, 2.55, 20.75), Vector3(0.22, 5.1, 9.2))
    add_box_collider(b, Vector3(2.86, 2.55, 20.75), Vector3(0.22, 5.1, 9.2))
    add_box_collider(b, Vector3(0, 2.55, 25.48), Vector3(5.72, 5.1, 0.22))

    # Four bunk-bed models replace the old box silhouettes.  Their footprints
    # leave the entrance, central aisle, and toilet doorway clear.
    var bunk_scene := load("res://assets/props/metal_bunkbeds.glb") as PackedScene
    if bunk_scene:
        for x in [-1.65, 1.65]:
            for z in [18.9, 21.0]:
                var bed := bunk_scene.instantiate() as Node3D
                bed.name = "BunkBed_%s_%s" % [str(x), str(z)]
                bed.scale = Vector3.ONE * 0.36
                bed.position = Vector3(x, 0.0, z)
                b.add_child(bed)
                var bed_body := StaticBody3D.new()
                bed_body.position = Vector3(x, 0.76, z)
                var bed_shape := CollisionShape3D.new()
                var bed_box := BoxShape3D.new()
                bed_box.size = Vector3(1.88, 1.53, 1.06)
                bed_shape.shape = bed_box
                bed_body.add_child(bed_shape)
                b.add_child(bed_body)

    # Local Soviet posters are mounted to the side wall and above the exterior
    # entrance without covering the toilet partition or the door opening.
    var poster_scene := load("res://assets/props/poster_from_soviet_union.glb") as PackedScene
    if poster_scene:
        var inside_poster := poster_scene.instantiate() as Node3D
        inside_poster.name = "BarracksInteriorPoster"
        inside_poster.scale = Vector3.ONE * 0.35
        inside_poster.position = Vector3(-2.72, 2.65, 19.7)
        inside_poster.rotation.y = PI * 0.5
        b.add_child(inside_poster)
        var outside_poster := poster_scene.instantiate() as Node3D
        outside_poster.name = "BarracksEntrancePoster"
        outside_poster.scale = Vector3.ONE * 0.30
        outside_poster.position = Vector3(-0.75, 3.0, 15.91)
        outside_poster.rotation.y = PI
        b.add_child(outside_poster)

    # Main exterior exit. It becomes usable only after the toilet sequence is finished.
    var yard_exit := create_door(b, "BarracksExitDoor", Vector3(1.65, 1.05, 16.03), 2.2, Color("#49382b"), true, "Выйти во двор", "yard", 2.1)
    yard_exit.action_text = "Выйти во двор"

    # Toilet blockout fits into the rear-right corner of the actual interior.
    var toilet_entry := create_door(b, "ToiletDoor", Vector3(2.5, 1.0, 22.85), 1.0, Color("#49382b"), true, "Открыть дверь в туалет", "toilet", 2.0)
    toilet_entry.action_text = "Открыть дверь в туалет"
    toilet_entry.auto_close_after_entry = true

    # Interior toilet partition and colliders, with its front doorway left clear.
    add_box_collider(b, Vector3(1.31, 1.2, 22.83), Vector3(0.38, 2.4, 0.12))
    add_box_collider(b, Vector3(2.62, 1.2, 22.83), Vector3(0.24, 2.4, 0.12))
    add_box_collider(b, Vector3(1.12, 1.2, 23.95), Vector3(0.12, 2.4, 2.3))
    add_box_collider(b, Vector3(2.74, 1.2, 23.95), Vector3(0.12, 2.4, 2.3))
    add_box_collider(b, Vector3(1.93, 1.2, 25.08), Vector3(1.74, 2.4, 0.12))

    # Senior soldier retains the same script and interaction in an open sightline.
    var officer := StaticBody3D.new()
    officer.name = "SeniorSoldier"
    officer.position = Vector3(-1.25, 0.95, 23.1)
    officer.set_script(load("res://scripts/Officer.gd"))
    add_child(officer)
    mesh_box(officer, Vector3.ZERO, Vector3(0.7, 1.9, 0.45), Color("#4d5948"), false)
    mesh_cylinder(officer, Vector3(0, 1.25, 0), 0.3, 0.45, Color("#a9846b"))
    var oc := CollisionShape3D.new()
    var os := CapsuleShape3D.new()
    os.radius = 0.32
    os.height = 1.9
    oc.shape = os
    officer.add_child(oc)

    # Light visual partition surfaces; the collider boxes above preserve the door gap.
    mesh_box(b, Vector3(1.31, 1.2, 22.83), Vector3(0.38, 2.4, 0.12), Color("#5b4939"), false)
    mesh_box(b, Vector3(2.63, 1.2, 22.83), Vector3(0.24, 2.4, 0.12), Color("#5b4939"), false)
    mesh_box(b, Vector3(1.12, 1.2, 23.95), Vector3(0.12, 2.4, 2.3), Color("#5b4939"), false)
    mesh_box(b, Vector3(2.74, 1.2, 23.95), Vector3(0.12, 2.4, 2.3), Color("#5b4939"), false)
    mesh_box(b, Vector3(1.93, 2.42, 23.95), Vector3(1.74, 0.12, 2.3), Color("#514238"), false)

    var toilet := StaticBody3D.new()
    toilet.name = "Toilet"
    toilet.position = Vector3(1.93, 0.0, 24.0)
    toilet.set_script(load("res://scripts/Toilet.gd"))
    add_child(toilet)
    var toilet_visual := (load("res://assets/props/dirty_toilet.glb") as PackedScene).instantiate() as Node3D
    toilet_visual.name = "ToiletVisual"
    toilet_visual.scale = Vector3.ONE * 0.1
    toilet.add_child(toilet_visual)
    var tc := CollisionShape3D.new()
    var ts := BoxShape3D.new()
    ts.size = Vector3(0.72, 0.9, 0.52)
    tc.shape = ts
    tc.position.y = 0.45
    toilet.add_child(tc)

    var paper_holder := (load("res://assets/props/retro_lowpoly_toilet_paper.glb") as PackedScene).instantiate() as Node3D
    paper_holder.name = "ToiletPaperHolder"
    paper_holder.position = Vector3(2.52, 1.3, 23.55)
    paper_holder.rotation.y = PI * 0.5
    b.add_child(paper_holder)

    # Kerose­ne lamp: warm local light with a crude metal base and glass body.
    var lamp := Node3D.new()
    lamp.name = "KeroseneLamp"
    lamp.position = Vector3(-0.6, 3.2, 20.5)
    b.add_child(lamp)
    mesh_cylinder(lamp, Vector3.ZERO, 0.28, 0.12, Color("#5a5040"))
    mesh_cylinder(lamp, Vector3(0, 0.22, 0), 0.16, 0.34, Color("#b7a66f"))
    mesh_cylinder(lamp, Vector3(0, 0.45, 0), 0.05, 0.12, Color("#30291f"))
    var lamp_light := OmniLight3D.new()
    lamp_light.name = "WarmFlame"
    lamp_light.position = Vector3(0, 0.35, 0)
    lamp_light.light_color = Color("#ffd28a")
    lamp_light.light_energy = 2.2
    lamp_light.omni_range = 7.5
    lamp.add_child(lamp_light)

    # The supplied fork is a local GLB and is only visible during the toilet task.
    var fork_visual := (load("res://assets/props/lowpoly_fork.glb") as PackedScene).instantiate() as Node3D
    fork_visual.name = "ForkVisual"
    fork_visual.scale = Vector3.ONE * 0.04
    fork_visual.rotation_degrees.x = -90.0
    $Player/Head/Camera3D/Fork.add_child(fork_visual)

func build_yard():
    var y := Node3D.new()
    y.name = "Yard"
    add_child(y)

    # Replace the outdoor box blockouts with a few local military tents.  They
    # remain off the central route and have simple solid footprints.
    var tent_scene := load("res://assets/props/tent.glb") as PackedScene
    if tent_scene:
        var tent_positions := [
            [Vector3(-25.5, 0.0, 4.0), 0.0],
            [Vector3(25.5, 0.0, 4.0), PI],
            [Vector3(-25.5, 0.0, -31.0), 0.0],
            [Vector3(25.5, 0.0, -31.0), PI]
        ]
        for index in range(tent_positions.size()):
            var tent_data: Array = tent_positions[index]
            var tent := tent_scene.instantiate() as Node3D
            tent.name = "CampTent_%02d" % (index + 1)
            # This FBX is exported in centimeters without a root unit scale.
            tent.scale = Vector3.ONE * 0.0055
            tent.position = tent_data[0]
            tent.rotation.y = float(tent_data[1])
            y.add_child(tent)
            var tent_body := StaticBody3D.new()
            tent_body.position = Vector3(tent_data[0].x, 0.78, tent_data[0].z)
            var tent_shape := CollisionShape3D.new()
            var tent_box := BoxShape3D.new()
            tent_box.size = Vector3(5.3, 1.56, 5.7)
            tent_shape.shape = tent_box
            tent_body.add_child(tent_shape)
            y.add_child(tent_body)

    mesh_cylinder(y, Vector3(-9, 2.5, 5), 0.05, 5.0, Color("#5b5a4c"))
    mesh_box(y, Vector3(-8.2, 4.1, 5), Vector3(1.7, 0.9, 0.06), Color("#9b2e2a"), false)

    # A single prop cluster beside the far storage shed, outside the clear route
    # from the barracks to the range. Its source GLB contains tires, barrels,
    # timber and crates in one deliberately compact salvage pile.
    var yard_props := load("res://assets/props/assets_pack_free_survivalpostapo.glb").instantiate() as Node3D
    yard_props.name = "StorageYardProps"
    yard_props.scale = Vector3.ONE * 0.72
    yard_props.position = Vector3(12, 0.82, -43) - Vector3(8.97, 0, -11.36) * yard_props.scale
    y.add_child(yard_props)
    var storage_collision := StaticBody3D.new()
    storage_collision.name = "StoragePropsCollision"
    storage_collision.position = Vector3(12.0, 0.8, -43.0)
    var storage_shape := CollisionShape3D.new()
    var storage_box := BoxShape3D.new()
    storage_box.size = Vector3(4.0, 1.6, 3.5)
    storage_shape.shape = storage_box
    storage_collision.add_child(storage_shape)
    y.add_child(storage_collision)

    # One battered timber divider gives the storage corner a clear edge.
    var divider_scene := load("res://assets/props/wooden_wall.glb") as PackedScene
    if divider_scene:
        var divider := divider_scene.instantiate() as Node3D
        divider.name = "StorageTimberDivider"
        # The imported panel origin is offset from its mesh center; compensate
        # for that after the 90-degree turn so its collider matches the wood.
        divider.position = Vector3(14.648, 0.82, -42.893)
        divider.rotation.y = PI * 0.5
        y.add_child(divider)
        var divider_body := StaticBody3D.new()
        divider_body.position = Vector3(15.5, 0.89, -43.0)
        divider_body.rotation.y = PI * 0.5
        var divider_shape := CollisionShape3D.new()
        var divider_box := BoxShape3D.new()
        divider_box.size = Vector3(2.9, 1.78, 0.14)
        divider_shape.shape = divider_box
        divider_body.add_child(divider_shape)
        y.add_child(divider_body)

func build_armory():
    var a := Node3D.new()
    a.name = "Armory"
    add_child(a)

    # The supplied ruined shop/house replaces the old box shell.  Its catalog
    # ground plane is hidden because the terrain is provided separately.
    var house_scene := load("res://assets/props/abandoned__building__shop__old__house.glb") as PackedScene
    if house_scene:
        var house := house_scene.instantiate() as Node3D
        house.name = "BuryatHouseVisual"
        house.scale = Vector3.ONE * 0.4
        house.position = Vector3(0.0, 0.0, -13.8)
        var house_ground := house.find_child("Plane", true, false) as Node3D
        if house_ground:
            house_ground.visible = false
        a.add_child(house)

    # Simple collision follows the new model's 8 x 5.6 m wall footprint and
    # leaves a 1.8 m opening on the side facing the approach from the yard.
    add_box_collider(a, Vector3(-2.55, 1.85, -11.0), Vector3(2.9, 3.7, 0.2))
    add_box_collider(a, Vector3(2.55, 1.85, -11.0), Vector3(2.9, 3.7, 0.2))
    add_box_collider(a, Vector3(0.0, 1.85, -16.6), Vector3(8.0, 3.7, 0.2))
    add_box_collider(a, Vector3(-4.0, 1.85, -13.8), Vector3(0.2, 3.7, 5.6))
    add_box_collider(a, Vector3(4.0, 1.85, -13.8), Vector3(0.2, 3.7, 5.6))

    # The entrance is on the +Z face that the player reaches from the yard.
    var armory_door := create_door(a, "ArmoryDoor", Vector3(0.9, 1.1, -10.88), 1.8, Color("#49382b"), false, "Открыть оружейную", "yard", 2.2)
    armory_door.action_text = "Открыть оружейную"

    # Keep the existing local armory photograph and hang it on the inside of the
    # new house's rear wall (the interior lies toward +Z from that wall).
    var arsenal_panel := MeshInstance3D.new()
    arsenal_panel.name = "ArsenalInteriorBackdrop"
    var arsenal_mesh := QuadMesh.new()
    arsenal_mesh.size = Vector2(7.2, 2.5)
    arsenal_panel.mesh = arsenal_mesh
    arsenal_panel.position = Vector3(0, 1.75, -16.48)
    var arsenal_mat := StandardMaterial3D.new()
    arsenal_mat.albedo_texture = load("res://assets/armory_wall.jpg") as Texture2D
    arsenal_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    arsenal_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    arsenal_mat.roughness = 1.0
    arsenal_panel.material_override = arsenal_mat
    a.add_child(arsenal_panel)

    # Keep the warm local light inside the new house.
    var armory_lamp := Node3D.new()
    armory_lamp.name = "KeroseneLamp"
    armory_lamp.position = Vector3(-3.0, 2.6, -13.2)
    a.add_child(armory_lamp)
    mesh_cylinder(armory_lamp, Vector3.ZERO, 0.28, 0.12, Color("#5a5040"))
    mesh_cylinder(armory_lamp, Vector3(0, 0.22, 0), 0.16, 0.34, Color("#b7a66f"))
    mesh_cylinder(armory_lamp, Vector3(0, 0.45, 0), 0.05, 0.12, Color("#30291f"))
    var armory_light := OmniLight3D.new()
    armory_light.name = "WarmFlame"
    armory_light.position = Vector3(0, 0.35, 0)
    armory_light.light_color = Color("#ffd28a")
    armory_light.light_energy = 2.2
    armory_light.omni_range = 7.5
    armory_lamp.add_child(armory_light)

    # Weapon counter remains between the entrance and Buryat's place.
    mesh_box(a, Vector3(0, 1.0, -15.0), Vector3(4.2, 0.7, 0.9), Color("#4b3828"), true)

    var buryat := StaticBody3D.new()
    buryat.name = "Buryat"
    buryat.position = Vector3(0, 0.95, -13.4)
    buryat.set_script(load("res://scripts/Buryat.gd"))
    add_child(buryat)
    var soldier_scene := load("res://assets/props/ussr_infantry_-_call_of_duty_world_at_war.glb") as PackedScene
    if soldier_scene:
        var buryat_visual := soldier_scene.instantiate() as Node3D
        buryat_visual.name = "BuryatSoldierVisual"
        buryat_visual.scale = Vector3.ONE * 0.01
        buryat_visual.rotation.y = PI
        buryat_visual.position.y = -0.95
        var model_root := buryat_visual.find_child("RootNode", true, false) as Node3D
        if model_root:
            var selected_parts := [
                "char_rus_guard_body1_2_LOD0.001",
                "char_rus_guard_head1_4_LOD0",
                "char_rus_guard_body1_gear1_1_LOD0",
                "char_rus_guard_ushankadown1_LOD0"
            ]
            for part in model_root.get_children():
                if part is Node3D:
                    part.visible = part.name in selected_parts
        buryat.add_child(buryat_visual)
    var bc := CollisionShape3D.new()
    var bs := CapsuleShape3D.new()
    bs.radius = 0.4
    bs.height = 1.9
    bc.shape = bs
    buryat.add_child(bc)

    # PPSh is displayed on the issue counter, not thrown on the ground.
    var gun := StaticBody3D.new()
    gun.name = "PPShPickup"
    gun.position = Vector3(0.9, 1.55, -15.0)
    gun.set_script(load("res://scripts/PPShPickup.gd"))
    add_child(gun)
    var gun_visual := load("res://scenes/PPSH.tscn").instantiate() as Node3D
    gun_visual.name = "PPSHVisual"
    gun.add_child(gun_visual)
    var gc := CollisionShape3D.new()
    gc.name = "CollisionShape3D"
    var gs := BoxShape3D.new()
    gs.size = Vector3(0.3, 0.4, 1.0)
    gc.shape = gs
    gun.add_child(gc)
    gc.disabled = true

func build_range():
    var r := Node3D.new()
    r.name = "Range"
    add_child(r)
    mesh_box(r, Vector3(0, -0.01, -70), Vector3(26, 0.05, 20), Color("#6f765a"), false)

    # Targets are deliberately much farther from the firing line.
    for i in range(5):
        var target := StaticBody3D.new()
        target.name = "Target%d" % (i + 1)
        target.position = Vector3(-8 + i * 4.0, 1.2, -78)
        target.set_script(load("res://scripts/Target.gd"))
        r.add_child(target)
        var tm := MeshInstance3D.new()
        var tmesh := BoxMesh.new()
        tmesh.size = Vector3(1.0, 2.0, 0.12)
        tm.mesh = tmesh
        tm.material_override = mat(Color("#d0c9aa"))
        target.add_child(tm)
        var cs := CollisionShape3D.new()
        var sh := BoxShape3D.new()
        sh.size = Vector3(1.0, 2.0, 0.2)
        cs.shape = sh
        target.add_child(cs)
        mesh_box(r, Vector3(-8 + i * 4.0, 0.7, -77.6), Vector3(0.12, 1.4, 0.12), Color("#5b4834"), false)

    # Firing line / small shelter so the player has a clear place to stand.
    mesh_box(r, Vector3(0, 1.2, -52), Vector3(18, 2.4, 0.6), Color("#594734"), true)

func add_tree(parent: Node3D, tree_scene: PackedScene, tree_position: Vector3, tree_scale: float, tree_name: String):
    var tree := tree_scene.instantiate() as Node3D
    tree.name = tree_name
    tree.position = tree_position
    tree.scale = Vector3.ONE * tree_scale
    parent.add_child(tree)

    var scale_ratio := tree_scale / 0.01
    var trunk_body := StaticBody3D.new()
    trunk_body.name = tree_name + "Collision"
    trunk_body.position = tree_position + Vector3(0.0, 0.78 * scale_ratio, 0.0)
    var trunk_shape := CollisionShape3D.new()
    var trunk := CylinderShape3D.new()
    trunk.radius = 0.2 * scale_ratio
    trunk.height = 1.56 * scale_ratio
    trunk_shape.shape = trunk
    trunk_body.add_child(trunk_shape)
    parent.add_child(trunk_body)

func build_truck(pos: Vector3):
    var t := StaticBody3D.new()
    t.name = "ZIS5"
    t.position = pos
    t.set_script(load("res://scripts/Truck.gd"))
    add_child(t)
    var truck_model := load("res://assets/vehicles/zis-5b.glb") as PackedScene
    var truck_visual := truck_model.instantiate() as Node3D
    truck_visual.name = "ZIS5Visual"
    # Godot's GLTF importer converts the centimeter-authored mesh to meters;
    # 0.95 keeps its ~5.8 m length aligned with the existing collision volume.
    truck_visual.scale = Vector3.ONE * 0.95
    truck_visual.rotation_degrees.y = 90.0
    t.add_child(truck_visual)
    var cs := CollisionShape3D.new()
    var sh := BoxShape3D.new()
    sh.size = Vector3(3, 2.5, 6.0)
    cs.shape = sh
    t.add_child(cs)

func build_forest():
    var f := Node3D.new()
    f.name = "Forest"
    add_child(f)
    var pine_scene := load("res://assets/props/pine_tree.glb") as PackedScene
    if pine_scene:
        for side in [-1, 1]:
            for index in range(9):
                var z := -108.0 + index * 20.0
                var x := float(side) * (37.0 + float(index % 2) * 1.0)
                add_tree(f, pine_scene, Vector3(x, 0.0, z), 0.009 + float(index % 3) * 0.0007, "Pine_%s_%02d" % [str(side), index])
        for index in range(9):
            var x := -32.0 + index * 8.0
            if abs(x - 13.0) < 6.0:
                continue
            add_tree(f, pine_scene, Vector3(x, 0.0, -112.0), 0.0095, "Pine_Back_%02d" % index)
            add_tree(f, pine_scene, Vector3(x, 0.0, 62.0), 0.0095, "Pine_Front_%02d" % index)

    # A few broadleaf trees break up the pine line without crowding the yard.
    var oak_scene := load("res://assets/props/oak_trees.glb") as PackedScene
    if oak_scene:
        for data in [Vector3(-29, 0, 25), Vector3(29, 0, -82), Vector3(-29, 0, -88)]:
            var oak := oak_scene.instantiate() as Node3D
            oak.name = "OakTree"
            oak.scale = Vector3.ONE * 2.0
            oak.position = data
            f.add_child(oak)
            var oak_body := StaticBody3D.new()
            oak_body.position = data + Vector3(0, 1.1, 0)
            var oak_shape := CollisionShape3D.new()
            var oak_cylinder := CylinderShape3D.new()
            oak_cylinder.radius = 0.32
            oak_cylinder.height = 2.2
            oak_shape.shape = oak_cylinder
            oak_body.add_child(oak_shape)
            f.add_child(oak_body)

    # Use a few mossy/plain rock variants as low forest-edge decoration with
    # simplified colliders; keep them away from the central route.
    var rock_pack := load("res://assets/props/stylised_rocks_asset_pack.glb").instantiate() as Node3D
    f.add_child(rock_pack)
    var rock_root := rock_pack.find_child("RootNode", true, false)
    if rock_root:
        for source_mesh in rock_pack.find_children("*", "MeshInstance3D", true, false):
            var rock_mesh := source_mesh as MeshInstance3D
            rock_mesh.visible = false
        var rock_sets := [
            ["Plain_Rock1", ["Plain_Rock3", "Plain_Rock12", "Plain_Rock23"], Vector3(32.5, 0, -28.0), 0.9],
            ["Mossy_Rock1", ["Mossy_Rock8", "Mossy_Rock17", "Mossy_Rock29"], Vector3(-32.5, 0, -62.0), 0.9]
        ]
        for rock_set in rock_sets:
            var group := rock_root.get_node_or_null(rock_set[0]) as Node3D
            if group == null:
                continue
            group.position = group.get_parent().global_transform.affine_inverse() * rock_set[2]
            group.scale = Vector3.ONE * float(rock_set[3])
            for index in range(rock_set[1].size()):
                var variant := group.get_node_or_null(rock_set[1][index]) as Node3D
                if variant == null:
                    continue
                # GLB variants are spaced on a 100 cm catalog grid; regroup three
                # different stones as a small cluster and reveal only their meshes.
                variant.position = Vector3((index % 2) * 120.0, 0, (index / 2) * 120.0)
                var selected_meshes := variant.find_children("*", "MeshInstance3D", true, false)
                if not selected_meshes.is_empty():
                    (selected_meshes[0] as MeshInstance3D).visible = true
                var rock_body := StaticBody3D.new()
                rock_body.name = "RockCollision"
                rock_body.position.y = 0.55
                var rock_shape := CollisionShape3D.new()
                var rock_sphere := SphereShape3D.new()
                rock_sphere.radius = 0.72
                rock_shape.shape = rock_sphere
                rock_body.add_child(rock_shape)
                variant.add_child(rock_body)

func setup_audio():
    shout_player = AudioStreamPlayer.new()
    shout_player.name = "ShoutPlayer"
    var stream: AudioStream = load("res://assets/za_baranova.mp3") as AudioStream
    if stream:
        shout_player.stream = stream
    shout_player.volume_db = 0.0
    add_child(shout_player)

    menu_music_player = AudioStreamPlayer.new()
    menu_music_player.name = "MenuMusic"
    var menu_stream: AudioStream = load("res://assets/menu_music.mp3") as AudioStream
    if menu_stream:
        menu_music_player.stream = menu_stream
        if menu_stream is AudioStreamMP3:
            (menu_stream as AudioStreamMP3).loop = true
    menu_music_player.volume_db = -5.0
    add_child(menu_music_player)
    if menu_music_player.stream:
        menu_music_player.play()

    fork_task_voice_player = AudioStreamPlayer.new()
    fork_task_voice_player.name = "ForkTaskVoice"
    fork_task_voice_player.stream = load("res://assets/audio/Kak ya budu vilkoy to chistitь.mp3") as AudioStream
    fork_task_voice_player.volume_db = -2.0
    add_child(fork_task_voice_player)

    fork_clean_player = AudioStreamPlayer.new()
    fork_clean_player.name = "ForkCleaningSound"
    fork_clean_player.stream = load("res://assets/audio/chistit-vilkoj1.mp3") as AudioStream
    fork_clean_player.volume_db = -5.0
    add_child(fork_clean_player)

func style_text(control: Control, outline_size: int = TEXT_OUTLINE_SIZE):
    control.add_theme_color_override("font_outline_color", TEXT_OUTLINE_COLOR)
    control.add_theme_constant_override("outline_size", outline_size)

func style_text_tree(root: Node):
    for child in root.get_children():
        if child is Label or child is Button:
            style_text(child as Control)
        style_text_tree(child)

func build_ui():
    ui = CanvasLayer.new()
    ui.name = "UI"
    add_child(ui)

    objective = Label.new()
    objective.position = Vector2(28, 25)
    objective.add_theme_font_size_override("font_size", 22)
    ui.add_child(objective)

    message = Label.new()
    message.position = Vector2(28, 65)
    message.add_theme_font_size_override("font_size", 20)
    ui.add_child(message)

    prompt = Label.new()
    prompt.position = Vector2(380, 610)
    prompt.size = Vector2(520, 45)
    prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    prompt.add_theme_font_size_override("font_size", 22)
    ui.add_child(prompt)

    ammo_label = Label.new()
    ammo_label.position = Vector2(1050, 640)
    ammo_label.add_theme_font_size_override("font_size", 22)
    ui.add_child(ammo_label)

    crosshair = Label.new()
    crosshair.text = "+"
    crosshair.position = Vector2(634, 348)
    crosshair.add_theme_font_size_override("font_size", 22)
    ui.add_child(crosshair)

    health_bar = ProgressBar.new()
    health_bar.position = Vector2(28, 650)
    health_bar.size = Vector2(260, 22)
    health_bar.value = 100
    ui.add_child(health_bar)

    stamina_bar = ProgressBar.new()
    stamina_bar.position = Vector2(28, 680)
    stamina_bar.size = Vector2(260, 22)
    stamina_bar.value = 100
    ui.add_child(stamina_bar)

    toilet_panel = Panel.new()
    toilet_panel.position = Vector2(430, 520)
    toilet_panel.size = Vector2(420, 100)
    toilet_panel.visible = false
    ui.add_child(toilet_panel)

    var tl := Label.new()
    tl.text = "ОЧИСТКА УНИТАЗА ВИЛКОЙ"
    tl.position = Vector2(55, 10)
    tl.add_theme_font_size_override("font_size", 20)
    toilet_panel.add_child(tl)
    toilet_bar = ProgressBar.new()
    toilet_bar.position = Vector2(25, 45)
    toilet_bar.size = Vector2(370, 25)
    toilet_panel.add_child(toilet_bar)

    menu = Panel.new()
    menu.position = Vector2(0, 0)
    menu.size = Vector2(1280, 720)
    ui.add_child(menu)

    var bg := TextureRect.new()
    bg.name = "MenuBackground"
    bg.position = Vector2.ZERO
    bg.size = Vector2(1280, 720)
    bg.texture = load("res://assets/menu_background.jpg") as Texture2D
    bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    menu.add_child(bg)
    menu.move_child(bg, 0)

    var overlay := ColorRect.new()
    overlay.position = Vector2.ZERO
    overlay.size = Vector2(1280, 720)
    overlay.color = Color(0.0, 0.0, 0.0, 0.22)
    menu.add_child(overlay)
    menu.move_child(overlay, 1)

    var title := Label.new()
    title.text = "РОДИНА 3D\nСТУДИН: ЗА БАРАНОВА"
    title.position = Vector2(70, 85)
    title.add_theme_font_size_override("font_size", 42)
    menu.add_child(title)

    var sub := Label.new()
    sub.text = "Пролог — первая часть"
    sub.position = Vector2(75, 185)
    sub.add_theme_font_size_override("font_size", 23)
    menu.add_child(sub)

    var start := Button.new()
    start.text = "НАЧАТЬ ИГРУ"
    start.position = Vector2(75, 260)
    start.size = Vector2(300, 58)
    start.pressed.connect(start_game)
    menu.add_child(start)

    var controls := Button.new()
    controls.text = "УПРАВЛЕНИЕ"
    controls.position = Vector2(75, 335)
    controls.size = Vector2(300, 58)
    controls.pressed.connect(show_controls)
    menu.add_child(controls)

    var hint := Label.new()
    hint.text = "Пародия на военное кино.\nЧем дальше — тем хуже."
    hint.position = Vector2(75, 425)
    hint.add_theme_font_size_override("font_size", 20)
    menu.add_child(hint)

    var credit := Label.new()
    credit.text = "Godot 4 · Compatibility"
    credit.position = Vector2(75, 660)
    credit.add_theme_font_size_override("font_size", 15)
    menu.add_child(credit)

    style_text_tree(ui)

func show_controls():
    var box := AcceptDialog.new()
    box.title = "УПРАВЛЕНИЕ"
    box.dialog_text = "WASD — движение\nShift — бег\nSpace — прыжок\nCtrl — присесть\n2 — достать / убрать ППШ\nЛКМ — стрелять\nПКМ — прицеливание\nF — взаимодействие\nT — перезарядка\nR — крик «За Баранова!»\nEsc — отпустить мышь"
    ui.add_child(box)
    style_text_tree(box)
    box.popup_centered(Vector2(520, 330))

func start_game():
    if menu_music_player and menu_music_player.playing:
        menu_music_player.stop()
    menu.visible = false
    menu_open = false
    player.process_mode = Node.PROCESS_MODE_INHERIT
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
    update_state("barracks")
    player.position = Vector3(0, 1.05, 18.0)
    player.velocity = Vector3.ZERO
    player.rotation = Vector3(0, PI, 0)
    player.head.rotation = Vector3.ZERO
    door_unlocked = false
    toilet_exit_unlocked = false
    buryat_has_issued_weapon = false
    toilet_progress = 0
    toilet_bar.value = 0
    player.fork.visible = false

func update_state(s):
    state = s
    prompt.text = ""
    toilet_panel.visible = false
    if s == "barracks":
        if toilet_exit_unlocked:
            objective.text = "ПРОЛОГ  |  Задание: выйти из казармы во двор"
            var yard_exit: StaticBody3D = get_node_or_null("Barracks/BarracksExitDoor") as StaticBody3D
            if yard_exit:
                yard_exit.locked = false
                yard_exit.action_text = "Выйти во двор"
        else:
            objective.text = "ПРОЛОГ  |  Задание: поговорить со старшим по заданию"
    elif s == "toilet":
        objective.text = "ПРОЛОГ  |  Задание: почистить унитаз вилкой"
        toilet_panel.visible = true
        toilet_bar.value = toilet_progress
        player.fork.visible = true
        var toilet_door: StaticBody3D = get_node_or_null("Barracks/ToiletDoor") as StaticBody3D
        if toilet_door:
            toilet_door.target_state = "toilet"
    elif s == "yard":
        player.fork.visible = false
        objective.text = "ПРОЛОГ  |  Задание: найти Бурята и получить ППШ"
    elif s == "range":
        range_started = true
        targets_left = 5
        objective.text = "ПРОЛОГ  |  Стрельбище: поразить все мишени издалека"
    elif s == "truck":
        objective.text = "ПРОЛОГ  |  Стрельба окончена. Найти и сесть в грузовик"
    elif s == "end":
        objective.text = "ПРОЛОГ ЗАВЕРШЁН"

func toilet_clean():
    if state != "toilet":
        return
    if fork_clean_player and not fork_clean_player.playing:
        fork_clean_player.play()
    toilet_progress = min(100, toilet_progress + 12)
    toilet_bar.value = toilet_progress
    message.text = "Студин усердно чистит вилкой…"
    if toilet_progress >= 100:
        player.fork.visible = false
        toilet_panel.visible = false
        toilet_exit_unlocked = true
        var exit_door: StaticBody3D = get_node_or_null("Barracks/ToiletDoor") as StaticBody3D
        if exit_door:
            exit_door.locked = false
            exit_door.action_text = "Выйти в казарму"
            exit_door.target_state = "barracks"
            exit_door.auto_close_after_entry = false
            var collision: CollisionShape3D = exit_door.get_node_or_null("CollisionShape3D") as CollisionShape3D
            if collision:
                collision.set_deferred("disabled", false)
        update_state("barracks")
        message.text = "Готово. Теперь можно выйти из казармы во двор."

func receive_ppsh_from_buryat():
    if state != "yard":
        return
    buryat_has_issued_weapon = true
    player.give_ppsh()
    var gun: StaticBody3D = get_node_or_null("PPShPickup") as StaticBody3D
    if gun:
        var collision := gun.get_node_or_null("CollisionShape3D") as CollisionShape3D
        if collision:
            collision.set_deferred("disabled", true)
        var visual := gun.get_node_or_null("PPSHVisual") as Node3D
        if visual:
            visual.visible = false
    objective.text = "ПРОЛОГ  |  Задание: пройти на стрельбище"
    say("Бурят: «Вот, твоё оружие. Идти стрелять мишень тренировка.»")

func target_hit():
    targets_left -= 1
    message.text = "Попадание. Осталось мишеней: %d" % targets_left
    if targets_left <= 0:
        update_state("truck")

func finish_prologue():
    update_state("end")
    message.text = "Дмитрий садится в ЗИС-5. Пролог закончен."
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func unlock_toilet_door():
    if not door_unlocked and fork_task_voice_player:
        fork_task_voice_player.play()
    door_unlocked = true
    var door: StaticBody3D = get_node_or_null("Barracks/ToiletDoor") as StaticBody3D
    if door:
        door.locked = false
        door.action_text = "Открыть дверь в туалет"
        door.target_state = "toilet"
        door.auto_close_after_entry = true

func try_finish_truck():
    if state != "truck":
        say("Сначала нужно закончить стрельбу.")
        return
    finish_prologue()

func player_shout():
    if menu_open:
        return
    message.text = "СТУДИН: «ЗА БАРАНОВА!»"
    message_time = 1.7
    if shout_player and shout_player.stream:
        shout_player.play()

func say(t):
    message.text = t
    message_time = 2.8

func weapon_fired():
    muzzle_time = 0.06

func _process(delta):
    if menu_open:
        return

    health_bar.value = player.health
    stamina_bar.value = player.stamina
    if player.can_shoot and player.current_weapon_definition:
        ammo_label.text = "%s  %02d / %02d" % [player.current_weapon_definition.display_name, player.ammo, player.reserve_ammo]
    elif player.can_shoot:
        ammo_label.text = "Оружие получено"
    else:
        ammo_label.text = "ППШ — не получен"

    if message_time > 0:
        message_time -= delta
        if message_time <= 0:
            message.text = ""

    # Close and lock the single toilet door only after the player has actually
    # moved inside. This avoids trapping the player in the doorway.
    if state == "toilet":
        var toilet_door: StaticBody3D = get_node_or_null("Barracks/ToiletDoor") as StaticBody3D
        if toilet_door and toilet_door.opened and toilet_door.auto_close_after_entry and player.position.z > 23.25:
            toilet_door.close_and_lock("Дверь заперта до окончания уборки")

    # Yard-to-range transition is deliberately far from the armory.
    if state == "yard" and buryat_has_issued_weapon and player.can_shoot and player.position.z < -50:
        update_state("range")

    var from: Vector3 = camera.global_position
    var to: Vector3 = from + -camera.global_transform.basis.z * 4.5
    var ray := PhysicsRayQueryParameters3D.create(from, to)
    ray.exclude = [player]
    var hit := get_world_3d().direct_space_state.intersect_ray(ray)
    var interactable: Node = null
    if hit and hit.collider is Node and hit.collider.has_method("interact"):
        interactable = hit.collider

    if interactable != null:
        prompt.text = "[F] " + str(interactable.action_text).replace(" [F]", "")
        if Input.is_action_just_pressed("interact"):
            interactable.interact(player)
    else:
        prompt.text = ""
