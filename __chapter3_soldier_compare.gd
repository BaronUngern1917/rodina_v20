extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	get_root().size = Vector2i(1600, 900)
	var root := Node3D.new()
	get_root().add_child(root)
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#aeb6bd")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color.WHITE
	environment.ambient_light_energy = 0.9
	environment_node.environment = environment
	root.add_child(environment_node)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-42.0, -30.0, 0.0)
	root.add_child(light)
	var paths := [
		"res://assets/props/nazi_engineer_-_wolf._new_colossus.glb",
		"res://assets/props/german_ww2_coat.glb",
		"res://assets/props/scp-1123_nazi.glb",
		"res://assets/props/ww2_german_wehrmacht_soldier.glb"
	]
	for index in paths.size():
		var packed := load(paths[index]) as PackedScene
		if packed == null:
			continue
		var model := packed.instantiate() as Node3D
		root.add_child(model)
		var bounds := _bounds(model)
		var scale_value: float = 1.85 / maxf(bounds.size.y, 0.001)
		model.scale = Vector3.ONE * scale_value
		model.position = Vector3(-4.5 + float(index) * 3.0 - (bounds.position.x + bounds.size.x * 0.5) * scale_value, -bounds.position.y * scale_value, -(bounds.position.z + bounds.size.z * 0.5) * scale_value)
		print(paths[index], " bounds=", bounds, " scale=", scale_value)
		if index == 2:
			var animator := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
			if animator != null:
				for animation_name in animator.get_animation_list():
					print("SCP_ANIMATION ", animation_name, " duration=", animator.get_animation(animation_name).length)
				animator.play("naziofficer_skeleton|naziofficerAnim")
		var title := Label3D.new()
		title.text = paths[index].get_file().replace(".glb", "")
		title.position = Vector3(-4.5 + float(index) * 3.0, 2.05, 0.0)
		title.font_size = 28
		root.add_child(title)
	var floor := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(15.0, 16.0)
	floor.mesh = plane
	floor.position = Vector3(0.0, -0.01, 0.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#666957")
	floor.material_override = mat
	root.add_child(floor)
	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 3.1, 13.5)
	root.add_child(camera)
	camera.look_at(Vector3(0.0, 0.95, 0.0), Vector3.UP)
	camera.current = true
	await create_timer(1.5).timeout
	var image: Image = get_root().get_texture().get_image()
	var error: Error = image.save_png(ProjectSettings.globalize_path("res://__chapter3_soldier_compare.png"))
	print("PREVIEW_CAPTURE size=", image.get_size(), " error=", error)
	quit()

func _bounds(root: Node3D) -> AABB:
	var stack: Array[Node] = [root]
	var result := AABB()
	var first := true
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
			var box: AABB = (node as MeshInstance3D).global_transform * (node as MeshInstance3D).get_aabb()
			result = box if first else result.merge(box)
			first = false
		for child in node.get_children():
			stack.append(child)
	return result
