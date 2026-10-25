extends CharacterBody3D

@export var walk_speed := 4.2
@export var sprint_speed := 7.2
@export var crouch_speed := 2.25
@export var jump_velocity := 5.0
@export var mouse_sensitivity := 0.0024

var health := 100.0
var stamina := 100.0
var gravity := 18.0
var pitch := 0.0
var can_shoot := false # Retained as the inventory/quest flag used by Chapter 1.
var ammo := 35
var reserve_ammo := 0
var max_ammo := 35
var reloading := false
var aim := false
var weapon_visible := false
var is_crouched := false

var weapon_catalog: Array[WeaponDefinition] = []
var owned_weapons: Array[WeaponDefinition] = []
var weapon_ammo: Dictionary = {}
var weapon_reserve_ammo: Dictionary = {}
var current_weapon_definition: WeaponDefinition
var fire_cooldown := 0.0
var recoil_offset := 0.0
var walk_cycle := 0.0
var step_timer := 0.0
var muzzle_timer := 0.0
var standing_capsule: CapsuleShape3D
var standing_capsule_height := 1.8
var standing_head_y := 0.55
var standing_camera_y := 0.15

var muzzle_flash: MeshInstance3D
var muzzle_light: OmniLight3D
const ONE_SHOT_AUDIO_POOL_SCRIPT: Script = preload("res://scripts/OneShotAudioPool.gd")
var footstep_sound_pool: Node3D
var ppsh_single_sound: AudioStreamPlayer3D
const SWORD_ATTACK_DURATION := 0.38
var sword_attack_remaining := 0.0
var chapter3_active := false
var chapter3_body: Node3D
var chapter3_body_skeleton: Skeleton3D
var chapter3_hand_mount: BoneAttachment3D
var chapter3_weapon_models: Dictionary = {}
var chapter3_bone_indices: Dictionary = {}
var chapter3_bone_rest_poses: Dictionary = {}
var chapter3_move_phase := 0.0
var chapter3_reload_in_progress := false
var using_chapter3_gun := false
var chapter3_lean_current := 0.0
var chapter3_camera_base_x := 0.0
const CHAPTER3_LEAN_DISTANCE := 0.28
const CHAPTER3_LEAN_ROLL := deg_to_rad(7.0)

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var weapon: Node3D = $Head/Camera3D/Weapon
@onready var fork: Node3D = $Head/Camera3D/Fork
@onready var player_collision: CollisionShape3D = $CollisionShape3D

func _ready():
    var capsule := player_collision.shape as CapsuleShape3D
    if capsule:
        standing_capsule = capsule.duplicate() as CapsuleShape3D
        standing_capsule_height = capsule.height
    standing_head_y = head.position.y
    standing_camera_y = camera.position.y
    chapter3_camera_base_x = camera.position.x
    setup_weapon()
    setup_player_audio()

func setup_weapon():
    for placeholder in ["WeaponBody", "WeaponStock", "WeaponBarrel", "WeaponMagazine"]:
        var node := get_node_or_null("Head/Camera3D/Weapon/" + placeholder) as MeshInstance3D
        if node:
            node.visible = false

    var ppsh := load("res://resources/weapons/ppsh_definition.tres") as WeaponDefinition
    if ppsh:
        weapon_catalog.append(ppsh)
        max_ammo = ppsh.magazine_capacity
        ammo = max_ammo
    var sword := load("res://resources/weapons/sword_definition.tres") as WeaponDefinition
    if sword:
        weapon_catalog.append(sword)
        owned_weapons.append(sword)
        weapon_ammo[sword.weapon_id] = 0
        weapon_reserve_ammo[sword.weapon_id] = 0
    var ptrd := load("res://resources/weapons/ptrd_definition.tres") as WeaponDefinition
    if ptrd:
        weapon_catalog.append(ptrd)
    var mp40 := load("res://resources/weapons/mp40_definition.tres") as WeaponDefinition
    if mp40:
        weapon_catalog.append(mp40)
    weapon.visible = false
    fork.visible = false
    camera.fov = 75.0

