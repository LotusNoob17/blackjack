extends Control

@onready var user_label = $Panel/user_label


const SUITS = ["♠", "♥"]
const VALUES = ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]

var deck = []
var player_hand = []
var dealer_hand = []

@onready var player_score_label = $Panel/player_score
@onready var dealer_score_label = $Panel/dealer_score
@onready var result_label = $Panel/result_label
@onready var restart_button = $Panel/restart_button
@onready var player_container = $Panel/player_hand
@onready var dealer_container = $Panel/dealer_hand
@onready var back_button = $Panel/back_button

func _ready():
	user_label.text = "Jugador: %s" % Global.logged_user
	$Panel/hit_button.pressed.connect(_on_hit_pressed)
	$Panel/stand_button.pressed.connect(_on_stand_pressed)
	restart_button.pressed.connect(_start_game)
	_start_game()
	back_button.pressed.connect(_on_back_pressed)

func _on_back_pressed():
	get_tree().change_scene_to_file("res://menus/main_menu.tscn")

func _create_deck() -> Array:
	var new_deck = []
	for suit in SUITS:
		for value in VALUES:
			new_deck.append({
				"value": value,
				"suit": suit
			})
	return new_deck

func _start_game():
	# Reset
	deck = _create_deck()
	deck.shuffle()
	player_hand = []
	dealer_hand = []
	result_label.visible = false
	restart_button.visible = false

	_clear_container(player_container)
	_clear_container(dealer_container)

	# Rehabilitar botones
	$Panel/hit_button.disabled = false
	$Panel/stand_button.disabled = false

	# Deal initial cards
	player_hand.append(_draw_card())
	dealer_hand.append(_draw_card())
	player_hand.append(_draw_card())
	dealer_hand.append(_draw_card())

	_update_hands()


func _clear_container(container: Node):
	for child in container.get_children():
		child.queue_free()

func _draw_card() -> Dictionary:
	return deck.pop_back()

func _update_hands(show_all_dealer := false):
	_clear_container(player_container)
	_clear_container(dealer_container)

	for card in player_hand:
		_add_card_visual(player_container, card)

	for i in dealer_hand.size():
		if i == 0 or show_all_dealer:
			_add_card_visual(dealer_container, dealer_hand[i])
		else:
			_add_card_visual(dealer_container, {"value": "?", "suit": "?"})

	player_score_label.text = "Puntos: %d" % _calculate_score(player_hand)
	if show_all_dealer:
		dealer_score_label.text = "Dealer: %d" % _calculate_score(dealer_hand)
	else:
		dealer_score_label.text = "Dealer: ?"

func _add_card_visual(container: Node, card: Dictionary):
	var sprite = TextureRect.new()
	sprite.expand = true
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sprite.custom_minimum_size = Vector2(100, 140)

	var texture: Texture
	if card.value == "?" or card.suit == "?":
		texture = load("res://assets/cards/back.png")
	else:
		var suit_map = {"♠": "P", "♥": "C"}
		var file_name = "%s%s.png" % [card.value, suit_map.get(card.suit, "")]
		var path = "res://assets/cards/" + file_name

		print("Cargando imagen para carta:", card)
		print("Ruta construida:", path)

		if ResourceLoader.exists(path):
			texture = load(path)
		else:
			print("⚠️ No se encontró la imagen:", path)
			texture = load("res://assets/cards/back.png")

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
	player_hand.append(_draw_card())
	_update_hands()

	if _calculate_score(player_hand) > 21:
		_end_game("¡Te pasaste! Pierdes.")

func _on_stand_pressed():
	while _calculate_score(dealer_hand) < 17:
		dealer_hand.append(_draw_card())

	_update_hands(true)
	var player_score = _calculate_score(player_hand)
	var dealer_score = _calculate_score(dealer_hand)

	if dealer_score > 21:
		_end_game("Dealer se pasó. ¡Ganas!")
	elif player_score > dealer_score:
		_end_game("¡Ganas!")
	elif player_score < dealer_score:
		_end_game("Pierdes.")
	else:
		_end_game("Empate.")

func _end_game(result: String):
	result_label.text = result
	result_label.visible = true
	restart_button.visible = true
	back_button.visible = true

	$Panel/hit_button.disabled = true
	$Panel/stand_button.disabled = true
	
	save_match_result(result)
	_save_score(result)

	
func _save_score(result: String):
	var username = Global.logged_user
	if username == "":
		push_warning("No hay usuario logueado, no se guarda historial.")
		return

	var score_data = {
		"result": result,
		"player_score": _calculate_score(player_hand),
		"dealer_score": _calculate_score(dealer_hand),
		"timestamp": Time.get_datetime_string_from_system()
	}

	var file_path = "user://scores/%s.json" % username
	DirAccess.make_dir_recursive_absolute("user://scores")
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	var history = []
	if file:
		var content = file.get_as_text()
		var parsed = JSON.parse_string(content)
		if typeof(parsed) == TYPE_ARRAY:
			history = parsed
	file = FileAccess.open(file_path, FileAccess.WRITE)
	history.append(score_data)
	file.store_string(JSON.stringify(history, "\t"))
	
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
