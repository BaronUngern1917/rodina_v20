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
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35.0, -30.0, 0.0)
	world.add_child(sun)
	var floor := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(8.0, 8.0)
	floor.mesh = plane
	world.add_child(floor)
	var path := "res://assets/props/scp-1123_nazi.glb"
	var model := (load(path) as PackedScene).instantiate() as Node3D
	world.add_child(model)
	for camera_node in model.find_children("*", "Camera3D", true, false):
		(camera_node as Camera3D).current = false
	for light_node in model.find_children("*", "Light3D", true, false):
		(light_node as Light3D).visible = false
	var old_position := Vector3(-2.0, 0.0, 0.0)
	model.position = old_position
	var bounds := _bounds(model)
	var factor := 1.8 / maxf(bounds.size.y, 0.001)
	model.scale = Vector3.ONE * factor
	var center_offset := bounds.get_center() - old_position
	model.position = Vector3(-center_offset.x * factor, -bounds.position.y * factor, -center_offset.z * factor)
	model.rotation.y = PI
	var skeleton := model.find_child("Skeleton3D", true, false) as Skeleton3D
	var animator := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if animator != null and animator.get_animation_list().size() > 0:
		animator.play(animator.get_animation_list()[0])
	print("GERMAN_OFFICER_CHECK bounds_raw=", bounds, " scale=", factor, " skeleton_bones=", skeleton.get_bone_count() if skeleton != null else 0, " animations=", animator.get_animation_list() if animator != null else [])
	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 2.0, 9.5)
	world.add_child(camera)
	camera.look_at(Vector3(0.0, 0.9, 0.0), Vector3.UP)
	camera.current = true
	await create_timer(1.0).timeout
	var image := get_root().get_texture().get_image()
	print("GERMAN_OFFICER_CAPTURE ", image.save_png(ProjectSettings.globalize_path("res://__chapter3_german_officer_preview.png")))
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
						var point := mi.global_transform * Vector3(x, y, z)
						result = AABB(point, Vector3.ZERO) if first else result.expand(point)
						first = false
		for child in node.get_children():
			stack.append(child)
	return result
