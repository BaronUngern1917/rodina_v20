extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for path in [
		"res://assets/props/nazi_engineer_-_wolf._new_colossus.glb",
		"res://assets/props/ww2_soviet_uniform.glb",
		"res://assets/props/ussr_infantry_-_call_of_duty_world_at_war.glb",
		"res://assets/props/soviet_soldier_monument_updated_model_-_hi_q.glb",
		"res://assets/props/scp-1123_nazi.glb",
		"res://assets/props/trench_set.glb",
		"res://assets/props/low_poly_dirt_ground.glb",
		"res://assets/props/bunker_o323a-160_z.glb",
		"res://assets/props/sandbags_-_defense_line.glb",
		"res://assets/props/soviet_strong-point.glb",
		"res://assets/props/field.glb",
		"res://assets/props/grass.glb",
		"res://assets/props/pine_tree.glb",
		"res://assets/props/stylised_rocks_asset_pack.glb",
		"res://assets/props/russian_45mm_artillery_gun.glb",
		"res://assets/props/152mm_m-10_howitzer.glb",
		"res://assets/props/radio_receiver_angrr-5.glb",
		"res://assets/props/old_russian_house.glb",
		"res://assets/vehicles/rtcw_tiger.glb",
		"res://assets/vehicles/aviation/junkers_ju_87_stuka.glb"
	]:
		print("=== ASSET " + path)
		var packed := load(path) as PackedScene
		if packed == null:
			print("LOAD_FAILED")
			continue
		var root := packed.instantiate()
		get_root().add_child(root)
		var meshes := 0
		var skeletons := 0
		var animations := 0
		var bounds := AABB()
		var has_bounds := false
		var skeleton_info := PackedStringArray()
		var animation_info := PackedStringArray()
		var tree_info := PackedStringArray()
		var stack: Array[Node] = [root]
		while not stack.is_empty():
			var node: Node = stack.pop_back()
			if node is MeshInstance3D:
				meshes += 1
				var mesh_node := node as MeshInstance3D
				if mesh_node.mesh != null:
					var box := mesh_node.global_transform * mesh_node.get_aabb()
					bounds = box if not has_bounds else bounds.merge(box)
					has_bounds = true
			if node is Skeleton3D:
				skeletons += 1
				var skeleton := node as Skeleton3D
				var names := PackedStringArray()
				for i in skeleton.get_bone_count():
					var bone_name: String = skeleton.get_bone_name(i)
					if bone_name.to_lower().contains("arm") or bone_name.to_lower().contains("hand") or bone_name.to_lower().contains("hip") or bone_name.to_lower().contains("leg") or bone_name.to_lower().contains("spine"):
						names.append(bone_name)
				skeleton_info.append("%s bones=%d: %s" % [skeleton.name, skeleton.get_bone_count(), ", ".join(names)])
			if node is AnimationPlayer:
				var player := node as AnimationPlayer
				for anim_name in player.get_animation_list():
					animations += 1
					animation_info.append("%s:%s" % [player.name, anim_name])
			for child in node.get_children():
				stack.append(child)
		print("SUMMARY meshes=%d skeletons=%d animations=%d bounds=%s" % [meshes, skeletons, animations, str(bounds)])
		for info in skeleton_info:
			print("SKELETON " + info)
		for info in animation_info:
			print("ANIMATION " + info)
		root.queue_free()
	quit()
