extends SceneTree

const ASSETS: Array[String] = [
	"res://assets/props/trench_set.glb",
	"res://assets/props/sandbags_-_defense_line.glb",
	"res://assets/props/wooden_wall.glb",
	"res://assets/props/wooden_fences__low_poly.glb",
	"res://assets/props/build01.glb",
	"res://assets/props/old_russian_house.glb",
	"res://assets/props/soviet_strong-point.glb",
	"res://assets/props/152mm_m-10_howitzer.glb",
	"res://assets/props/metal_barrier_tank_17_mb.glb",
]

func _initialize() -> void:
	for path in ASSETS:
		var packed := load(path) as PackedScene
		if packed == null:
			print("BOUNDS path=%s missing" % path)
			continue
		var instance := packed.instantiate() as Node3D
		root.add_child(instance)
		var boxes: Array[AABB] = []
		_collect(instance, Transform3D.IDENTITY, boxes)
		if boxes.is_empty():
			print("BOUNDS path=%s empty" % path)
		else:
			var bounds: AABB = boxes[0]
			for index in range(1, boxes.size()):
				bounds = bounds.merge(boxes[index])
			print("BOUNDS path=%s position=%s size=%s" % [path, str(bounds.position), str(bounds.size)])
		instance.free()
	quit()

func _collect(node: Node3D, parent_transform: Transform3D, boxes: Array[AABB]) -> void:
	var combined: Transform3D = parent_transform * node.transform
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		boxes.append(combined * (node as MeshInstance3D).get_aabb())
	for child in node.get_children():
		if child is Node3D:
			_collect(child as Node3D, combined, boxes)
