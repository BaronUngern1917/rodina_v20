extends CharacterBody3D

@export var walk_speed := 4.2
@export var sprint_speed := 7.2
@export var mouse_sensitivity := 0.0024
var health := 100.0
var stamina := 100.0
var gravity := 18.0
var pitch := 0.0
var can_shoot := false
var ammo := 35
var max_ammo := 35
var reloading := false
var aim := false
var weapon_visible := false

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var weapon: Node3D = $Head/Camera3D/Weapon
@onready var fork: Node3D = $Head/Camera3D/Fork

func _ready():
    setup_weapon()

func setup_weapon():
    for placeholder in ["WeaponBody", "WeaponStock", "WeaponBarrel", "WeaponMagazine"]:
        get_node("Head/Camera3D/Weapon/" + placeholder).visible = false
    var ppsh_visual := load("res://scenes/PPSH.tscn").instantiate() as Node3D
    weapon.add_child(ppsh_visual)
    weapon.visible = false
    fork.visible = false

func _unhandled_input(event):
    if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
        rotate_y(-event.relative.x * mouse_sensitivity)
        pitch = clamp(pitch - event.relative.y * mouse_sensitivity, -1.45, 1.45)
        head.rotation.x = pitch
    if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    if event is InputEventMouseButton and event.pressed:
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta):
    if not is_on_floor():
        velocity.y -= gravity * delta
    var input_vec := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
    var dir := (transform.basis * Vector3(input_vec.x,0,input_vec.y)).normalized()
    var sprinting := Input.is_action_pressed("sprint") and input_vec.length() > 0.1 and stamina > 0.0
    var speed := sprint_speed if sprinting else walk_speed
    if sprinting: stamina = max(0.0, stamina - 25.0 * delta)
    else: stamina = min(100.0, stamina + 18.0 * delta)
    velocity.x = move_toward(velocity.x, dir.x * speed, 22.0 * delta)
    velocity.z = move_toward(velocity.z, dir.z * speed, 22.0 * delta)
    move_and_slide()
    aim = Input.is_action_pressed("aim") and can_shoot
    camera.fov = lerp(camera.fov, 55.0 if aim else 75.0, min(1.0,delta*12.0))
    if can_shoot and Input.is_action_pressed("shoot") and not reloading:
        shoot()
    if Input.is_action_just_pressed("reload") and can_shoot:
        reload_weapon()
    if Input.is_action_just_pressed("shout"):
        get_tree().call_group("game","player_shout")

func give_ppsh():
    can_shoot = true
    weapon.visible = true
    ammo = max_ammo

func shoot():
    if ammo <= 0: return
    var game = get_tree().get_first_node_in_group("game")
    if game == null or game.state != "range":
        return
    ammo -= 1
    var ray := PhysicsRayQueryParameters3D.create(camera.global_position, camera.global_position + -camera.global_transform.basis.z * 120.0)
    ray.exclude = [self]
    var hit := get_world_3d().direct_space_state.intersect_ray(ray)
    if hit and hit.collider.has_method("hit_target"):
        hit.collider.hit_target()
    get_tree().call_group("game","weapon_fired")

func reload_weapon():
    if reloading or ammo == max_ammo: return
    reloading = true
    await get_tree().create_timer(1.1).timeout
    ammo = max_ammo
    reloading = false
