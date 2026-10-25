extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var root := (load("res://assets/props/ussr_infantry_-_call_of_duty_world_at_war.glb") as PackedScene).instantiate() as Node3D
	get_root().add_child(root)
	var body := root.find_child("char_rus_guard_body1_1_LOD0", true, false) as Node3D
	if body == null:
		print("BODY_NOT_FOUND")
		quit()
		return
	var boxes: Array[AABB] = []
	var all_nodes: Array[Node] = [root]
	while not all_nodes.is_empty():
		var node: Node = all_nodes.pop_back()
		if node is VisualInstance3D:
			(node as VisualInstance3D).visible = body.is_ancestor_of(node) or node == body
		if node is MeshInstance3D and (body.is_ancestor_of(node) or node == body):
			var mesh := node as MeshInstance3D
			boxes.append(mesh.global_transform * mesh.get_aabb())
		for child in node.get_children():
			all_nodes.append(child)
	var bounds := boxes[0]
	for index in range(1, boxes.size()):
		bounds = bounds.merge(boxes[index])
	var scale_value: float = 0.015
	root.scale = Vector3.ONE * scale_value
	root.position = Vector3(-(bounds.position.x + bounds.size.x * 0.5) * scale_value, -bounds.position.y * scale_value, -(bounds.position.z + bounds.size.z * 0.5) * scale_value)
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#aeb6bd")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color.WHITE
	environment.ambient_light_energy = 0.8
	environment_node.environment = environment
	get_root().add_child(environment_node)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-42.0, -30.0, 0.0)
	get_root().add_child(light)
	var floor := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(12.0, 12.0)
	floor.mesh = plane
	floor.position.y = -0.01
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color("#60614f")
	floor.material_override = floor_material
	get_root().add_child(floor)
	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 1.4, 4.4)
	get_root().add_child(camera)
	camera.look_at(Vector3(0.0, 0.82, 0.0), Vector3.UP)
	camera.current = true
	await process_frame
	await process_frame
	get_root().get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://__chapter3_cod_body_preview.png"))
	print("BODY_BOUNDS ", bounds, " screenshot written")
	quit()
