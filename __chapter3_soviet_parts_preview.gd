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
	var names: Array[String] = ["Object_71", "Object_68", "Object_73", "Object_69"]
	for i in names.size():
		var root := (load("res://assets/props/ww2_soviet_uniform.glb") as PackedScene).instantiate() as Node3D
		world.add_child(root)
		root.scale = Vector3.ONE * 0.8
		root.rotation.y = PI
		var meshes: Array[Node] = root.find_children("*", "MeshInstance3D", true, false)
		for item in meshes:
			var mesh := item as MeshInstance3D
			mesh.visible = mesh.name == names[i]
			if mesh.visible:
				print("SOVIET_PART index=", i, " name=", mesh.name, " local_bounds=", mesh.get_aabb())
		root.position = Vector3(-4.2 + i * 2.8, 0.0, 0.0)
		var label := Label3D.new()
		label.text = names[i]
		label.position = Vector3(-4.2 + i * 2.8, 2.0, 0.0)
		world.add_child(label)
	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 2.0, -8.5)
	world.add_child(camera)
	camera.look_at(Vector3(0.0, 0.9, 0.0), Vector3.UP)
	camera.current = true
	await create_timer(1.5).timeout
	var image := get_root().get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path("res://__chapter3_soviet_parts_preview.png"))
	quit()
