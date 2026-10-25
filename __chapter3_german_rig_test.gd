extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	get_root().size = Vector2i(1280, 720)
	var world := Node3D.new()
	get_root().add_child(world)
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#aeb6bd")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color.WHITE
	environment.ambient_light_energy = 0.8
	environment_node.environment = environment
	world.add_child(environment_node)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42.0, -30.0, 0.0)
	world.add_child(sun)
	var floor := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(8.0, 8.0)
	floor.mesh = plane
	world.add_child(floor)
	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_color = Color("#5b5e4d")
	floor.material_override = ground_material
	var script := load("res://scripts/Chapter3Combatant.gd") as Script
	var soldier := script.new() as CharacterBody3D
	world.add_child(soldier)
	soldier.set_physics_process(false)
	soldier.configure(world, &"german", &"rifle", Vector3.ZERO)
	soldier.call("_animate_soldier_rig", true, 0.0)
	var skeleton := soldier.find_child("Skeleton3D", true, false) as Skeleton3D
	var weapon_mount := soldier.find_child("CombatWeaponMount", true, false) as BoneAttachment3D
	print("GERMAN_RIG_CHECK bones=", skeleton.get_bone_count() if skeleton != null else 0, " weapon_bone=", weapon_mount.bone_name if weapon_mount != null else "missing")
	var combat_weapon := soldier.find_child("CombatWeapon", true, false) as Node3D
	print("GERMAN_WEAPON_CHECK visible=", combat_weapon.visible if combat_weapon != null else false, " global=", combat_weapon.global_transform if combat_weapon != null else Transform3D.IDENTITY)
	for bone_name in ["rightshoulder_044", "rightarm_045", "rightforearm_00", "righthand_047", "rightweapon_064", "leftshoulder_018", "leftarm_019", "leftforearm_020"]:
		var bone_index: int = skeleton.find_bone(bone_name) if skeleton != null else -1
		if bone_index >= 0:
			print("GERMAN_BONE ", bone_name, " rest=", skeleton.get_bone_rest(bone_index), " global=", skeleton.get_bone_global_pose(bone_index))
	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 1.65, -4.4)
	world.add_child(camera)
	camera.look_at(Vector3(0.0, 1.0, 0.0), Vector3.UP)
	camera.current = true
	await create_timer(1.3).timeout
	var screenshot := get_root().get_texture().get_image()
	var error := screenshot.save_png(ProjectSettings.globalize_path("res://__chapter3_german_rig_test.png"))
	print("GERMAN_RIG_CAPTURE size=", screenshot.get_size(), " error=", error)
	quit()
