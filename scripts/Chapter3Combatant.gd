extends CharacterBody3D

const GRAVITY: float = 18.0
const GERMAN_INFANTRY_RIGS: Array[String] = [
	"res://assets/props/nazi_engineer_-_wolf._new_colossus.glb",
]
const GERMAN_INFANTRY_MIN_BONES: int = 60

var controller: Node
var faction: StringName = &"german"
var role: StringName = &"rifle"
var health: float = 80.0
var maximum_health: float = 80.0
var target: Node3D
var dead: bool = false
var attack_cooldown: float = 0.0
var think_cooldown: float = 0.0
var corpse_time: float = 0.0
var move_phase: float = 0.0
var origin_y: float = 0.0
var desired_position: Vector3 = Vector3.ZERO
var visual_root: Node3D
var skeleton: Skeleton3D
var _bone_indices: Dictionary = {}
var _bone_rest_poses: Dictionary = {}
var _pose_bone_indices: Dictionary = {}
var _home_position: Vector3 = Vector3.ZERO
var _shot_number: int = 0
var rigged: bool = false

func configure(chapter_controller: Node, side: StringName, soldier_role: StringName, spawn_position: Vector3) -> void:
	controller = chapter_controller
	faction = side
	role = soldier_role
	name = "%s_%s" % [str(side), str(soldier_role)]
	position = spawn_position
	_home_position = spawn_position
	add_to_group("chapter3_combatants")
	collision_layer = 1
	collision_mask = 1
	var capsule := CollisionShape3D.new()
	var capsule_shape := CapsuleShape3D.new()
	capsule_shape.radius = 0.34 if role != &"dog" else 0.26
	capsule_shape.height = 1.65 if role != &"dog" else 0.8
	capsule.shape = capsule_shape
	capsule.position.y = capsule_shape.height * 0.5
	add_child(capsule)
	visual_root = Node3D.new()
	visual_root.name = "ProceduralAnimatedVisual"
	add_child(visual_root)
	_build_visual()
	_build_weapon_visual()
	health = 35.0 if role == &"dog" else (125.0 if role == &"heavy" else 78.0)
	maximum_health = health
	attack_cooldown = randf_range(0.25, 2.0)
	think_cooldown = randf_range(0.05, 0.65)
	origin_y = position.y
	desired_position = position

func _build_visual() -> void:
	var model_path: String = GERMAN_INFANTRY_RIGS[0]
	var model_scale: float = 1.0
	if role == &"dog":
		model_path = "res://assets/characters/dogs/cod_ghosts_riley.glb"
		model_scale = 0.05
	elif faction == &"soviet":
		model_path = "res://assets/props/ww2_soviet_uniform.glb"
		model_scale = 1.0
	var packed: PackedScene = load(model_path) as PackedScene
	if packed == null:
		push_warning("Chapter 3 combatant asset is missing: %s" % model_path)
		return
	var model: Node3D = packed.instantiate() as Node3D
	model.name = "SoldierModel"
	model.scale = Vector3.ONE * model_scale
	if role == &"dog":
		model.rotation.y = PI
	elif faction == &"soviet":
		# The local Soviet uniform rig is already upright; only turn it to the
		# CharacterBody's forward axis so targeting rotates the full soldier.
		model.rotation.y = PI
		model.position.y = 0.05
	else:
		# The German rig is authored facing local +X. Align it to Godot's -Z
		# forward axis so CharacterBody3D.look_at() turns the soldier and weapon
		# toward the combat target instead of presenting a side-on model.
		model.rotation.y = PI * 0.5
	visual_root.add_child(model)
	_disable_imported_collisions(model)
	skeleton = _find_primary_skeleton(model)
	if skeleton != null:
		rigged = skeleton.get_bone_count() > 0
		if faction == &"german" and role != &"dog":
			rigged = _has_soldier_rig(skeleton)
		model.set_meta("rig_bone_count", skeleton.get_bone_count())
		model.set_meta("is_rigged_infantry", rigged)
		model.set_meta("rig_animation", "procedural")
		_cache_procedural_bones()
		if faction == &"german" and role != &"dog" and not rigged:
			push_warning("German infantry rig is incomplete (%d bones): %s" % [skeleton.get_bone_count(), model_path])
	else:
		push_error("Chapter 3 combatant has no usable Skeleton3D: %s" % model_path)
		if faction == &"german":
			push_error("German infantry must use one of the rigged local infantry assets: %s" % str(GERMAN_INFANTRY_RIGS))

