extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	get_root().size = Vector2i(1600, 900)
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
	plane.size = Vector2(18.0, 9.0)
	floor.mesh = plane
	world.add_child(floor)
	var tests := [
		["coat Y0", "res://assets/props/german_ww2_coat.glb", Vector3.ZERO],
		["coat X90", "res://assets/props/german_ww2_coat.glb", Vector3(PI * 0.5, 0.0, 0.0)],
		["coat X-90", "res://assets/props/german_ww2_coat.glb", Vector3(-PI * 0.5, 0.0, 0.0)],
		["coat Z90", "res://assets/props/german_ww2_coat.glb", Vector3(0.0, 0.0, PI * 0.5)],
		["nazi Y0", "res://assets/props/scp-1123_nazi.glb", Vector3.ZERO],
		["nazi X90", "res://assets/props/scp-1123_nazi.glb", Vector3(PI * 0.5, 0.0, 0.0)],
		["nazi X-90", "res://assets/props/scp-1123_nazi.glb", Vector3(-PI * 0.5, 0.0, 0.0)],
		["nazi Z90", "res://assets/props/scp-1123_nazi.glb", Vector3(0.0, 0.0, PI * 0.5)]
	]
	for i in tests.size():
		var item: Array = tests[i]
		var model := (load(item[1]) as PackedScene).instantiate() as Node3D
		world.add_child(model)
		model.rotation = item[2]
		model.position = Vector3(-6.3 + float(i % 4) * 4.2, 0.0, 2.5 if i < 4 else -2.5)
		var bounds := _bounds(model)
		var factor := 1.78 / maxf(bounds.size.y, 0.001)
		model.scale = Vector3.ONE * factor
		model.position = Vector3(model.position.x, -bounds.position.y * factor, model.position.z) - Vector3(bounds.get_center().x * factor, 0.0, bounds.get_center().z * factor)
		var skeleton := model.find_child("Skeleton3D", true, false) as Skeleton3D
		var animator := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if animator != null and animator.get_animation_list().size() > 0:
			animator.play(animator.get_animation_list()[0])
		var label := Label3D.new()
		label.text = item[0] + " bones=" + str(skeleton.get_bone_count() if skeleton != null else 0)
		label.position = Vector3(-6.3 + float(i % 4) * 4.2, 2.2, 2.5 if i < 4 else -2.5)
		world.add_child(label)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 12.2
	camera.position = Vector3(0.0, 8.0, 19.0)
	world.add_child(camera)
	camera.look_at(Vector3(0.0, 0.8, 0.0), Vector3.UP)
	camera.current = true
	await create_timer(2.0).timeout
	var image := get_root().get_texture().get_image()
	print("GERMAN_RIG_ORIENTATIONS_CAPTURE ", image.save_png(ProjectSettings.globalize_path("res://__chapter3_german_rig_orientations.png")))
	quit()

func _bounds(root: Node3D) -> AABB:
	var result := AABB()
	var first := true
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
			var mi := node as MeshInstance3D
			var box := mi.get_aabb()
			for x in [box.position.x, box.end.x]:
				for y in [box.position.y, box.end.y]:
					for z in [box.position.z, box.end.z]:
						var point: Vector3 = mi.global_transform * Vector3(x, y, z)
						result = AABB(point, Vector3.ZERO) if first else result.expand(point)
						first = false
		for child in node.get_children():
			stack.append(child)
	return result