func setup_player_audio():
    footstep_sound_pool = ONE_SHOT_AUDIO_POOL_SCRIPT.new() as Node3D
    footstep_sound_pool.name = "FootstepOneShotPool"
    footstep_sound_pool.position.y = -0.75
    add_child(footstep_sound_pool)
    var footstep_stream := load("res://assets/audio/fast-walking-on-a-concrete-surface.mp3") as AudioStream
    footstep_sound_pool.call("configure", footstep_stream, 0.24, 0.35, -12.0, 18.0, 3.0, 4)
    footstep_sound_pool.call("set_sample_starts", PackedFloat32Array([0.0, 0.33, 0.68, 1.03, 1.38, 1.73, 2.1, 2.45, 2.8, 3.2, 3.6]))

    ppsh_single_sound = _create_ppsh_sample_player("PPSHSingleSound", "res://assets/audio/ppsh_single.wav")

func _create_ppsh_sample_player(player_name: String, stream_path: String) -> AudioStreamPlayer3D:
    var sample_player := AudioStreamPlayer3D.new()
    sample_player.name = player_name
    sample_player.stream = load(stream_path) as AudioStream
    sample_player.position.y = 1.0
    sample_player.volume_db = -3.0
    sample_player.max_distance = 32.0
    sample_player.unit_size = 5.0
    sample_player.max_polyphony = 12
    add_child(sample_player)
    return sample_player

func _queue_ppsh_fire_sound() -> void:
    if ppsh_single_sound and ppsh_single_sound.stream:
        ppsh_single_sound.play()