func _find_primary_skeleton(model: Node3D) -> Skeleton3D:
	var best: Skeleton3D
	for node in model.find_children("*", "Skeleton3D", true, false):
		var candidate: Skeleton3D = node as Skeleton3D
		if candidate != null and (best == null or candidate.get_bone_count() > best.get_bone_count()):
			best = candidate
	return best

func _has_soldier_rig(candidate: Skeleton3D) -> bool:
	if candidate.get_bone_count() < GERMAN_INFANTRY_MIN_BONES:
		return false
	var left_arm: bool = _find_bone_name("leftarm") != "" or _find_bone_name("bip01lupperarm") != ""
	var right_arm: bool = _find_bone_name("rightarm") != "" or _find_bone_name("bip01rupperarm") != ""
	var left_forearm: bool = _find_bone_name("leftforearm") != "" or _find_bone_name("bip01lforearm") != ""
	var right_forearm: bool = _find_bone_name("rightforearm") != "" or _find_bone_name("bip01rforearm") != ""
	var right_hand: bool = _find_bone_name("righthand") != "" or _find_bone_name("bip01rhand") != ""
	return left_arm and right_arm and left_forearm and right_forearm and right_hand

func _disable_imported_collisions(node: Node) -> void:
	# Imported character GLBs may carry authoring collision helpers. The capsule
	# on this CharacterBody3D is the sole gameplay collider for an NPC.
	if node is CollisionObject3D:
		var collision_object := node as CollisionObject3D
		collision_object.collision_layer = 0
		collision_object.collision_mask = 0
		collision_object.process_mode = Node.PROCESS_MODE_DISABLED
	for child in node.get_children():
		_disable_imported_collisions(child)

func _cache_procedural_bones() -> void:
	_pose_bone_indices.clear()
	for i in skeleton.get_bone_count():
		var bone_name: String = skeleton.get_bone_name(i).to_lower()
		_bone_indices[bone_name] = i
		_bone_rest_poses[i] = skeleton.get_bone_pose_rotation(i)

func _build_weapon_visual() -> void:
	if role == &"dog":
		return
	var weapon_path: String = "res://assets/weapons/ptrd_anti-_tank_rifle.glb" if role == &"ptrd" else ("res://assets/weapons/ppsh-41.glb" if faction == &"soviet" else "res://assets/props/ww2_german_mp40.glb")
	var packed: PackedScene = load(weapon_path) as PackedScene
	if packed == null:
		return
	var weapon: Node3D = packed.instantiate() as Node3D
	weapon.name = "CombatWeapon"
	var weapon_scale: float = 15.0 if role == &"ptrd" else (0.16 if faction == &"soviet" else 60.0)
	weapon.scale = Vector3.ONE * weapon_scale
	var weapon_mount: BoneAttachment3D
	if skeleton != null:
		var mount_bone: String = _find_bone_name("rightweapon") if faction == &"german" else _find_bone_name("hand_r")
		if mount_bone == "" and faction == &"german":
			mount_bone = _find_bone_name("righthand")
		if mount_bone == "" and faction == &"german":
			mount_bone = _find_bone_name("bip01rhand")
		if mount_bone != "":
			weapon_mount = BoneAttachment3D.new()
			weapon_mount.name = "CombatWeaponMount"
			weapon_mount.bone_name = mount_bone
			skeleton.add_child(weapon_mount)
	if weapon_mount != null:
		weapon.position = Vector3.ZERO
		weapon.rotation_degrees = Vector3(0.0, 90.0, 18.0)
		weapon_mount.add_child(weapon)
	else:
		weapon.position = Vector3(0.3, 1.04, -0.12)
		weapon.rotation_degrees = Vector3(0.0, 90.0, 5.0)
		visual_root.add_child(weapon)

func _find_bone_name(fragment: String) -> String:
	if skeleton == null:
		return ""
	var needle: String = fragment.to_lower()
	var normalized_needle: String = needle.replace("_", "").replace(".", "").replace("-", "").replace(" ", "")
	for index in skeleton.get_bone_count():
		var candidate: String = skeleton.get_bone_name(index)
		var normalized_candidate: String = candidate.to_lower().replace("_", "").replace(".", "").replace("-", "").replace(" ", "")
		if candidate.to_lower().contains(needle) or normalized_candidate.contains(normalized_needle):
			return candidate
	return ""

