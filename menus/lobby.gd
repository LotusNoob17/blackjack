extends Control

@onready var ip_input = $ip_input
@onready var status_label = $status_label

func _ready():
	$host_button.pressed.connect(_on_host_pressed)
	$join_button.pressed.connect(_on_join_pressed)
	$back1_button.pressed.connect(_on_back1_pressed)

func _on_host_pressed():
	var peer = ENetMultiplayerPeer.new()
	var result = peer.create_server(7777)
	if result != OK:
		status_label.text = "Error al crear servidor"
		return
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(_on_player_joined)
	status_label.text = "Esperando jugador..."
	
func _on_join_pressed():
	var ip = ip_input.text.strip_edges()
	var peer = ENetMultiplayerPeer.new()
	var result = peer.create_client(ip, 7777)
	if result != OK:
		status_label.text = "Error al conectar al servidor"
		return
	multiplayer.multiplayer_peer = peer
	status_label.text = "Conectando..."
	multiplayer.connected_to_server.connect(_on_connected)
func _on_back1_pressed():
	get_tree().change_scene_to_file("res://menus/main_menu.tscn")
func _on_connected():
	get_tree().change_scene_to_file("res://juego/blackjack_multiplayer.tscn")

func _on_player_joined(id):
	print("Jugador conectado con ID:", id)
	get_tree().change_scene_to_file("res://juego/blackjack_multiplayer.tscn")
