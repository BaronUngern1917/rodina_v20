extends SceneTree
const PATHS: PackedStringArray = ["res://assets/props/ww2_soviet_uniform.glb", "res://assets/props/ussr_infantry_-_call_of_duty_world_at_war.glb", "res://assets/props/german_ww2_coat.glb", "res://assets/characters/dogs/cod_ghosts_riley.glb", "res://assets/vehicles/rtcw_tiger.glb"]
func _initialize() -> void:
	call_deferred("_inspect")
func _inspect() -> void:
	for path in PATHS:
		var packed: PackedScene = load(path) as PackedScene
		if packed == null: continue
		var root: Node = packed.instantiate()
		print("TREE_BEGIN ", path)
		_walk(root, "", 0)
		print("TREE_END")
		root.free()
	quit()
func _walk(node: Node, parent_path: String, depth: int) -> void:
	if depth > 8: return
	var path: String = parent_path + "/" + node.name
	var extra: String = ""
	if node is MeshInstance3D:
		var mi: MeshInstance3D = node as MeshInstance3D
		extra = " mesh=" + (mi.mesh.get_class() if mi.mesh else "null") + " bounds=" + str(mi.mesh.get_aabb().size if mi.mesh else Vector3.ZERO)
	if node is Skeleton3D:
		var sk: Skeleton3D = node as Skeleton3D
		var names: PackedStringArray = []
		for i in range(sk.get_bone_count()): names.append(sk.get_bone_name(i))
		extra = " bones=" + str(sk.get_bone_count()) + " " + ",".join(names)
	if node is AnimationPlayer:
		extra = " anims=" + ",".join((node as AnimationPlayer).get_animation_list())
	print("  ".repeat(depth) + path + " [" + node.get_class() + "]" + extra)
	for child in node.get_children(): _walk(child, path, depth + 1)