func _unhandled_input(event):
    if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
        rotate_y(-event.relative.x * mouse_sensitivity)
        pitch = clamp(pitch - event.relative.y * mouse_sensitivity, -1.45, 1.45)
        head.rotation.x = pitch + recoil_offset

    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_ESCAPE:
            Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
        for definition in weapon_catalog:
            if event.physical_keycode == definition.equip_key_physical_code and owned_weapons.has(definition):
                toggle_weapon(definition)

    if event is InputEventMouseButton and event.pressed:
        if event.button_index == MOUSE_BUTTON_LEFT and weapon_visible and current_weapon_definition != null and current_weapon_definition.weapon_id == &"sword" and sword_attack_remaining <= 0.0:
            sword_attack_remaining = SWORD_ATTACK_DURATION
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta):
    fire_cooldown = maxf(0.0, fire_cooldown - delta)
    recoil_offset = move_toward(recoil_offset, 0.0, delta * 0.09)
    sword_attack_remaining = maxf(0.0, sword_attack_remaining - delta)

    var lean_game: Node = get_tree().get_first_node_in_group("game")
    if chapter3_active and lean_game != null and lean_game.get("state") == "chapter3":
        _update_chapter3_lean(delta)
    else:
        _reset_chapter3_lean(delta)

    var active_game := get_tree().get_first_node_in_group("game")
    if active_game != null and active_game.state == "chase":
        aim = weapon_visible and can_shoot and _is_ranged_weapon() and not reloading and Input.is_action_pressed("aim")
        update_weapon_pose(delta, false)
        camera.fov = move_toward(camera.fov, 62.0 if aim else 75.0, delta * 45.0)
        if muzzle_timer > 0.0:
            muzzle_timer -= delta
            if muzzle_flash:
                muzzle_flash.visible = muzzle_timer > 0.0
            if muzzle_light:
                muzzle_light.light_energy = 2.0 if muzzle_timer > 0.0 else 0.0
        if weapon_visible and can_shoot and _is_ranged_weapon() and not reloading and Input.is_action_pressed("shoot"):
            shoot()
        if Input.is_action_just_pressed("reload") and weapon_visible and can_shoot and _is_ranged_weapon():
            reload_weapon()
        head.rotation.x = pitch + recoil_offset
        return

    var crouch_requested := Input.is_action_pressed("crouch")
    if crouch_requested and not is_crouched:
        set_crouched(true)
    elif not crouch_requested and is_crouched and can_stand_up():
        set_crouched(false)

    if not is_on_floor():
        velocity.y -= gravity * delta
    elif Input.is_action_just_pressed("jump") and not is_crouched:
        velocity.y = jump_velocity

    var input_vec := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
    var dir := (transform.basis * Vector3(input_vec.x, 0.0, input_vec.y)).normalized()
    var moving := input_vec.length() > 0.1
    var sprinting := not is_crouched and Input.is_action_pressed("sprint") and moving and stamina > 0.0
    var speed := crouch_speed if is_crouched else (sprint_speed if sprinting else walk_speed)
    if sprinting:
        stamina = maxf(0.0, stamina - 25.0 * delta)
    else:
        stamina = minf(100.0, stamina + 18.0 * delta)

    velocity.x = move_toward(velocity.x, dir.x * speed, 22.0 * delta)
    velocity.z = move_toward(velocity.z, dir.z * speed, 22.0 * delta)
    move_and_slide()

    var actual_movement := Vector2(velocity.x, velocity.z).length() > 0.25
    aim = weapon_visible and can_shoot and _is_ranged_weapon() and not reloading and Input.is_action_pressed("aim")
    update_footsteps(delta, actual_movement, sprinting)
    update_weapon_pose(delta, actual_movement)
    if muzzle_timer > 0.0:
        muzzle_timer -= delta
        if muzzle_flash:
            muzzle_flash.visible = muzzle_timer > 0.0
        if muzzle_light:
            muzzle_light.light_energy = 2.0 if muzzle_timer > 0.0 else 0.0

    var active_game_c3: Node = get_tree().get_first_node_in_group("game")
    if active_game_c3 != null and active_game_c3.state == "chapter3" and using_chapter3_gun:
        velocity = Vector3.ZERO
        move_and_slide()
        head.rotation.x = pitch + recoil_offset
        return
    if weapon_visible and current_weapon_definition != null and current_weapon_definition.weapon_id == &"sword" and active_game_c3 != null and active_game_c3.state == "chapter3" and Input.is_action_just_pressed("shoot"):
        sword_attack_remaining = SWORD_ATTACK_DURATION
        var chapter3: Node = get_tree().get_first_node_in_group("chapter3_controller")
        if chapter3 != null:
            chapter3.call("player_melee_attack")
    elif weapon_visible and can_shoot and _is_ranged_weapon() and not reloading:
        if current_weapon_definition.weapon_id == &"ptrd":
            if Input.is_action_just_pressed("shoot"):
                shoot()
        elif Input.is_action_pressed("shoot"):
            shoot()
    if Input.is_action_just_pressed("reload") and weapon_visible and can_shoot and _is_ranged_weapon():
        reload_weapon()
    if Input.is_action_just_pressed("shout"):
        get_tree().call_group("game", "player_shout")

    head.rotation.x = pitch + recoil_offset

func set_crouched(value: bool):
    if player_collision.shape is not CapsuleShape3D:
        return
    var capsule := player_collision.shape as CapsuleShape3D
    is_crouched = value
    if value:
        var crouch_height := 1.2
        capsule.height = crouch_height
        player_collision.position.y = -((standing_capsule_height - crouch_height) * 0.5)
        head.position.y = standing_head_y - 0.48
        camera.position.y = standing_camera_y
    else:
        capsule.height = standing_capsule_height
        player_collision.position.y = 0.0
        head.position.y = standing_head_y
        camera.position.y = standing_camera_y