func _physics_process(delta: float) -> void:
	if dead:
		corpse_time += delta
		if corpse_time > 90.0:
			queue_free()
		return
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	think_cooldown -= delta
	move_phase += delta
	if think_cooldown <= 0.0:
		think_cooldown = 0.34 + randf_range(0.0, 0.18)
		_choose_target()
		_update_intention()
	_move_tactically(delta)
	_animate(delta)

func _choose_target() -> void:
	if not is_instance_valid(controller):
		return
	target = controller.call("find_target_for", self) as Node3D

func _update_intention() -> void:
	if not is_instance_valid(target):
		desired_position = _home_position
		return
	var distance: float = global_position.distance_to(target.global_position)
	if role == &"dog":
		desired_position = target.global_position
		return
	if distance > 13.0:
		desired_position = controller.call("pick_cover_approach", global_position, target.global_position, faction)
	else:
		var away: Vector3 = (global_position - target.global_position).normalized()
		var flank: Vector3 = Vector3(away.z, 0.0, -away.x) * sin(move_phase * 0.63 + float(get_instance_id() % 13)) * 2.0
		desired_position = global_position + away * 2.2 + flank
	if faction == &"german" and global_position.z > 126.0:
		desired_position.z = minf(desired_position.z, 126.0)

func _move_tactically(delta: float) -> void:
	if not is_instance_valid(target):
		velocity.x = move_toward(velocity.x, 0.0, 5.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 5.0 * delta)
		move_and_slide()
		return
	var to_goal: Vector3 = desired_position - global_position
	to_goal.y = 0.0
	var distance: float = to_goal.length()
	var attack_distance: float = 1.35 if role == &"dog" else 7.0
	var speed: float = 6.2 if role == &"dog" else (2.7 if faction == &"soviet" else 3.1)
	var move_direction: Vector3 = to_goal.normalized() if distance > attack_distance else Vector3.ZERO
	velocity.x = move_toward(velocity.x, move_direction.x * speed, 7.0 * delta)
	velocity.z = move_toward(velocity.z, move_direction.z * speed, 7.0 * delta)
	move_and_slide()
	if move_direction.length_squared() > 0.01:
		var look_direction: Vector3 = move_direction
		look_at(global_position + look_direction, Vector3.UP)
	_try_attack()

func _try_attack() -> void:
	if attack_cooldown > 0.0 or not is_instance_valid(target) or target == self:
		return
	var distance: float = global_position.distance_to(target.global_position)
	if role == &"ptrd" and faction == &"soviet" and target.is_in_group("chapter3_tanks"):
		if distance <= 85.0:
			attack_cooldown = randf_range(5.0, 7.5)
			var muzzle: Vector3 = global_position + Vector3(0.0, 1.2, 0.0)
			var target_point: Vector3 = target.global_position + Vector3(0.0, 1.1, 0.0)
			controller.call("draw_tracer", muzzle, target_point, faction)
			controller.call("launch_projectile", muzzle, target_point - muzzle, 96.0, 95.0, 1.0, &"anti_tank", self)
		return
	if role == &"dog":
		if distance <= 1.55:
			attack_cooldown = 0.76
			controller.call("play_chapter3_sound", "res://assets/audio/audiopapkin-german-shepherd-barking-302356.mp3", global_position, -7.0)
			target.call("take_damage", 9.0, &"bite", self)
		return
	if distance > 36.0:
		return
	attack_cooldown = randf_range(1.35, 2.7) if faction == &"german" else randf_range(1.7, 3.1)
	var muzzle: Vector3 = global_position + Vector3(0.0, 1.12, 0.0)
	var target_point: Vector3 = target.global_position + Vector3(0.0, 0.95, 0.0)
	controller.call("draw_tracer", muzzle, target_point, faction)
	if controller.call("has_clear_fire_line", muzzle, target_point, self, target):
		var hit_chance: float = 0.72 if distance < 16.0 else 0.46
		if randf() <= hit_chance:
			target.call("take_damage", 5.0 if role == &"rifle" else 8.0, &"infantry", self)
	_shot_number += 1
	if _shot_number % 3 == 0:
		controller.call("play_chapter3_sound", "res://assets/audio/sound_of_machinegun.mp3", global_position, -23.0)

func take_damage(amount: float, damage_kind: StringName = &"infantry", attacker: Node = null) -> void:
	if dead:
		return
	if damage_kind == &"explosive":
		amount *= 1.4
	health -= amount
	if attacker is Node3D and is_instance_valid(attacker):
		target = attacker as Node3D
		think_cooldown = 0.0
	if health <= 0.0:
		die()

