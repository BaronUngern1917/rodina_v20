extends SceneTree
func _initialize() -> void:
	call_deferred("_build")
func _build() -> void:
	get_root().size = Vector2i(1600, 900)
	var world := Node3D.new()
	get_root().add_child(world)
	var camera := Camera3D.new()
	camera.position = Vector3(0, 4, 18)
	camera.look_at(Vector3(0, 1.2, 0))
	camera.current = true
	world.add_child(camera)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -25, 0)
	sun.light_energy = 1.4
	world.add_child(sun)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("#8193a0")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("#b8ad98")
	e.ambient_light_energy = 0.7
	env.environment = e
	world.add_child(env)
	var floor := MeshInstance3D.new()
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(24, 28)
	floor.mesh = floor_mesh
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color("#55564e")
	floor.material_override = fm
	world.add_child(floor)
	var candidates: Array[Dictionary] = [
		{"path":"res://assets/props/ww2_soviet_uniform.glb", "x":-7.5, "scale":Vector3.ONE, "label":"Uniform"},
		{"path":"res://assets/props/ussr_infantry_-_call_of_duty_world_at_war.glb", "x":-2.5, "scale":Vector3.ONE * 0.01, "label":"USSR infantry pack"},
		{"path":"res://assets/props/ww2_german_wehrmacht_soldier.glb", "x":2.5, "scale":Vector3.ONE, "label":"German"},
		{"path":"res://assets/characters/dogs/cod_ghosts_riley.glb", "x":6.0, "scale":Vector3.ONE * 0.05, "label":"Dog"},
		{"path":"res://assets/vehicles/rtcw_tiger.glb", "x":0.0, "scale":Vector3.ONE * 0.6, "label":"Tiger"}
	]
	for data in candidates:
		var scene: PackedScene = load(data["path"]) as PackedScene
		if scene == null: continue
		var model: Node3D = scene.instantiate() as Node3D
		model.name = data["label"]
		model.scale = data["scale"]
		model.position = Vector3(data["x"], 0, 0)
		world.add_child(model)
		print("PREVIEW_MODEL ", data["label"], " scale ", model.scale)
	await create_timer(2.0).timeout
	var image := get_root().get_texture().get_image()
	var err := image.save_png(ProjectSettings.globalize_path("res://__chapter3_preview.png"))
	print("VIEWPORT_CAPTURE path=res://__chapter3_preview.png error=", err, " size=", image.get_size())
	quit()
