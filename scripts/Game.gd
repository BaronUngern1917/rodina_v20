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

func create_door(parent: Node, name: String, pos: Vector3, width: float, color: Color, locked := false, action := "Открыть дверь", target := "yard") -> StaticBody3D:
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
    door_visual.scale = Vector3(width / source_bounds.size.x, 3.0 / source_bounds.size.y, 0.18 / source_bounds.size.z)
    door_visual.position = Vector3(
        -source_bounds.end.x * door_visual.scale.x,
        -source_bounds.get_center().y * door_visual.scale.y,
        -source_bounds.get_center().z * door_visual.scale.z
    )
    door.add_child(door_visual)

    var cs := CollisionShape3D.new()
    cs.name = "CollisionShape3D"
    var bs := BoxShape3D.new()
    bs.size = Vector3(width, 3.0, 0.18)
    cs.shape = bs
    cs.position = Vector3(-width * 0.5, 0, 0)
    door.add_child(cs)
    return door

func build_world():
    # The base is intentionally much larger than v11: the player now has real space to walk between buildings.
    mesh_box(self, Vector3(0, -0.2, -25), Vector3(86, 0.4, 190), Color("#5f654e"), true)
    build_barracks()
    build_yard()
    build_armory()
    build_range()
    build_truck(Vector3(13, 0.55, -104))
    build_forest()

func build_barracks():
    var b := Node3D.new()
    b.name = "Barracks"
    add_child(b)

    # Keep the original floor/wall collision layout, but replace its blockout visuals.
    var shell_visuals: Array[MeshInstance3D] = []
    shell_visuals.append(mesh_box(b, Vector3(0, 0.05, 21), Vector3(16, 0.1, 14), Color("#6a4e38"), true))
    shell_visuals.append(mesh_box(b, Vector3(-4.5, 2.0, 14), Vector3(7.0, 4.0, 0.2), Color("#6a4e38"), true))
    shell_visuals.append(mesh_box(b, Vector3(4.5, 2.0, 14), Vector3(7.0, 4.0, 0.2), Color("#6a4e38"), true))
    shell_visuals.append(mesh_box(b, Vector3(0, 2.0, 28), Vector3(16, 4.0, 0.2), Color("#6a4e38"), true))
    shell_visuals.append(mesh_box(b, Vector3(-7.9, 2.0, 21), Vector3(0.2, 4.0, 14), Color("#6a4e38"), true))
    shell_visuals.append(mesh_box(b, Vector3(7.9, 2.0, 21), Vector3(0.2, 4.0, 14), Color("#6a4e38"), true))
    shell_visuals.append(mesh_box(b, Vector3(0, 4.3, 21), Vector3(16.5, 0.6, 14.5), Color("#3e3a30"), true))
    for shell_visual in shell_visuals:
        shell_visual.visible = false

    var barracks_visual := load("res://assets/props/small_barracks.glb").instantiate() as Node3D
    barracks_visual.name = "SmallBarracksVisual"
    # Model bounds are about 7.05 x 5.80 x 10.01 m. Non-uniform scale matches
    # the existing 16 x 14 m footprint and 4 m walls without moving gameplay points.
    barracks_visual.scale = Vector3(2.25, 0.69, 1.4)
    barracks_visual.position = Vector3(0, 0.13, 20.3)
    var built_in_door := barracks_visual.find_child("door_low_003", true, false)
    if built_in_door:
        built_in_door.visible = false
    var ground_disc := barracks_visual.find_child("Circle", true, false)
    if ground_disc:
        ground_disc.visible = false
    b.add_child(barracks_visual)

    # Beds.
    for x in [-5.2, 0.0, 5.2]:
        for z in [17.0, 25.0]:
            mesh_box(b, Vector3(x, 0.55, z), Vector3(3.0, 0.35, 1.15), Color("#5a5b50"), false)
            mesh_box(b, Vector3(x, 0.9, z - 0.35), Vector3(3.0, 0.25, 0.15), Color("#403f38"), false)

    # Propaganda posters.
    mesh_box(b, Vector3(-2.4, 2.5, 13.88), Vector3(2.0, 2.3, 0.05), Color("#8e332c"), false)
    mesh_box(b, Vector3(0.0, 2.5, 13.88), Vector3(2.0, 2.3, 0.05), Color("#b18b38"), false)
    mesh_box(b, Vector3(2.4, 2.5, 13.88), Vector3(2.0, 2.3, 0.05), Color("#6b6e63"), false)

    # Main exterior exit. It becomes usable only after the toilet sequence is finished.
    var yard_exit := create_door(b, "BarracksExitDoor", Vector3(1.1, 1.5, 14.12), 2.2, Color("#49382b"), true, "Выйти во двор", "yard")
    yard_exit.action_text = "Выйти во двор"
    # A visual threshold only; it must never block the exterior doorway.
    mesh_box(b, Vector3(0, 0.12, 13.88), Vector3(2.0, 0.12, 0.22), Color("#5a4735"), false)

    # One normal toilet door. It is used both to enter and to leave;
    # after entering, it closes and stays locked until cleaning is finished.
    var toilet_entry := create_door(b, "ToiletDoor", Vector3(6.7, 1.5, 19.0), 2.2, Color("#49382b"), true, "Открыть дверь в туалет", "toilet")
    toilet_entry.action_text = "Открыть дверь в туалет"
    toilet_entry.auto_close_after_entry = true

    # Senior soldier.
    var officer := StaticBody3D.new()
    officer.name = "SeniorSoldier"
    officer.position = Vector3(3.0, 1.0, 15.5)
    officer.set_script(load("res://scripts/Officer.gd"))
    add_child(officer)
    mesh_box(officer, Vector3.ZERO, Vector3(0.7, 1.9, 0.45), Color("#4d5948"), false)
    mesh_cylinder(officer, Vector3(0, 1.25, 0), 0.3, 0.45, Color("#a9846b"))
    var oc := CollisionShape3D.new()
    var os := CapsuleShape3D.new()
    os.radius = 0.38
    os.height = 1.9
    oc.shape = os
    officer.add_child(oc)

    # Toilet is a small enclosed room with ONE doorway only.
    var room := Node3D.new()
    room.name = "ToiletRoom"
    add_child(room)
    # The front opening is exactly the width of ToiletDoor. The door is aligned
    # to the right jamb, so there is no half-door gap at either side.
    mesh_box(room, Vector3(4.0, 1.5, 19.0), Vector3(1.0, 3.0, 0.2), Color("#5b4939"), true)
    mesh_box(room, Vector3(7.2, 1.5, 19.0), Vector3(1.0, 3.0, 0.2), Color("#5b4939"), true)
    mesh_box(room, Vector3(7.6, 1.5, 21.0), Vector3(0.2, 3.0, 4.0), Color("#5b4939"), true)
    mesh_box(room, Vector3(3.6, 1.5, 21.0), Vector3(0.2, 3.0, 4.0), Color("#5b4939"), true)
    mesh_box(room, Vector3(5.6, 3.0, 21.0), Vector3(4.2, 0.2, 4.0), Color("#514238"), true)
    mesh_box(room, Vector3(5.6, 0.1, 21.0), Vector3(4.2, 0.2, 4.0), Color("#5b4939"), true)
    # Solid rear wall: there is deliberately no second exit.
    mesh_box(room, Vector3(5.6, 1.5, 23.0), Vector3(4.2, 3.0, 0.2), Color("#5b4939"), true)

    var toilet := StaticBody3D.new()
    toilet.name = "Toilet"
    toilet.position = Vector3(5.6, 0.35, 21.0)
    toilet.set_script(load("res://scripts/Toilet.gd"))
    add_child(toilet)
    mesh_box(toilet, Vector3.ZERO, Vector3(1.0, 0.7, 1.2), Color("#c7c4b7"), false)
    var tc := CollisionShape3D.new()
    var ts := BoxShape3D.new()
    ts.size = Vector3(1, 0.7, 1.2)
    tc.shape = ts
    toilet.add_child(tc)

    # Kerose­ne lamp: warm local light with a crude metal base and glass body.
    var lamp := Node3D.new()
    lamp.name = "KeroseneLamp"
    lamp.position = Vector3(-1.0, 2.7, 20.5)
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

    # Fork in first-person view.
    mesh_cylinder($Player/Head/Camera3D/Fork, Vector3.ZERO, 0.018, 0.45, Color("#b9b7aa"))

