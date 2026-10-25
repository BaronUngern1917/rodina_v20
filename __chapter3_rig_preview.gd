extends SceneTree

const PREVIEWS: Array[Dictionary] = [
	{"path": "res://assets/props/trench_set.glb", "label": "TRENCH 0.12", "yaw": 0.0, "scale": 0.12},
	{"path": "res://assets/props/sandbags_-_defense_line.glb", "label": "BAGS 0.065", "yaw": 0.0, "scale": 0.065},
	{"path": "res://assets/props/wooden_wall.glb", "label": "WALL 1.0", "yaw": 0.0, "scale": 1.0},
]

func _initialize() -> void:
	call_deferred("_build_preview")

func _build_preview() -> void:
	var viewport := root as Window
	viewport.size = Vector2i(1280, 720)
	var scene_root := Node3D.new()
	root.add_child(scene_root)
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#93a8b2")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#ffffff")
	environment.ambient_light_energy = 0.9
	world.environment = environment
	scene_root.add_child(world)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40.0, -25.0, 0.0)
	light.light_energy = 1.5
	scene_root.add_child(light)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(16.0, 8.0)
	ground.mesh = plane
	ground.position = Vector3(0.0, -0.03, 0.0)
	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_color = Color("#66635a")
	ground.material_override = ground_material
	scene_root.add_child(ground)
	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 2.0, 8.2)
	camera.fov = 50.0
	scene_root.add_child(camera)
	camera.look_at(Vector3(0.0, 0.95, 0.0))
	for index in PREVIEWS.size():
		var spec: Dictionary = PREVIEWS[index]
		var packed := load(String(spec["path"])) as PackedScene
		if packed == null:
			continue
		var model := packed.instantiate() as Node3D
		model.name = String(spec["label"])
		model.scale = Vector3.ONE * float(spec["scale"])
		model.rotation.y = float(spec["yaw"])
		model.position = Vector3(-4.5 + float(index) * 3.0, 0.0, 0.0)
		scene_root.add_child(model)
		var label := Label3D.new()
		label.text = String(spec["label"])
		label.position = Vector3(-4.5 + float(index) * 3.0, 2.25, 0.0)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		scene_root.add_child(label)
	await process_frame
	await process_frame
	var image := viewport.get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path("res://__chapter3_rig_preview.png"))
	print("RIG_PREVIEW_CAPTURE path=res://__chapter3_rig_preview.png")
	quit()