func _update_chapter3_lean(delta: float) -> void:
    var lean_input: float = float(Input.is_physical_key_pressed(KEY_E)) - float(Input.is_physical_key_pressed(KEY_Q))
    var requested_lean: float = lean_input * CHAPTER3_LEAN_DISTANCE
    var safe_lean: float = requested_lean
    if absf(requested_lean) > 0.001:
        var local_base: Vector3 = camera.position
        local_base.x = chapter3_camera_base_x
        var from: Vector3 = head.to_global(local_base)
        var to: Vector3 = from + head.global_basis.x.normalized() * requested_lean
        var query := PhysicsRayQueryParameters3D.create(from, to)
        query.collision_mask = collision_mask
        query.collide_with_areas = false
        query.exclude = [get_rid()]
        var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
        if not hit.is_empty():
            var free_distance: float = maxf(0.0, from.distance_to(hit.get("position", from)) - 0.12)
            safe_lean = signf(requested_lean) * minf(absf(requested_lean), free_distance)
    chapter3_lean_current = move_toward(chapter3_lean_current, safe_lean, delta * 1.9)
    camera.position.x = chapter3_camera_base_x + chapter3_lean_current
    var roll_target: float = -signf(chapter3_lean_current) * CHAPTER3_LEAN_ROLL
    camera.rotation.z = move_toward(camera.rotation.z, roll_target, delta * 1.6)

func _reset_chapter3_lean(delta: float) -> void:
    chapter3_lean_current = move_toward(chapter3_lean_current, 0.0, delta * 1.9)
    camera.position.x = chapter3_camera_base_x + chapter3_lean_current
    camera.rotation.z = move_toward(camera.rotation.z, 0.0, delta * 1.6)

func can_stand_up() -> bool:
    if standing_capsule == null:
        return true
    var query := PhysicsShapeQueryParameters3D.new()
    query.shape = standing_capsule
    query.transform = global_transform
    query.collision_mask = collision_mask
    query.exclude = [get_rid()]
    return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()

func update_footsteps(delta: float, moving: bool, sprinting: bool):
    if not moving or not is_on_floor() or footstep_sound_pool == null:
        step_timer = 0.0
        return
    walk_cycle += delta * (12.0 if sprinting else (7.2 if is_crouched else 9.0))
    var interval := 0.67 if is_crouched else (0.38 if sprinting else 0.52)
    step_timer += delta
    if step_timer >= interval:
        step_timer -= interval
        footstep_sound_pool.call("play_random_one_shot")

func update_weapon_pose(delta: float, moving: bool):
    if chapter3_active:
        _animate_chapter3_arms(delta, moving)
        return
    if current_weapon_definition == null or not weapon_visible:
        return
    var target_position := current_weapon_definition.ads_position if aim else current_weapon_definition.hip_position
    var target_rotation := current_weapon_definition.ads_rotation_degrees if aim else current_weapon_definition.hip_rotation_degrees
    if reloading:
        target_position += Vector3(0.0, -0.16, 0.0)
        target_rotation += Vector3(0.0, 0.0, 14.0)
    elif moving:
        var sway_scale := 0.25 if aim else (0.55 if is_crouched else 1.0)
        target_position += Vector3(sin(walk_cycle) * 0.012, absf(cos(walk_cycle)) * 0.016, 0.0) * sway_scale
        target_rotation.z += sin(walk_cycle) * 0.8 * sway_scale
    if current_weapon_definition.weapon_id == &"sword" and sword_attack_remaining > 0.0:
        var attack_progress := 1.0 - sword_attack_remaining / SWORD_ATTACK_DURATION
        var windup_position := Vector3(0.10, 0.04, 0.025)
        var strike_position := Vector3(-0.14, -0.09, -0.16)
        var windup_rotation := Vector3(-12.0, -20.0, -28.0)
        var strike_rotation := Vector3(24.0, 34.0, 54.0)
        if attack_progress < 0.18:
            var windup_progress := attack_progress / 0.18
            target_position += windup_position * windup_progress
            target_rotation += windup_rotation * windup_progress
        elif attack_progress < 0.48:
            var strike_progress := (attack_progress - 0.18) / 0.30
            target_position += windup_position.lerp(strike_position, strike_progress)
            target_rotation += windup_rotation.lerp(strike_rotation, strike_progress)
        else:
            var recovery_progress := (attack_progress - 0.48) / 0.52
            target_position += strike_position.lerp(Vector3.ZERO, recovery_progress)
            target_rotation += strike_rotation.lerp(Vector3.ZERO, recovery_progress)
    weapon.position = weapon.position.lerp(target_position, minf(1.0, delta * 14.0))
    weapon.rotation_degrees = weapon.rotation_degrees.lerp(target_rotation, minf(1.0, delta * 14.0))

