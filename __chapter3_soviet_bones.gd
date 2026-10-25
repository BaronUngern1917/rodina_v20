extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var model := (load("res://assets/props/ww2_soviet_uniform.glb") as PackedScene).instantiate() as Node3D
	get_root().add_child(model)
	await process_frame
	var skeleton := model.find_child("Skeleton3D", true, false) as Skeleton3D
	for i in skeleton.get_bone_count():
		var name := skeleton.get_bone_name(i).to_lower()
		if name.contains("root") or name.contains("pelvis") or name.contains("spine") or name.contains("clavicle") or name.contains("upperarm") or name.contains("lowerarm") or name.contains("hand") or name.contains("thigh") or name.contains("calf") or name.contains("foot"):
			print("BONE ", skeleton.get_bone_name(i), " rest=", skeleton.get_bone_rest(i), " pose=", skeleton.get_bone_pose(i), " global=", skeleton.get_bone_global_pose(i))
	quit()
