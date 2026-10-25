extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var model := (load("res://assets/props/ww2_soviet_uniform.glb") as PackedScene).instantiate() as Node3D
	get_root().add_child(model)
	await process_frame
	var stack: Array[Node] = [model]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is MeshInstance3D:
			var mesh := node as MeshInstance3D
			var skeleton_node: Node = mesh.get_node_or_null(mesh.skeleton) if not mesh.skeleton.is_empty() else null
			print("SOVIET_MESH path=", mesh.get_path(), " bounds=", mesh.get_aabb(), " skeleton=", skeleton_node.get_path() if skeleton_node else "none")
		for child in node.get_children():
			stack.append(child)
	quit()