func toggle_weapon(definition: WeaponDefinition):
    if reloading:
        return
    if current_weapon_definition == definition and weapon_visible:
        weapon_visible = false
        aim = false
        sword_attack_remaining = 0.0
        weapon.visible = false
        return
    equip_weapon(definition)

func equip_weapon(definition: WeaponDefinition):
    if definition == null or not owned_weapons.has(definition):
        return
    current_weapon_definition = definition
    sword_attack_remaining = 0.0
    max_ammo = definition.magazine_capacity
    ammo = int(weapon_ammo.get(definition.weapon_id, definition.magazine_capacity))
    reserve_ammo = int(weapon_reserve_ammo.get(definition.weapon_id, 0))
    var visual_name := "WeaponVisual_%s" % str(definition.weapon_id)
    var visual := weapon.get_node_or_null(visual_name) as Node3D
    if visual == null and definition.visual_scene:
        visual = definition.visual_scene.instantiate() as Node3D
        visual.name = visual_name
        weapon.add_child(visual)
    for child in weapon.get_children():
        if child is Node3D and child != muzzle_flash:
            child.visible = child.name == visual_name
    if chapter3_active:
        weapon.visible = false
        _show_chapter3_weapon(definition)
    else:
        weapon.position = definition.hip_position
        weapon.rotation_degrees = definition.hip_rotation_degrees
    weapon_visible = true
    weapon.visible = not chapter3_active

func _is_ranged_weapon() -> bool:
    if current_weapon_definition == null:
        return false
    return current_weapon_definition.weapon_id == &"ppsh" or current_weapon_definition.weapon_id == &"mp40" or current_weapon_definition.weapon_id == &"ptrd"

func give_ppsh():
    var ppsh := load("res://resources/weapons/ppsh_definition.tres") as WeaponDefinition
    grant_weapon(ppsh)

func grant_weapon(definition: WeaponDefinition):
    if definition == null:
        return
    if not weapon_catalog.has(definition):
        weapon_catalog.append(definition)
    if not owned_weapons.has(definition):
        owned_weapons.append(definition)
        weapon_ammo[definition.weapon_id] = definition.magazine_capacity
        weapon_reserve_ammo[definition.weapon_id] = definition.magazine_capacity * definition.reserve_magazines
    can_shoot = owned_weapons.any(func(owned: WeaponDefinition) -> bool: return owned.weapon_id == &"ppsh")
    equip_weapon(definition)
    if definition.weapon_id == &"ppsh":
        create_weapon_effects(definition)
    if chapter3_active:
        _show_chapter3_weapon(definition)

func begin_chapter3() -> void:
    chapter3_active = true
    var ppsh: WeaponDefinition = load("res://resources/weapons/ppsh_definition.tres") as WeaponDefinition
    if ppsh != null:
        if not weapon_catalog.has(ppsh):
            weapon_catalog.append(ppsh)
        if not owned_weapons.has(ppsh):
            grant_weapon(ppsh)
        if int(weapon_ammo.get(ppsh.weapon_id, 0)) <= 0 and int(weapon_reserve_ammo.get(ppsh.weapon_id, 0)) <= 0:
            weapon_ammo[ppsh.weapon_id] = ppsh.magazine_capacity
            weapon_reserve_ammo[ppsh.weapon_id] = ppsh.magazine_capacity
    can_shoot = true
    _build_chapter3_fps_body()
    if current_weapon_definition == null:
        equip_weapon(ppsh)
    elif owned_weapons.has(current_weapon_definition):
        equip_weapon(current_weapon_definition)
    camera.fov = 78.0
    health = 100.0
    stamina = 100.0

