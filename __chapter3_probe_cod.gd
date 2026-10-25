extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed := load("res://assets/props/ussr_infantry_-_call_of_duty_world_at_war.glb") as PackedScene
	var root := packed.instantiate() as Node3D
	get_root().add_child(root)
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is Skeleton3D:
			var skeleton := node as Skeleton3D
			print("SKELETON path=", skeleton.get_path(), " bones=", skeleton.get_bone_count(), " pos=", skeleton.global_position)
		if node is MeshInstance3D:
			var mesh := node as MeshInstance3D
			var skeleton_node: Node = mesh.get_node_or_null(mesh.skeleton) if not mesh.skeleton.is_empty() else null
			var skeleton_name: String = str(skeleton_node.get_path()) if skeleton_node != null else "none"
			print("MESH path=", mesh.get_path(), " name=", mesh.name, " skeleton=", skeleton_name, " pos=", mesh.global_position, " bounds=", mesh.global_transform * mesh.get_aabb())
		for child in node.get_children():
			stack.append(child)
	quit()
