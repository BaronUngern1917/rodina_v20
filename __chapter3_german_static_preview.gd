extends SceneTree

const CANDIDATES: Array[String] = [
	"res://assets/props/nazi_engineer_-_wolf._new_colossus.glb",
	"res://assets/props/scp-1123_nazi.glb",
	"res://assets/props/scp-1123_nazi.glb"
]

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var world := Node3D.new()
	root.add_child(world)
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#aeb6bd")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_energy = 0.9
	environment_node.environment = environment
	world.add_child(environment_node)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-42.0, -30.0, 0.0)
	world.add_child(light)
	var floor := MeshInstance3D.new()
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(10.0, 7.0)
	floor.mesh = floor_mesh
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color("#626553")
	floor.material_override = floor_material
	world.add_child(floor)
	for index in CANDIDATES.size():
		var packed := load(CANDIDATES[index]) as PackedScene
		var model := packed.instantiate() as Node3D
		if index == 0:
			model.rotation.y = PI * 0.5
		elif index == 1:
			model.rotation.x = PI * 0.5
		else:
			model.rotation.x = -PI * 0.5
		world.add_child(model)
		for animator_node in model.find_children("*", "AnimationPlayer", true, false):
			(animator_node as AnimationPlayer).stop()
		var box := _bounds(model)
		var scale_value := 1.82 / maxf(box.size.y, 0.001)
		model.scale = Vector3.ONE * scale_value
		model.position = Vector3(-3.4 + index * 3.4, -box.position.y * scale_value, 0.0)
		var skeleton := model.find_child("Skeleton3D", true, false) as Skeleton3D
		var label := Label3D.new()
		var variant_name: String = "COLLOSSUS" if index == 0 else ("SCP X +90" if index == 1 else "SCP X -90")
		label.text = "%s | bones %d | H %.1fm" % [variant_name, skeleton.get_bone_count() if skeleton else 0, box.size.y * scale_value]
		label.position = Vector3(-3.4 + index * 3.4, 2.05, 0.0)
		label.font_size = 18
		world.add_child(label)
		print("GERMAN_STATIC_MODEL path=%s bones=%d bounds=%s normalized_height=%.2f" % [CANDIDATES[index], skeleton.get_bone_count() if skeleton else 0, str(box), box.size.y * scale_value])
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 5.6
	camera.position = Vector3(0.0, 1.8, 9.0)
	world.add_child(camera)
	camera.look_at(Vector3(0.0, 0.95, 0.0), Vector3.UP)
	camera.current = true
	await create_timer(1.5).timeout
	var screenshot := root.get_texture().get_image()
	print("GERMAN_STATIC_CAPTURE ", screenshot.save_png(ProjectSettings.globalize_path("res://__chapter3_german_static_preview.png")))
	quit()

func _bounds(node: Node3D) -> AABB:
	var result := AABB()
	var first := true
	var stack: Array[Node] = [node]
	while not stack.is_empty():
		var current: Node = stack.pop_back()
		if current is MeshInstance3D and (current as MeshInstance3D).mesh != null:
			var mesh_node := current as MeshInstance3D
			var box := mesh_node.get_aabb()
			for x in [box.position.x, box.end.x]:
				for y in [box.position.y, box.end.y]:
					for z in [box.position.z, box.end.z]:
						var point: Vector3 = mesh_node.global_transform * Vector3(x, y, z)
						result = AABB(point, Vector3.ZERO) if first else result.expand(point)
						first = false
		for child in current.get_children():
			stack.append(child)
	return result
