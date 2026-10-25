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
	environment.ambient_light_energy = 0.9
	environment_node.environment = environment
	world.add_child(environment_node)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42.0, -30.0, 0.0)
	world.add_child(sun)
	var floor := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(9.0, 8.0)
	floor.mesh = plane
	world.add_child(floor)
	var positions := [-2.7, -0.9, 0.9, 2.7]
	var captions := ["REST", "READY .8", "READY 1.35", "ARMS UP"]
	var test_script := load("res://scripts/Chapter3Combatant.gd") as Script
	for i in 4:
		var soldier := test_script.new() as CharacterBody3D
		world.add_child(soldier)
		soldier.set_physics_process(false)
		soldier.configure(world, &"german", &"rifle", Vector3(positions[i], 0.0, 0.0))
		var model := soldier.find_child("SoldierModel", true, false) as Node3D
		var skeleton := soldier.find_child("Skeleton3D", true, false) as Skeleton3D
		if i > 0:
			var shoulder_left := 0.8 if i != 2 else 1.35
			var shoulder_right := -shoulder_left
			var elbow_left := -0.85 if i != 3 else 0.0
			var elbow_right := 0.85 if i != 3 else 0.0
			for item in [["leftarm_019", Vector3(shoulder_left, 0.0, -0.1)], ["rightarm_045", Vector3(shoulder_right, 0.0, 0.1)], ["leftforearm_020", Vector3(elbow_left, 0.0, -0.08)], ["rightforearm_00", Vector3(elbow_right, 0.0, 0.08)]]:
				var bone_index := skeleton.find_bone(item[0])
				if bone_index >= 0:
					skeleton.set_bone_pose_rotation(bone_index, Quaternion.from_euler(item[1]))
		var label := Label3D.new()
		label.text = captions[i]
		label.position = Vector3(positions[i], 2.05, 0.0)
		world.add_child(label)
	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 1.8, 9.0)
	world.add_child(camera)
	camera.look_at(Vector3(0.0, 0.95, 0.0), Vector3.UP)
	camera.current = true
	await create_timer(2.0).timeout
	var image := get_root().get_texture().get_image()
	print("GERMAN_POSE_MATRIX_CAPTURE ", image.save_png(ProjectSettings.globalize_path("res://__chapter3_german_pose_matrix.png")))
	quit()
