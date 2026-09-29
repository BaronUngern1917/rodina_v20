extends Area3D

var controller: Node
var zone_kind: String = "hull"

func hit_target() -> void:
	if is_instance_valid(controller):
		controller.register_hit(zone_kind, global_position)
