extends StaticBody3D

var action_text: String = "Поговорить со старшим"
var used: bool = false

func interact(_player):
    if used:
        return
    used = true
    action_text = "Задание выдано"
    get_tree().call_group("game", "unlock_toilet_door")
    get_tree().call_group("game", "update_state", "toilet")
    get_tree().call_group("game", "say", "Солдат: «Унитаз. Вилкой. Быстро.»")