func _build_chapter3_fps_body() -> void:
    if chapter3_body != null:
        chapter3_body.visible = true
        return
    var packed: PackedScene = load("res://assets/props/ww2_soviet_uniform.glb") as PackedScene
    if packed == null:
        push_warning("Chapter 3 first-person soldier rig is unavailable; camera weapon visuals remain active.")
        return
    chapter3_body = packed.instantiate() as Node3D
    chapter3_body.name = "DmitryFPSRig"
    # The imported uniform is already upright in Godot coordinates. Keep its
    # skeleton local up axis aligned with the player and place the body beneath
    # the camera so the weapon hand remains in the FPS view.
    # The Soviet uniform rig is authored facing local +Z. Turn it to face the
    # FPS camera's forward (-Z) direction so its hands and attached weapon stay
    # in front of the near plane instead of behind the camera.
    chapter3_body.rotation = Vector3(0.0, PI, 0.0)
    # Keep the first-person rig low and slightly ahead so it contributes arms
    # and equipment at the lower edge of the view instead of filling the frame.
    chapter3_body.position = Vector3(0.0, -0.9, 0.05)
    chapter3_body.scale = Vector3.ONE * 0.62
    chapter3_body.visible = true
    camera.add_child(chapter3_body)
    _set_visual_layer_recursive(chapter3_body, 2)
    camera.cull_mask |= 2
    chapter3_body_skeleton = chapter3_body.find_child("Skeleton3D", true, false) as Skeleton3D
    if chapter3_body_skeleton == null:
        push_warning("Dmitry's first-person model has no Skeleton3D.")
        return
    for i in chapter3_body_skeleton.get_bone_count():
        var bone_name: String = chapter3_body_skeleton.get_bone_name(i).to_lower()
        chapter3_bone_indices[bone_name] = i
        chapter3_bone_rest_poses[i] = chapter3_body_skeleton.get_bone_pose_rotation(i)
        if bone_name.contains("head") and not bone_name.contains("end"):
            chapter3_body_skeleton.set_bone_pose_scale(i, Vector3.ZERO)
    var right_hand_bone: String = ""
    for bone_name in chapter3_bone_indices.keys():
        if String(bone_name).contains("hand_r") or String(bone_name).contains("hand. r"):
            right_hand_bone = String(bone_name)
            break
    if right_hand_bone == "":
        for bone_name in chapter3_bone_indices.keys():
            if String(bone_name).contains("hand") and String(bone_name).contains("_r"):
                right_hand_bone = String(bone_name)
                break
    if right_hand_bone != "":
        chapter3_hand_mount = BoneAttachment3D.new()
        chapter3_hand_mount.name = "DmitryRightHandWeaponMount"
        chapter3_hand_mount.bone_name = right_hand_bone
        chapter3_body_skeleton.add_child(chapter3_hand_mount)

func _set_visual_layer_recursive(node: Node, layer: int) -> void:
    if node is VisualInstance3D:
        (node as VisualInstance3D).layers = layer
    for child in node.get_children():
        _set_visual_layer_recursive(child, layer)

func _show_chapter3_weapon(definition: WeaponDefinition) -> void:
    if chapter3_hand_mount == null:
        weapon.visible = true
        return
    for key in chapter3_weapon_models.keys():
        var existing: Node3D = chapter3_weapon_models[key] as Node3D
        if existing != null:
            existing.visible = String(key) == String(definition.weapon_id)
    var model: Node3D = chapter3_weapon_models.get(definition.weapon_id) as Node3D
    if model == null and definition.visual_scene != null:
        model = definition.visual_scene.instantiate() as Node3D
        model.name = "HeldWeapon_%s" % String(definition.weapon_id)
        # Imported character rigs keep centimetre-space bone transforms while
        # the weapon scenes are authored at world scale. Compensate that rig
        # scale so the attached mesh remains human-sized in the FPS view.
        var rig_scale_compensation: float = 50.0 if definition.weapon_id == &"mp40" else (100.0 if definition.weapon_id in [&"sword", &"ppsh", &"ptrd"] else 1.0)
        model.scale *= rig_scale_compensation
        chapter3_hand_mount.add_child(model)
        chapter3_weapon_models[definition.weapon_id] = model
    if model != null:
        model.visible = true
        if definition.weapon_id == &"ppsh":
            model.position = Vector3(-0.02, -0.22, -0.16)
            model.rotation_degrees = Vector3(2.0, -90.0, 0.0)
        elif definition.weapon_id == &"mp40":
            model.position = Vector3(-0.02, -0.18, -0.12)
            model.rotation_degrees = Vector3(0.0, -90.0, 0.0)
        elif definition.weapon_id == &"ptrd":
            model.position = Vector3(-0.02, -0.28, -0.28)
            model.rotation_degrees = Vector3(0.0, -90.0, 0.0)
        else:
            model.position = Vector3(-0.02, -0.12, -0.12)
    weapon.visible = false

