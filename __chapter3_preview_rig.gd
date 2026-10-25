extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var root := Node3D.new()
	get_root().add_child(root)
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#adb5bc")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color.WHITE
	environment.ambient_light_energy = 0.8
	environment_node.environment = environment
	root.add_child(environment_node)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45.0, -25.0, 0.0)
	root.add_child(light)
	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 3.2, 9.0)
	root.add_child(camera)
	camera.look_at(Vector3(0.0, 0.8, 0.0), Vector3.UP)
	camera.current = true
	var rotations: Array[Vector3] = [Vector3(-PI * 0.5, 0.0, 0.0), Vector3(PI * 0.5, 0.0, 0.0), Vector3(0.0, 0.0, -PI * 0.5), Vector3(0.0, 0.0, PI * 0.5)]
	for index in rotations.size():
		var packed := load("res://assets/props/ww2_soviet_uniform.glb") as PackedScene
		var model := packed.instantiate() as Node3D
		model.position.x = -3.3 + float(index) * 2.2
		model.rotation = rotations[index]
		model.scale = Vector3.ONE * 1.05
		root.add_child(model)
	var floor := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(12.0, 12.0)
	floor.mesh = plane
	floor.position.y = -0.02
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color("#5e614f")
	floor.material_override = floor_material
	root.add_child(floor)
	await process_frame
	await process_frame
	await process_frame
	get_root().get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://__chapter3_rig_preview.png"))
	quit()
