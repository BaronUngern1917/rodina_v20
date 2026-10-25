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
	plane.size = Vector2(10.0, 8.0)
	floor.mesh = plane
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color("#626553")
	floor.material_override = floor_mat
	world.add_child(floor)
	var paths := [
		"res://assets/props/german_ww2_coat.glb",
		"res://assets/props/nazi_engineer_-_wolf._new_colossus.glb",
		"res://assets/props/scp-1123_nazi.glb"
	]
	for i in paths.size():
		var model := (load(paths[i]) as PackedScene).instantiate() as Node3D
		if i == 0:
			model.rotation.x = PI * 0.5
		world.add_child(model)
		var bounds := _bounds(model)
		var scale_value := 1.82 / maxf(bounds.size.y, 0.001)
		model.scale = Vector3.ONE * scale_value
		model.position = Vector3(-3.4 + i * 3.4, -bounds.position.y * scale_value, 0.0)
		var skeleton := model.find_child("Skeleton3D", true, false) as Skeleton3D
		var animator := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
		print("GERMAN_PREVIEW path=", paths[i], " size=", bounds.size, " scale=", scale_value, " bones=", skeleton.get_bone_count() if skeleton else 0)
		if animator and not animator.get_animation_list().is_empty():
			animator.play(animator.get_animation_list()[0])
		for camera_node in model.find_children("*", "Camera3D", true, false):
			(camera_node as Camera3D).current = false
		for light_node in model.find_children("*", "Light3D", true, false):
			(light_node as Light3D).visible = false
		var label := Label3D.new()
		label.text = paths[i].get_file().replace(".glb", "")
		label.position = Vector3(-3.4 + i * 3.4, 2.0, 0.0)
		label.font_size = 20
		world.add_child(label)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 5.6
	camera.position = Vector3(0.0, 1.7, 8.0)
	world.add_child(camera)
	camera.look_at(Vector3(0.0, 0.95, 0.0), Vector3.UP)
	camera.current = true
	await create_timer(2.0).timeout
	var image: Image = get_root().get_texture().get_image()
	print("GERMAN_VARIANTS_CAPTURE ", image.save_png(ProjectSettings.globalize_path("res://__chapter3_german_variants_preview.png")))
	quit()

func _bounds(root: Node3D) -> AABB:
	var result := AABB()
	var first := true
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
			var mi: MeshInstance3D = node as MeshInstance3D
			var box: AABB = mi.get_aabb()
			for x in [box.position.x, box.end.x]:
				for y in [box.position.y, box.end.y]:
					for z in [box.position.z, box.end.z]:
						var point := mi.global_transform * Vector3(x, y, z)
						result = AABB(point, Vector3.ZERO) if first else result.expand(point)
						first = false
		for child in node.get_children():
			stack.append(child)
	return result
