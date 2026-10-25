extends SceneTree

const CHECK_PATHS: PackedStringArray = [
	"res://assets/props/ussr_infantry_-_call_of_duty_world_at_war.glb",
	"res://assets/props/ww2_german_wehrmacht_soldier.glb",
	"res://assets/props/ww2_german_mp40.glb",
	"res://assets/props/ww2_soviet_uniform.glb",
	"res://assets/props/soviet_soldier_monument_updated_model_-_hi_q.glb",
	"res://assets/props/german_ww2_coat.glb",
	"res://assets/characters/dogs/cod_ghosts_riley.glb",
	"res://assets/vehicles/rtcw_tiger.glb",
	"res://assets/vehicles/panzer_3_ausf_j_tank_model.glb",
	"res://assets/props/russian_45mm_artillery_gun.glb",
	"res://assets/props/152mm_m-10_howitzer.glb",
	"res://assets/props/soviet_strong-point.glb",
	"res://assets/props/trench_set.glb",
	"res://assets/props/bunker_o323a-160_z.glb",
	"res://assets/props/sandbags_-_defense_line.glb",
	"res://assets/props/french_house_ww2.glb",
	"res://assets/props/old_russian_house.glb",
	"res://assets/weapons/ptrd_anti-_tank_rifle.glb",
	"res://assets/weapons/ppsh-41.glb",
	"res://assets/props/maschinengewehr_mg_42.glb",
	"res://assets/props/artillery_shell.glb",
	"res://assets/props/timeframe_explosion.glb",
	"res://assets/vehicles/aviation/junkers_ju_87_stuka.glb"
]

func _initialize() -> void:
	call_deferred("_inspect")

func _inspect() -> void:
	for path in CHECK_PATHS:
		var packed: PackedScene = ResourceLoader.load(path) as PackedScene
		if packed == null:
			print("ASSET %s MISSING_OR_NOT_IMPORTED" % path)
			continue
		var root: Node = packed.instantiate()
		root.name = "Probe"
		get_root().add_child(root)
		var result: Dictionary = {"nodes": 0, "meshes": 0, "skeletons": [], "animations": [], "minimum": Vector3(INF, INF, INF), "maximum": Vector3(-INF, -INF, -INF)}
		_walk(root, result)
		var dims: Vector3 = result["maximum"] - result["minimum"]
		print("ASSET %s nodes=%d meshes=%d size=%s skeletons=%s animations=%s" % [path, result["nodes"], result["meshes"], dims, str(result["skeletons"]), str(result["animations"])])
		root.queue_free()
	await process_frame
	quit()

func _walk(node: Node, result: Dictionary) -> void:
	result["nodes"] = int(result["nodes"]) + 1
	if node is MeshInstance3D:
		var mi: MeshInstance3D = node as MeshInstance3D
		if mi.mesh != null:
			result["meshes"] = int(result["meshes"]) + 1
			var aabb: AABB = mi.mesh.get_aabb()
			for x in [aabb.position.x, aabb.end.x]:
				for y in [aabb.position.y, aabb.end.y]:
					for z in [aabb.position.z, aabb.end.z]:
						var corner: Vector3 = mi.global_transform * Vector3(x, y, z)
						result["minimum"] = (result["minimum"] as Vector3).min(corner)
						result["maximum"] = (result["maximum"] as Vector3).max(corner)
	if node is Skeleton3D:
		var skeleton: Skeleton3D = node as Skeleton3D
		var bones: PackedStringArray = []
		for i in mini(skeleton.get_bone_count(), 10):
			bones.append(skeleton.get_bone_name(i))
		(result["skeletons"] as Array).append("%s:%d:%s" % [skeleton.name, skeleton.get_bone_count(), ",".join(bones)])
	if node is AnimationPlayer:
		(result["animations"] as Array).append("%s:%s" % [node.name, ",".join((node as AnimationPlayer).get_animation_list())])
	for child in node.get_children():
		_walk(child, result)