func _animate_chapter3_arms(delta: float, moving: bool) -> void:
    if chapter3_body_skeleton == null:
        return
    if chapter3_body != null:
        chapter3_body.visible = true
    chapter3_move_phase += delta * (10.5 if moving else 2.0)
    var swing: float = sin(chapter3_move_phase) * (0.055 if moving and not aim else 0.012)
    # On this rig, shoulder rotation around local Z brings both hands together
    # in front of the chest. Rotating around X leaves the arms stretched sideways.
    var shoulder_pose: float = 0.95 if weapon_visible else 0.0
    if aim:
        shoulder_pose += 0.12
    _pose_chapter3_bone(["upperarm_l", "upperarm_le"], Vector3(0.0, 0.0, shoulder_pose + swing))
    _pose_chapter3_bone(["lowerarm_l", "lowerarm_le"], Vector3.ZERO)
    _pose_chapter3_bone(["upperarm_r", "upperarm_ri"], Vector3(0.0, 0.0, -shoulder_pose - swing))
    _pose_chapter3_bone(["lowerarm_r", "lowerarm_ri"], Vector3.ZERO)

func _pose_chapter3_bone(prefixes: Array[String], euler: Vector3) -> void:
    for prefix in prefixes:
        for bone_name_variant in chapter3_bone_indices.keys():
            var bone_name: String = String(bone_name_variant)
            if not bone_name.begins_with(prefix):
                continue
            var index: int = int(chapter3_bone_indices[bone_name_variant])
            var rest_pose: Quaternion = chapter3_bone_rest_poses[index]
            chapter3_body_skeleton.set_bone_pose_rotation(index, rest_pose * Quaternion.from_euler(euler))
            return

func add_weapon_ammo(weapon_id: StringName, amount: int) -> int:
    var definition: WeaponDefinition = null
    for candidate in weapon_catalog:
        if candidate.weapon_id == weapon_id:
            definition = candidate
            break
    if definition == null or not owned_weapons.has(definition) or amount <= 0:
        return 0
    var old_amount: int = int(weapon_reserve_ammo.get(weapon_id, 0))
    weapon_reserve_ammo[weapon_id] = old_amount + amount
    if current_weapon_definition == definition:
        reserve_ammo = int(weapon_reserve_ammo[weapon_id])
    return int(weapon_reserve_ammo[weapon_id]) - old_amount

func take_damage(amount: float, damage_kind: StringName = &"infantry", _attacker: Node = null) -> void:
    if health <= 0.0:
        return
    health = maxf(0.0, health - amount)
    if health <= 0.0:
        var chapter3: Node = get_tree().get_first_node_in_group("chapter3_controller")
        if chapter3 != null:
            chapter3.call("player_killed", damage_kind)

func create_weapon_effects(definition: WeaponDefinition):
    if muzzle_flash == null:
        muzzle_flash = MeshInstance3D.new()
        muzzle_flash.name = "MuzzleFlash"
        var flash_mesh := SphereMesh.new()
        flash_mesh.radius = 0.055
        flash_mesh.height = 0.11
        muzzle_flash.mesh = flash_mesh
        var flash_material := StandardMaterial3D.new()
        flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        flash_material.albedo_color = Color(1.0, 0.55, 0.12, 0.95)
        flash_material.emission_enabled = true
        flash_material.emission = Color(1.0, 0.3, 0.04)
        flash_material.emission_energy_multiplier = 2.5
        muzzle_flash.material_override = flash_material
        muzzle_flash.visible = false
        weapon.add_child(muzzle_flash)
        muzzle_light = OmniLight3D.new()
        muzzle_light.name = "MuzzleLight"
        muzzle_light.light_color = Color(1.0, 0.5, 0.18)
        muzzle_light.omni_range = 3.0
        muzzle_light.light_energy = 0.0
        muzzle_flash.add_child(muzzle_light)
    muzzle_flash.position = definition.muzzle_position

