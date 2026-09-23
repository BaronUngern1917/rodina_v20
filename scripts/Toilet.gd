extends StaticBody3D
var action_text := "Чистить вилкой"
func interact(_player):
    get_tree().call_group("game","toilet_clean")
