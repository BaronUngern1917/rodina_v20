extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	get_root().size = Vector2i(1280, 720)
	var world := Node3D.new()
	get_root().add_child(world)
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#aeb6bd")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.9
	env_node.environment = env
	world.add_child(env_node)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40.0, -25.0, 0.0)
	world.add_child(light)
	var floor := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(12.0, 8.0)
	floor.mesh = plane
	world.add_child(floor)
	var variants := [
		["REST", Vector3.ZERO, Vector3.ZERO],
		["X RAISE", Vector3(-0.94, 0.0, 0.0), Vector3(-0.50, 0.0, 0.0)],
		["Y SWING", Vector3(0.0, -1.1, 0.0), Vector3.ZERO],
		["Z SWING", Vector3(0.0, 0.0, 1.1), Vector3.ZERO]
	]
	var offsets := [-3.6, -1.2, 1.2, 3.6]
	for index in variants.size():
		var variant: Array = variants[index]
		var model := (load("res://assets/props/ww2_soviet_uniform.glb") as PackedScene).instantiate() as Node3D
		world.add_child(model)
		model.scale = Vector3.ONE * 0.72
		model.rotation.y = PI
		model.position = Vector3(offsets[index], 0.0, 0.0)
		var skeleton := model.find_child("Skeleton3D", true, false) as Skeleton3D
		if skeleton != null:
			for bone_name in ["upperarm_l_09", "upperarm_r_030", "lowerarm_l_011", "lowerarm_r_032"]:
				var bone_index := skeleton.find_bone(bone_name)
				if bone_index < 0:
					continue
				var euler: Vector3 = variant[1] if bone_name.begins_with("upper") else variant[2]
				if bone_name.contains("_r_"):
					euler.y = -euler.y
					euler.z = -euler.z
				skeleton.set_bone_pose_rotation(bone_index, skeleton.get_bone_rest(bone_index).basis.get_rotation_quaternion() * Quaternion.from_euler(euler))
		var label := Label3D.new()
		label.text = String(variant[0])
		label.position = Vector3(offsets[index], 2.1, 0.0)
		world.add_child(label)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 5.2
	camera.position = Vector3(0.0, 2.2, -10.0)
	world.add_child(camera)
	camera.look_at(Vector3(0.0, 0.9, 0.0), Vector3.UP)
	camera.current = true
	await create_timer(1.2).timeout
	get_root().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://__chapter3_arm_pose_matrix.png"))
	quit()
