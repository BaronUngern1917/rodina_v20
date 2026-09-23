extends StaticBody3D

var active: bool = true
var mesh_node: MeshInstance3D
var collision_node: CollisionShape3D

func _ready():
    mesh_node = get_node_or_null("MeshInstance3D") as MeshInstance3D
    collision_node = get_node_or_null("CollisionShape3D") as CollisionShape3D

func hit_target():
    if not active:
        return
    var game = get_tree().get_first_node_in_group("game")
    if game == null or game.state != "range":
        return
    active = false
    if mesh_node != null:
        mesh_node.visible = false
    if collision_node != null:
        collision_node.set_deferred("disabled", true)
    get_tree().call_group("game", "target_hit")