func receive_projectile(amount: float, kind: StringName, attacker: Node = null) -> void:
	take_damage(amount, kind, attacker)

func die() -> void:
	if dead:
		return
	dead = true
	health = 0.0
	velocity = Vector3.ZERO
	collision_layer = 0
	collision_mask = 0
	remove_from_group("chapter3_combatants")
	rotation.x = 0.0
	visual_root.rotation.x = -PI * 0.5
	if is_instance_valid(controller):
		controller.call("on_combatant_died", self)

func _animate(delta: float) -> void:
	if visual_root == null:
		return
	var moving: bool = Vector2(velocity.x, velocity.z).length() > 0.55
	var crouch: float = 0.12 if faction == &"soviet" else 0.0
	if role != &"dog":
		visual_root.position.y = crouch + (0.035 * sin(move_phase * 10.0) if moving else 0.014 * sin(move_phase * 2.3))
	else:
		visual_root.position.y = 0.025 * sin(move_phase * 13.0)
	if skeleton == null:
		return
	if role == &"dog":
		_animate_dog_rig()
	else:
		_animate_soldier_rig(moving, delta)

func _animate_soldier_rig(moving: bool, _delta: float) -> void:
	var stride: float = sin(move_phase * 9.0) * (0.18 if moving else 0.035)
	var firing: float = sin(move_phase * 19.0) * 0.035 if attack_cooldown > 1.15 else 0.0
	# Preserve the model's authored ready pose, then add small rig-driven motion
	# so movement and bursts are visible without pulling either hand off the gun.
	_pose_first_matching(["upperarm_l", "upperarm_le", "leftarm_", "bip01lupperarm"], Vector3(-0.16 + stride * 0.12, 0.0, -0.035))
	_pose_first_matching(["lowerarm_l", "lowerarm_le", "forearm_l", "leftforearm", "bip01lforearm"], Vector3(-0.14, 0.0, -0.025))
	_pose_first_matching(["upperarm_r", "upperarm_ri", "rightarm_", "bip01rupperarm"], Vector3(-0.18 - stride * 0.12, 0.0, 0.035))
	_pose_first_matching(["lowerarm_r", "lowerarm_ri", "forearm_r", "rightforearm", "bip01rforearm"], Vector3(-0.16 + firing, 0.0, 0.025))
	_pose_first_matching(["spine_01", "spinelower", "spine_04", "bip01spine1"], Vector3(0.03, 0.0, 0.0))
	_pose_first_matching(["leftupleg", "thigh_l", "bip01lthigh"], Vector3(stride, 0.0, 0.0))
	_pose_first_matching(["rightupleg", "thigh_r", "bip01rthigh"], Vector3(-stride, 0.0, 0.0))

func _animate_dog_rig() -> void:
	var leg_swing: float = sin(move_phase * 12.0) * 0.45
	_pose_first_matching(["front_thigh.l"], Vector3(leg_swing, 0.0, 0.0))
	_pose_first_matching(["front_thigh.r"], Vector3(-leg_swing, 0.0, 0.0))
	_pose_first_matching(["thigh.l"], Vector3(-leg_swing, 0.0, 0.0))
	_pose_first_matching(["thigh.r"], Vector3(leg_swing, 0.0, 0.0))

func _pose_first_matching(candidates: Array[String], euler: Vector3) -> void:
	if candidates.is_empty():
		return
	var cache_key: String = candidates[0]
	var bone_index: int = int(_pose_bone_indices.get(cache_key, -2))
	if bone_index == -2:
		bone_index = -1
		for candidate in candidates:
			var normalized_candidate: String = candidate.to_lower().replace("_", "").replace(".", "").replace("-", "").replace(" ", "")
			for bone_name_variant in _bone_indices.keys():
				var bone_name: String = String(bone_name_variant)
				var normalized_bone_name: String = bone_name.replace("_", "").replace(".", "").replace("-", "").replace(" ", "")
				if not bone_name.begins_with(candidate) and not normalized_bone_name.contains(normalized_candidate):
					continue
				bone_index = int(_bone_indices[bone_name_variant])
				break
			if bone_index >= 0:
				break
		_pose_bone_indices[cache_key] = bone_index
	if bone_index < 0:
		return
	var rest_pose: Quaternion = _bone_rest_poses[bone_index]
	var pose: Quaternion = rest_pose * Quaternion.from_euler(euler)
	skeleton.set_bone_pose_rotation(bone_index, pose)
