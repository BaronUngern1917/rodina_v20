extends StaticBody3D

var action_text: String = "Сесть в грузовик"

func interact(_player):
    get_tree().call_group("game", "try_finish_truck")
