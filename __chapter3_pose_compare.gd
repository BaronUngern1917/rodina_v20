extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	get_root().size = Vector2i(1600, 900)
	var world := Node3D.new()
	get_root().add_child(world)
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#adb5bc")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.8
	env_node.environment = env
	world.add_child(env_node)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40.0, -25.0, 0.0)
	world.add_child(light)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(16.0, 16.0)
	ground.mesh = plane
	var ground_mat := StandardMaterial3D.new()
	ground_mat.albedo_color = Color("#626553")
	ground.material_override = ground_mat
	world.add_child(ground)
	var tests: Array[Dictionary] = [
		{"name":"x-", "rotation":Vector3(-1.1, 0.0, 0.0)},
		{"name":"y+", "rotation":Vector3(0.0, 1.1, 0.0)},
		{"name":"z-", "rotation":Vector3(0.0, 0.0, -1.1)}
	]
	var script := load("res://scripts/Chapter3Combatant.gd") as Script
	for i in tests.size():
		var soldier := script.new() as CharacterBody3D
		soldier.set_physics_process(false)
		soldier.position = Vector3(-2.3 + float(i) * 2.3, 0.0, 0.0)
		world.add_child(soldier)
		soldier.configure(world, &"soviet", &"rifle", soldier.position)
		soldier.set_physics_process(false)
		var right_arm_prefix: Array[String] = ["upperarm_r"]
		var right_forearm_prefix: Array[String] = ["lowerarm_r"]
		var left_arm_prefix: Array[String] = ["upperarm_l"]
		var left_forearm_prefix: Array[String] = ["lowerarm_l"]
		soldier.call("_pose_first_matching", right_arm_prefix, tests[i]["rotation"])
		soldier.call("_pose_first_matching", right_forearm_prefix, Vector3(-0.8, 0.0, 0.0))
		soldier.call("_pose_first_matching", left_arm_prefix, tests[i]["rotation"])
		soldier.call("_pose_first_matching", left_forearm_prefix, Vector3(-0.8, 0.0, 0.0))
		var label := Label3D.new()
		label.text = str(tests[i]["name"])
		label.position = Vector3(-2.3 + float(i) * 2.3, 2.2, 0.0)
		label.font_size = 48
		world.add_child(label)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 4.8
	camera.position = Vector3(0.0, 2.1, -10.0)
	world.add_child(camera)
	camera.look_at(Vector3(0.0, 1.0, 0.0), Vector3.UP)
	camera.current = true
	await create_timer(1.2).timeout
	var img := get_root().get_texture().get_image()
	print("POSE_COMPARE_CAPTURE ", img.save_png(ProjectSettings.globalize_path("res://__chapter3_pose_compare.png")))
	quit()
