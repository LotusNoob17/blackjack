extends Control

var current_turn_is_host := false 

const SUITS = ["♠", "♥"]
const VALUES = ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]

var deck = []
var player_hand = []
var dealer_hand = []
var player_stood = false
var dealer_stood = false
var is_turn_finished = false


@onready var user_label = $Panel/user_label
@onready var role_label = $Panel/role_label
@onready var player_score_label = $Panel/player_score
@onready var dealer_score_label = $Panel/dealer_score
@onready var result_label = $Panel/result_label
@onready var restart_button = $Panel/restart_button
@onready var player_container = $Panel/player_hand
@onready var dealer_container = $Panel/dealer_hand
@onready var hit_button = $Panel/hit_button
@onready var stand_button = $Panel/stand_button
@onready var back_button = $Panel/back_button
@onready var turn_label = $Panel/turn_label


var is_host := false

func _ready():
	user_label.text = "Jugador: %s" % Global.logged_user
	is_host = multiplayer.is_server()
	role_label.text = "Rol: Dealer (Host)" if is_host else "Rol: Jugador"
	

	result_label.visible = false
	restart_button.visible = is_host
	back_button.pressed.connect(_on_back_pressed)
	_update_turn_display()
	hit_button.pressed.connect(_on_hit_pressed)
	stand_button.pressed.connect(_on_stand_pressed)

	if is_host:
		restart_button.pressed.connect(_start_game)
		multiplayer.peer_disconnected.connect(_on_peer_left)
		_start_game()


func _update_turn_display():
	if is_host:
		hit_button.disabled = !current_turn_is_host
		stand_button.disabled = !current_turn_is_host
	else:
		hit_button.disabled = current_turn_is_host
		stand_button.disabled = current_turn_is_host

	turn_label.text = "Turno: " + ("Dealer (Tú)" if is_host and current_turn_is_host else "Jugador (Tú)" if not is_host and !current_turn_is_host else "Esperando rival...")


func _on_back_pressed():
	get_tree().change_scene_to_file("res://menus/main_menu.tscn")

func _start_game():
	deck = _create_deck()
	deck.shuffle()
	player_hand = [_draw_card(), _draw_card()]
	dealer_hand = [_draw_card(), _draw_card()]
	player_stood = false
	dealer_stood = false
	current_turn_is_host = false  # Siempre comienza el jugador
	_update_hands()
	_update_turn_display()
	# En _start_game() del host
	for id in multiplayer.get_peers():
		rpc_id(id, "receive_game_state", dealer_hand.duplicate(true), player_hand.duplicate(true))

func _create_deck() -> Array:
	var new_deck = []
	for suit in SUITS:
		for value in VALUES:
			new_deck.append({
				"value": value,
				"suit": suit
			})
	return new_deck

func _draw_card() -> Dictionary:
	if deck.is_empty():
		print("⚠️ El mazo está vacío, no se puede sacar más cartas.")
		return {}  # Devuelve un Dictionary vacío para evitar el error
	return deck.pop_back()


@rpc("any_peer", "call_local")
func receive_game_state(remote_dealer_hand: Array, remote_player_hand: Array):
	if !is_host:
		player_hand = remote_player_hand.duplicate(true)
		dealer_hand = remote_dealer_hand.duplicate(true)
		_update_hands()


func _update_hands(show_all_top := false):
	_clear_container(dealer_container)
	_clear_container(player_container)

	var my_hand
	var opponent_hand

	if is_host:
		my_hand = dealer_hand
		opponent_hand = player_hand
	else:
		my_hand = player_hand
		opponent_hand = dealer_hand


	for card in my_hand:
		_add_card_visual(player_container, card)


	for i in opponent_hand.size():
		if i == 0 or show_all_top:
			_add_card_visual(dealer_container, opponent_hand[i])
		else:
			_add_card_visual(dealer_container, {"value": "?", "suit": "?"})

	player_score_label.text = "Tú: %d" % _calculate_score(my_hand)
	dealer_score_label.text = "Rival: %d" % _calculate_score(opponent_hand) if show_all_top else "Rival: ?"

func _clear_container(container: Node):
	for child in container.get_children():
		child.queue_free()

func _add_card_visual(container: Node, card: Dictionary):
	if not card.has("value") or not card.has("suit"):
		print("⚠️ Carta inválida:", card)
		return

	var sprite = TextureRect.new()
	sprite.expand = true
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sprite.custom_minimum_size = Vector2(100, 140)

	var texture: Texture
	if card["value"] == "?" or card["suit"] == "?":
		texture = load("res://assets/cards/back.png")
	else:
		var suit_map = {"♠": "P", "♥": "C"}
		var file_name = "%s%s.png" % [card["value"], suit_map.get(card["suit"], "")]
		var path = "res://assets/cards/" + file_name

		texture = load(path) if ResourceLoader.exists(path) else load("res://assets/cards/back.png")

	sprite.texture = texture
	container.add_child(sprite)


func _calculate_score(hand: Array) -> int:
	var score = 0
	var aces = 0
	for card in hand:
		var v = card["value"]
		if v in ["J", "Q", "K"]:
			score += 10
		elif v == "A":
			score += 11
			aces += 1
		else:
			score += int(v)

	while score > 21 and aces > 0:
		score -= 10
		aces -= 1

	return score


