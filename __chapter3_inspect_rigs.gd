extends SceneTree

const TARGETS: Array[String] = [
	"res://assets/props/nazi_engineer_-_wolf._new_colossus.glb",
	"res://assets/props/scp-1123_nazi.glb",
	"res://assets/props/german_ww2_coat.glb",
	"res://assets/props/ww2_german_wehrmacht_soldier.glb",
]

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for path in TARGETS:
		var packed := load(path) as PackedScene
		if packed == null:
			print("ASSET path=%s load=failed" % path)
			continue
		var instance := packed.instantiate() as Node3D
		root.add_child(instance)
		print("ASSET path=%s root=%s" % [path, instance.get_class()])
		_walk(instance, path)
		print("SUMMARY path=%s root_scale=%s" % [path, str(instance.scale)])
		instance.free()
	quit()

func _walk(node: Node, path: String) -> void:
	if node is Skeleton3D:
		var skeleton := node as Skeleton3D
		var keys: Array[String] = []
		for index in skeleton.get_bone_count():
			var bone_name := skeleton.get_bone_name(index)
			if bone_name.to_lower().contains("upperarm") or bone_name.to_lower().contains("forearm") or bone_name.to_lower().contains("hand"):
				keys.append(bone_name)
		print("SKELETON path=%s count=%d arm_bones=%s" % [path, skeleton.get_bone_count(), ",".join(keys)])
	if node is AnimationPlayer:
		print("ANIM path=%s node=%s clips=%s" % [path, str(node.get_path()), ",".join((node as AnimationPlayer).get_animation_list())])
	for child in node.get_children():
		_walk(child, path)
