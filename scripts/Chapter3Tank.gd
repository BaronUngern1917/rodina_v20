extends AnimatableBody3D

var controller: Node
var model_path: String = ""
var vehicle_kind: StringName = &"tiger"
var health: float = 300.0
var maximum_health: float = 300.0
var drive_speed: float = 1.25
var fire_cooldown: float = 8.0
var wrecked: bool = false
var visual: Node3D
var skeleton: Skeleton3D
var turret_bone: int = -1
var barrel_bone: int = -1
var _turret_pose: Quaternion = Quaternion.IDENTITY

func configure(chapter_controller: Node, kind: StringName, scene_path: String, at: Vector3, scene_scale: float) -> void:
	controller = chapter_controller
	vehicle_kind = kind
	model_path = scene_path
	name = "%s_Chapter3Tank" % String(kind)
	position = at
	collision_layer = 1
	collision_mask = 1
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4.3, 2.25, 7.0) if kind == &"tiger" else Vector3(4.0, 2.0, 5.4)
	collider.shape = box
	collider.position.y = box.size.y * 0.5
	add_child(collider)
	var packed: PackedScene = load(scene_path) as PackedScene
	if packed == null:
		push_warning("Chapter 3 tank asset is missing: %s" % scene_path)
		return
	visual = packed.instantiate() as Node3D
	visual.name = "VehicleModel"
	visual.scale = Vector3.ONE * scene_scale
	visual.rotation.y = PI
	add_child(visual)
	skeleton = visual.find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton != null:
		for i in skeleton.get_bone_count():
			var bone_name: String = skeleton.get_bone_name(i).to_lower()
			if bone_name.contains("turret") and turret_bone < 0:
				turret_bone = i
				_turret_pose = skeleton.get_bone_pose_rotation(i)
			if bone_name.contains("cannon") and barrel_bone < 0:
				barrel_bone = i
	health = 320.0 if kind == &"tiger" else 190.0
	maximum_health = health
	fire_cooldown = randf_range(4.0, 8.0)
	add_to_group("chapter3_tanks")

func advance_frontline(target_z: float, delta: float) -> void:
	if wrecked:
		return
	position.z = move_toward(position.z, target_z, drive_speed * delta)
	position.x = sin(Time.get_ticks_msec() * 0.00055 + float(get_instance_id() % 17)) * 1.25
	if is_instance_valid(controller):
		var player: CharacterBody3D = controller.get("player") as CharacterBody3D
		if player != null and turret_bone >= 0 and skeleton != null:
			var local_target: Vector3 = to_local(player.global_position)
			var yaw: float = atan2(local_target.x, -local_target.z)
			var target_rotation: Quaternion = Quaternion(Vector3.UP, yaw)
			skeleton.set_bone_pose_rotation(turret_bone, _turret_pose.slerp(target_rotation, delta * 0.65))

func should_fire(delta: float) -> bool:
	if wrecked:
		return false
	fire_cooldown -= delta
	if fire_cooldown > 0.0:
		return false
	fire_cooldown = randf_range(7.5, 11.0) if vehicle_kind == &"tiger" else randf_range(10.0, 14.0)
	return true

func receive_projectile(amount: float, kind: StringName, attacker: Node = null) -> void:	
	if wrecked:
		return
	if kind != &"anti_tank" and kind != &"artillery" and kind != &"explosive":
		if amount < 45.0:
			if is_instance_valid(controller):
				controller.call("play_chapter3_sound", "res://assets/audio/bullet_hits_the_tank.mp3", global_position, -9.0)
			return
	health -= amount
	if health <= 0.0:
		wrecked = true
		remove_from_group("chapter3_tanks")
		collision_layer = 1
		if visual != null:
			visual.rotation_degrees.z = -6.0
		if is_instance_valid(controller):
			controller.call("play_chapter3_sound", "res://assets/audio/explosion-with-fire-flame.mp3", global_position, -4.0)
			controller.call("on_tank_destroyed", self, attacker)

func take_damage(amount: float, kind: StringName = &"infantry", attacker: Node = null) -> void:
	receive_projectile(amount, kind, attacker)