func build_yard():
    var y := Node3D.new()
    y.name = "Yard"
    add_child(y)

    # Several spaced-out service buildings, no more cramped cluster.
    for data in [
        Vector3(-16, 1.5, 8), Vector3(16, 1.5, 8),
        Vector3(-18, 1.5, -12), Vector3(18, 1.5, -12),
        Vector3(-17, 1.5, -35), Vector3(17, 1.5, -35)
    ]:
        mesh_box(y, data, Vector3(7, 3, 6), Color("#725437"), true)

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

func build_armory():
    var a := Node3D.new()
    a.name = "Armory"
    add_child(a)

    # Fully enclosed weapon-issue building. The only opening is the front door.
    mesh_box(a, Vector3(0, 0.05, -12), Vector3(12, 0.1, 10), Color("#6b4d35"), true)
    # Front wall: opening from x=0 to x=2.2 for a single hinged door.
    mesh_box(a, Vector3(-3.0, 1.8, -16.9), Vector3(6.0, 3.6, 0.2), Color("#6b4d35"), true)
    mesh_box(a, Vector3(4.1, 1.8, -16.9), Vector3(3.8, 3.6, 0.2), Color("#6b4d35"), true)
    # Side and rear walls: no through-passages.
    mesh_box(a, Vector3(-5.9, 1.8, -12), Vector3(0.2, 3.6, 10), Color("#6b4d35"), true)
    mesh_box(a, Vector3(5.9, 1.8, -12), Vector3(0.2, 3.6, 10), Color("#6b4d35"), true)
    mesh_box(a, Vector3(0, 1.8, -7.1), Vector3(12, 3.6, 0.2), Color("#6b4d35"), true)
    mesh_box(a, Vector3(0, 3.8, -12), Vector3(12, 0.5, 10), Color("#3e3a30"), true)

    # One proper hinged entrance door. Its pivot is at the right jamb.
    var armory_door := create_door(a, "ArmoryDoor", Vector3(2.2, 1.8, -16.78), 2.2, Color("#49382b"), false, "Открыть оружейную", "yard")
    armory_door.action_text = "Открыть оружейную"

    # Real armory photo: use a QuadMesh whose normal is +Z by default, so the
    # texture faces the room.  The rear wall is at z=-7.1, while Buryat is at z=-13.0.
    # IMPORTANT: the room extends toward NEGATIVE Z from the rear wall, so the old
    # z=-6.50 placement was actually outside the building.  Put the photo at -10.5,
    # clearly inside and slightly closer to Buryat than to the rear wall.
    var arsenal_panel := MeshInstance3D.new()
    arsenal_panel.name = "ArsenalInteriorBackdrop"
    var arsenal_mesh := QuadMesh.new()
    arsenal_mesh.size = Vector2(11.5, 3.2)
    arsenal_panel.mesh = arsenal_mesh
    arsenal_panel.position = Vector3(0, 1.85, -10.5)
    var arsenal_mat := StandardMaterial3D.new()
    arsenal_mat.albedo_texture = load("res://assets/armory_wall.jpg") as Texture2D
    arsenal_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    arsenal_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    arsenal_mat.roughness = 1.0
    arsenal_panel.material_override = arsenal_mat
    a.add_child(arsenal_panel)

    # Same kind of kerosene lamp as in the barracks, so Buryat's room is
    # visibly lit without making the whole yard bright.
    var armory_lamp := Node3D.new()
    armory_lamp.name = "KeroseneLamp"
    armory_lamp.position = Vector3(-3.8, 2.7, -12.0)
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

    # Weapon counter.
    mesh_box(a, Vector3(0, 1.0, -14.5), Vector3(7.0, 0.7, 1.0), Color("#4b3828"), true)

    var buryat := StaticBody3D.new()
    buryat.name = "Buryat"
    buryat.position = Vector3(0, 1.0, -13.0)
    buryat.set_script(load("res://scripts/Buryat.gd"))
    add_child(buryat)
    mesh_box(buryat, Vector3.ZERO, Vector3(0.8, 1.9, 0.5), Color("#455342"), false)
    mesh_cylinder(buryat, Vector3(0, 1.25, 0), 0.31, 0.45, Color("#a9846b"))
    var bc := CollisionShape3D.new()
    var bs := CapsuleShape3D.new()
    bs.radius = 0.4
    bs.height = 1.9
    bc.shape = bs
    buryat.add_child(bc)

    # PPSh is displayed on the issue counter, not thrown on the ground.
    var gun := StaticBody3D.new()
    gun.name = "PPShPickup"
    gun.position = Vector3(0.9, 1.55, -14.4)
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
    for i in range(70):
        var x := float((i * 37) % 96) - 48.0
        var z := float((i * 53) % 190) - 120.0
        if abs(x) < 24 and z > -55:
            continue
        mesh_cylinder(f, Vector3(x, 1.4, z), 0.18 + float(i % 3) * 0.07, 2.8 + float(i % 2) * 1.2, Color("#3f3a2b"))
        var crown: MeshInstance3D = mesh_cylinder(f, Vector3(x, 3.1, z), 0.9 + float(i % 3) * 0.2, 2.0, Color("#354934"))
        crown.scale = Vector3(1, 1, 1)

    # Use individual mossy/plain pack variants as low forest-edge decoration.
    # They stay off the central route and have no collision because they are not obstacles.
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
    box.dialog_text = "WASD — движение\nShift — бег\nЛКМ — стрелять\nПКМ — прицеливание\nF — взаимодействие\nT — перезарядка\nR — крик «За Баранова!»\nEsc — отпустить мышь"
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
    player.position = Vector3(0, 1.05, 25)
    player.velocity = Vector3.ZERO
    player.rotation = Vector3(0, 0, 0)
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
        message.text = "Готово. Теперь можно вернуться в казарму через дверь."
        objective.text = "ПРОЛОГ  |  Задание: вернуться в казарму через дверь"

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
        var visual := gun.get_node_or_null("MeshInstance3D") as MeshInstance3D
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
    ammo_label.text = ("ППШ  %02d / 35" % player.ammo) if player.can_shoot else "ППШ — не получен"

    if message_time > 0:
        message_time -= delta
        if message_time <= 0:
            message.text = ""

    # Close and lock the single toilet door only after the player has actually
    # moved inside. This avoids trapping the player in the doorway.
    if state == "toilet":
        var toilet_door: StaticBody3D = get_node_or_null("Barracks/ToiletDoor") as StaticBody3D
        if toilet_door and toilet_door.opened and toilet_door.auto_close_after_entry and player.position.z > 20.15:
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
