extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game_scene := load("res://scenes/Main.tscn") as PackedScene
	var game := game_scene.instantiate() as Node3D
	root.add_child(game)
	var wait_seconds := 0.0
	while game.get("menu") == null and wait_seconds < 90.0:
		await create_timer(0.2).timeout
		wait_seconds += 0.2
	if game.get("menu") == null:
		push_error("Timed out waiting for Game world initialization")
		quit(1)
		return
	await create_timer(0.5).timeout
	game.call("start_chapter3")
	var controller := game.get_node("Chapter3Controller")
	controller.set_process(false)
	controller.set_physics_process(false)
	for combatant in get_nodes_in_group("chapter3_combatants"):
		combatant.set_physics_process(false)
	await create_timer(2.0).timeout
	var player := game.get_node("Player") as CharacterBody3D
	var camera := player.get_node("Head/Camera3D") as Camera3D
	_capture("__chapter3_lean_center.png")
	var q_event := InputEventKey.new()
	q_event.keycode = KEY_Q
	q_event.physical_keycode = KEY_Q
	q_event.pressed = true
	Input.parse_input_event(q_event)
	await create_timer(0.45).timeout
	print("LEAN_Q amount=%.3f camera_x=%.3f roll=%.3f" % [player.get("chapter3_lean_current"), camera.position.x, camera.rotation.z])
	_capture("__chapter3_lean_left.png")
	q_event.pressed = false
	Input.parse_input_event(q_event)
	await create_timer(0.35).timeout
	var e_event := InputEventKey.new()
	e_event.keycode = KEY_E
	e_event.physical_keycode = KEY_E
	e_event.pressed = true
	Input.parse_input_event(e_event)
	await create_timer(0.45).timeout
	print("LEAN_E amount=%.3f camera_x=%.3f roll=%.3f" % [player.get("chapter3_lean_current"), camera.position.x, camera.rotation.z])
	_capture("__chapter3_lean_right.png")
	e_event.pressed = false
	Input.parse_input_event(e_event)
	await create_timer(0.35).timeout
	var blocker := StaticBody3D.new()
	blocker.position = player.global_position + Vector3(-0.21, 0.7, 0.0)
	blocker.collision_layer = 1
	blocker.collision_mask = 0
	var blocker_shape := CollisionShape3D.new()
	var blocker_box := BoxShape3D.new()
	blocker_box.size = Vector3(0.10, 1.2, 1.0)
	blocker_shape.shape = blocker_box
	blocker.add_child(blocker_shape)
	game.add_child(blocker)
	var ray_from: Vector3 = camera.global_position
	var ray_to: Vector3 = ray_from - player.head.global_basis.x.normalized() * 0.28
	var ray_query := PhysicsRayQueryParameters3D.create(ray_from, ray_to)
	ray_query.collision_mask = player.collision_mask
	ray_query.exclude = [player.get_rid()]
	print("LEAN_BLOCKER_TEST player=%s camera=%s blocker=%s layer=%d mask=%d ray_to=%s hit=%s" % [str(player.global_position), str(ray_from), str(blocker.global_position), blocker.collision_layer, player.collision_mask, str(ray_to), str(player.get_world_3d().direct_space_state.intersect_ray(ray_query))])
	player.set_physics_process(false)
	q_event.pressed = true
	Input.parse_input_event(q_event)
	for _frame in 30:
		player.call("_update_chapter3_lean", 0.016)
		await process_frame
	var blocked_lean := float(player.get("chapter3_lean_current"))
	print("LEAN_Q_BLOCKED amount=%.3f camera_x=%.3f state=%s health=%.1f" % [blocked_lean, camera.position.x, game.get("state"), player.get("health")])
	if blocked_lean < 0.0 and blocked_lean >= -0.15:
		print("LEAN_COLLISION_TEST=PASS")
	else:
		push_error("Lean collision test failed: camera passed through near wall")
	_capture("__chapter3_lean_blocked.png")
	quit()

func _capture(filename: String) -> void:
	var image := root.get_texture().get_image()
	var path := ProjectSettings.globalize_path("res://" + filename)
	print("LEAN_CAPTURE path=%s size=%s err=%d" % [path, str(image.get_size()), image.save_png(path)])