func _on_hit_pressed():
	var my_hand
	var opponent_hand

	if is_host:
		my_hand = dealer_hand
		opponent_hand = player_hand
		var card = _draw_card()
		my_hand.append(card)

		# Sincronizar con el cliente
		for id in multiplayer.get_peers():
			rpc_id(id, "sync_game_state", player_hand, dealer_hand)

		_update_hands()
		var score = _calculate_score(dealer_hand)
		if score > 21:
			_finish_game()
	else:
		rpc_id(1, "request_card", multiplayer.get_unique_id())


@rpc("any_peer", "call_local")
func sync_turn(is_host_turn: bool):
	current_turn_is_host = is_host_turn
	_update_turn_display()



@rpc("any_peer")
func request_card(player_id: int):
	if !multiplayer.is_server():
		return
	var new_card = _draw_card()
	player_hand.append(new_card)
	# Enviar la carta al cliente
	rpc_id(player_id, "receive_card", new_card)
	# Actualizar la interfaz del host también
	sync_game_state.rpc(player_hand, dealer_hand)



@rpc("authority", "call_local")
func receive_card(card: Dictionary):
	player_hand.append(card)
	_update_hands()

	var score = _calculate_score(player_hand)
	if score > 21:
		_finish_game()

	# Pedirle al host que actualice también
	if !is_host:
		rpc_id(1, "sync_game_state", player_hand, dealer_hand)



func _on_stand_pressed():
	if is_host:
		dealer_stood = true
		rpc("notify_dealer_stood")
		rpc("sync_turn", false)  # Dar el turno al cliente (si fuera necesario)
	else:
		player_stood = true
		rpc_id(1, "notify_player_stood")
		rpc("sync_turn", true)  # Dar el turno al host

	_check_end_condition()




@rpc("any_peer")
func request_stand():
	if !multiplayer.is_server():
		return

	while _calculate_score(dealer_hand) < 17:
		dealer_hand.append(_draw_card())

	var player_score = _calculate_score(player_hand)
	var dealer_score = _calculate_score(dealer_hand)

	var result := ""
	if dealer_score > 21:
		result = "Dealer se pasó. ¡Ganas!"
	elif player_score > dealer_score:
		result = "¡Ganas!"
	elif player_score < dealer_score:
		result = "Pierdes."
	else:
		result = "Empate."

	rpc("end_game", result, player_hand, dealer_hand)

@rpc("any_peer", "call_local")
func end_game(p_hand: Array, d_hand: Array):
	var my_hand
	var opponent_hand
	var my_score
	var opponent_score
	var result = ""

	if is_host:
		my_hand = d_hand.duplicate(true)
		opponent_hand = p_hand.duplicate(true)
	else:
		my_hand = p_hand.duplicate(true)
		opponent_hand = d_hand.duplicate(true)

	my_score = _calculate_score(my_hand)
	opponent_score = _calculate_score(opponent_hand)

	if my_score > 21:
		result = "¡Te pasaste! Pierdes."
	elif opponent_score > 21:
		result = "El oponente se pasó. ¡Ganas!"
	elif my_score > opponent_score:
		result = "¡Ganas!"
	elif my_score < opponent_score:
		result = "Pierdes."
	else:
		result = "Empate."

	_update_hands(true)
	result_label.text = "Resultado: %s" % result
	result_label.visible = true
	save_match_result(result)
	back_button.visible = true

func _on_peer_left(id):
	result_label.text = "El jugador remoto se ha desconectado."
	result_label.visible = true

func save_match_result(result: String):
	if Global.logged_user == "":
		print("⚠️ No hay usuario logueado.")
		return

	var request = HTTPRequest.new()
	add_child(request)
	request.request_completed.connect(_on_save_match_response)

	var form = {
		"username": Global.logged_user,
		"resultado": result,
		"player_score": str(_calculate_score(player_hand)),
		"dealer_score": str(_calculate_score(dealer_hand))
	}
	var body = Utils.http_build_query(form)
	var headers = ["Content-Type: application/x-www-form-urlencoded"]

	request.request("http://localhost/blackjack_api/save_game.php", headers, HTTPClient.METHOD_POST, body)

func _on_save_match_response(result, response_code, headers, body):
	var response = body.get_string_from_utf8()
	if response == "OK":
		print("✅ Partida registrada en la base de datos.")
	else:
		print("❌ Error al guardar partida:", response)

@rpc("any_peer")
func notify_player_stood():
	player_stood = true
	current_turn_is_host = true
	_update_turn_display()
	_check_end_condition()

@rpc("authority", "call_local")
func notify_dealer_stood():
	dealer_stood = true
	current_turn_is_host = false
	_update_turn_display()
	_check_end_condition()

func _check_end_condition():
	var player_score = _calculate_score(player_hand)
	var dealer_score = _calculate_score(dealer_hand)

	if player_score > 21 or dealer_score > 21 or (player_stood and dealer_stood):
		_finish_game()

func _finish_game():
	var my_hand
	var opponent_hand

	if is_host:
		my_hand = dealer_hand
		opponent_hand = player_hand
		rpc("end_game", opponent_hand, my_hand)  # player_hand, dealer_hand
	else:
		my_hand = player_hand
		opponent_hand = dealer_hand
		rpc("end_game", my_hand, opponent_hand)  # player_hand, dealer_hand


@rpc("any_peer", "call_local")
func sync_game_state(p_hand: Array, d_hand: Array):
	if is_host:
		player_hand = p_hand.duplicate(true)
		dealer_hand = d_hand.duplicate(true)
	else:
		player_hand = p_hand.duplicate(true)
		dealer_hand = d_hand.duplicate(true)

	_update_hands()
