extends StaticBody3D

var opened: bool = false
var locked: bool = false
var action_text: String = "Открыть дверь"
var target_state: String = "yard"
var auto_close_after_entry: bool = false
var _busy: bool = false
var _closed_rotation_y: float = 0.0

func _ready():
    _closed_rotation_y = rotation.y

func interact(_player):
    if _busy:
        return
    if locked:
        get_tree().call_group("game", "say", "Дверь пока заперта.")
        return
    open()

func open():
    if _busy or opened:
        return
    _busy = true
    opened = true
    var collision: CollisionShape3D = get_node_or_null("CollisionShape3D") as CollisionShape3D
    if collision:
        collision.set_deferred("disabled", true)
    var tween := create_tween()
    tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    tween.tween_property(self, "rotation:y", _closed_rotation_y + deg_to_rad(-90.0), 0.45)
    await tween.finished
    get_tree().call_group("game", "update_state", target_state)
    _busy = false

func close_and_lock(lock_message: String = "Дверь заперта"):
    if _busy or not opened:
        return
    _busy = true
    var tween := create_tween()
    tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    tween.tween_property(self, "rotation:y", _closed_rotation_y, 0.4)
    await tween.finished
    opened = false
    locked = true
    action_text = lock_message
    var collision: CollisionShape3D = get_node_or_null("CollisionShape3D") as CollisionShape3D
    if collision:
        collision.set_deferred("disabled", false)
    _busy = false
