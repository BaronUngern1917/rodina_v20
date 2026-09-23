extends StaticBody3D

var action_text: String = "Поговорить с Бурятом"
var used: bool = false

func interact(_player):
    if used:
        get_tree().call_group("game", "say", "Бурят: «Вот, твоё оружие. Идти стрелять мишень тренировка.»")
        return
    var game = get_tree().get_first_node_in_group("game")
    if game == null or game.state != "yard":
        return
    used = true
    action_text = "Бурят: ППШ получен"
    get_tree().call_group("game", "receive_ppsh_from_buryat")