func shoot():
    if not can_shoot or not weapon_visible or reloading or ammo <= 0 or fire_cooldown > 0.0 or not _is_ranged_weapon():
        return
    var game: Node = get_tree().get_first_node_in_group("game")
    if game == null or (game.state != "range" and game.state != "chase" and game.state != "chapter3"):
        return
    if game.state != "chapter3" and current_weapon_definition.weapon_id != &"ppsh":
        return

    fire_cooldown = 1.0 / maxf(current_weapon_definition.rounds_per_second, 0.1)
    ammo -= 1
    weapon_ammo[current_weapon_definition.weapon_id] = ammo
    if current_weapon_definition.weapon_id == &"ppsh":
        create_weapon_effects(current_weapon_definition)
        muzzle_timer = 0.055
        muzzle_flash.visible = true
        muzzle_light.light_energy = 2.0
    recoil_offset += 0.014
    if current_weapon_definition.weapon_id == &"ppsh":
        _queue_ppsh_fire_sound()
    elif current_weapon_definition.fire_sound != null:
        ppsh_single_sound.stream = current_weapon_definition.fire_sound
        ppsh_single_sound.volume_db = -8.0 if current_weapon_definition.weapon_id == &"ptrd" else -3.0
        ppsh_single_sound.play()

    var spread := deg_to_rad(current_weapon_definition.spread_degrees)
    var direction := -camera.global_transform.basis.z
    direction += camera.global_transform.basis.x * randf_range(-spread, spread)
    direction += camera.global_transform.basis.y * randf_range(-spread, spread)
    direction = direction.normalized()
    var ray := PhysicsRayQueryParameters3D.create(camera.global_position, camera.global_position + direction * 120.0)
    ray.exclude = [get_rid()]
    ray.collision_mask = 1
    if game.state == "chase":
        ray.collision_mask |= 4 # Separate Chapter 2 hull/track areas.
    ray.collide_with_areas = true
    var hit := get_world_3d().direct_space_state.intersect_ray(ray)
    if hit and hit.collider.has_method("hit_target"):
        hit.collider.hit_target()
    elif hit and game.state == "chapter3" and hit.collider is Node:
        var target_node: Node = hit.collider as Node
        var damage: float = 105.0 if current_weapon_definition.weapon_id == &"ptrd" else (15.0 if current_weapon_definition.weapon_id == &"mp40" else 17.0)
        var kind: StringName = &"anti_tank" if current_weapon_definition.weapon_id == &"ptrd" else &"infantry"
        if target_node.has_method("receive_projectile"):
            target_node.call("receive_projectile", damage, kind, self)
        elif target_node.has_method("take_damage"):
            target_node.call("take_damage", damage, kind, self)
    get_tree().call_group("game", "weapon_fired")

func reload_weapon():
    if not can_shoot or not weapon_visible or reloading or not _is_ranged_weapon() or ammo >= current_weapon_definition.magazine_capacity or reserve_ammo <= 0:
        return
    reloading = true
    aim = false
    await get_tree().create_timer(current_weapon_definition.reload_duration).timeout
    if not is_inside_tree():
        return
    var needed := current_weapon_definition.magazine_capacity - ammo
    var loaded := mini(needed, reserve_ammo)
    ammo += loaded
    reserve_ammo -= loaded
    weapon_ammo[current_weapon_definition.weapon_id] = ammo
    weapon_reserve_ammo[current_weapon_definition.weapon_id] = reserve_ammo
    reloading = false
