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
var fire_sound_player: AudioStreamPlayer3D
var step_sound_player: AudioStreamPlayer3D

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
    weapon.visible = false
    fork.visible = false
    camera.fov = 75.0

func setup_player_audio():
    fire_sound_player = AudioStreamPlayer3D.new()
    fire_sound_player.name = "WeaponFireSound"
    fire_sound_player.volume_db = -3.0
    fire_sound_player.max_distance = 32.0
    fire_sound_player.unit_size = 5.0
    camera.add_child(fire_sound_player)

    step_sound_player = AudioStreamPlayer3D.new()
    step_sound_player.name = "FootstepSound"
    step_sound_player.stream = load("res://assets/audio/fast-walking-on-a-concrete-surface.mp3") as AudioStream
    step_sound_player.position = Vector3(0.0, -0.75, 0.0)
    step_sound_player.volume_db = -12.0
    step_sound_player.max_distance = 18.0
    step_sound_player.unit_size = 3.0
    add_child(step_sound_player)

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
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta):
    fire_cooldown = maxf(0.0, fire_cooldown - delta)
    recoil_offset = move_toward(recoil_offset, 0.0, delta * 0.09)

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
    aim = weapon_visible and can_shoot and not reloading and Input.is_action_pressed("aim")
    update_footsteps(delta, actual_movement, sprinting)
    update_weapon_pose(delta, actual_movement)
    if muzzle_timer > 0.0:
        muzzle_timer -= delta
        if muzzle_flash:
            muzzle_flash.visible = muzzle_timer > 0.0
        if muzzle_light:
            muzzle_light.light_energy = 2.0 if muzzle_timer > 0.0 else 0.0

    if weapon_visible and can_shoot and not reloading and Input.is_action_pressed("shoot"):
        shoot()
    if Input.is_action_just_pressed("reload") and weapon_visible and can_shoot:
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
    if not moving or not is_on_floor() or step_sound_player == null or step_sound_player.stream == null:
        step_timer = 0.0
        return
    walk_cycle += delta * (12.0 if sprinting else (7.2 if is_crouched else 9.0))
    var interval := 0.67 if is_crouched else (0.38 if sprinting else 0.52)
    step_timer += delta
    if step_timer >= interval:
        step_timer -= interval
        step_sound_player.play()

func update_weapon_pose(delta: float, moving: bool):
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
    weapon.position = weapon.position.lerp(target_position, minf(1.0, delta * 14.0))
    weapon.rotation_degrees = weapon.rotation_degrees.lerp(target_rotation, minf(1.0, delta * 14.0))

func toggle_weapon(definition: WeaponDefinition):
    if reloading:
        return
    if current_weapon_definition == definition and weapon_visible:
        weapon_visible = false
        aim = false
        weapon.visible = false
        return
    equip_weapon(definition)

func equip_weapon(definition: WeaponDefinition):
    if definition == null or not owned_weapons.has(definition):
        return
    current_weapon_definition = definition
    max_ammo = definition.magazine_capacity
    ammo = int(weapon_ammo.get(definition.weapon_id, definition.magazine_capacity))
    reserve_ammo = int(weapon_reserve_ammo.get(definition.weapon_id, 0))
    if fire_sound_player:
        fire_sound_player.stream = definition.fire_sound
    var visual_name := "WeaponVisual_%s" % str(definition.weapon_id)
    var visual := weapon.get_node_or_null(visual_name) as Node3D
    if visual == null and definition.visual_scene:
        visual = definition.visual_scene.instantiate() as Node3D
        visual.name = visual_name
        weapon.add_child(visual)
    for child in weapon.get_children():
        if child is Node3D and child != muzzle_flash:
            child.visible = child.name == visual_name
    weapon.position = definition.hip_position
    weapon.rotation_degrees = definition.hip_rotation_degrees
    weapon_visible = true
    weapon.visible = true

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
    can_shoot = not owned_weapons.is_empty()
    equip_weapon(definition)
    create_weapon_effects(definition)

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
    if not can_shoot or not weapon_visible or reloading or ammo <= 0 or fire_cooldown > 0.0 or current_weapon_definition == null:
        return
    var game = get_tree().get_first_node_in_group("game")
    if game == null or game.state != "range":
        return

    fire_cooldown = 1.0 / maxf(current_weapon_definition.rounds_per_second, 0.1)
    ammo -= 1
    weapon_ammo[current_weapon_definition.weapon_id] = ammo
    create_weapon_effects(current_weapon_definition)
    muzzle_timer = 0.055
    muzzle_flash.visible = true
    muzzle_light.light_energy = 2.0
    recoil_offset += 0.014
    if fire_sound_player and fire_sound_player.stream and not fire_sound_player.playing:
        fire_sound_player.play()

    var spread := deg_to_rad(current_weapon_definition.spread_degrees)
    var direction := -camera.global_transform.basis.z
    direction += camera.global_transform.basis.x * randf_range(-spread, spread)
    direction += camera.global_transform.basis.y * randf_range(-spread, spread)
    direction = direction.normalized()
    var ray := PhysicsRayQueryParameters3D.create(camera.global_position, camera.global_position + direction * 120.0)
    ray.exclude = [get_rid()]
    var hit := get_world_3d().direct_space_state.intersect_ray(ray)
    if hit and hit.collider.has_method("hit_target"):
        hit.collider.hit_target()
    get_tree().call_group("game", "weapon_fired")

func reload_weapon():
    if not can_shoot or not weapon_visible or reloading or current_weapon_definition == null or ammo >= current_weapon_definition.magazine_capacity or reserve_ammo <= 0:
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
