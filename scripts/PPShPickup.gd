extends StaticBody3D

var action_text: String = "Взять ППШ"
var picked: bool = false
var collision_shape: CollisionShape3D

func _ready():
    collision_shape = get_node_or_null("CollisionShape3D") as CollisionShape3D

func interact(player):
    if picked:
        return
    var game = get_tree().get_first_node_in_group("game")
    if game == null or game.state != "yard":
        return
    picked = true
    player.give_ppsh()
    if collision_shape != null:
        collision_shape.set_deferred("disabled", true)
    var visual := get_node_or_null("PPSHVisual") as Node3D
    if visual != null:
        visual.visible = false
    action_text = "ППШ уже взят"
    get_tree().call_group("game", "say", "ППШ получен. Теперь — на стрельбище.")
