extends Control

@onready var user_label = $Panel/user_label
@onready var vs_cpu_button = $Panel/VBoxContainer/vs_cpu_button
@onready var multiplayer_button = $Panel/VBoxContainer/multiplayer_button
@onready var logout_button = $Panel/VBoxContainer/logout_button

func _ready():
	user_label.text = "Bienvenido, %s" % Global.logged_user
	vs_cpu_button.pressed.connect(_on_vs_cpu_pressed)
	multiplayer_button.pressed.connect(_on_multiplayer_pressed)
	logout_button.pressed.connect(_on_logout_pressed)

func _on_vs_cpu_pressed():
	get_tree().change_scene_to_file("res://juego/blackjack.tscn")

func _on_multiplayer_pressed():
	get_tree().change_scene_to_file("res://menus/lobby.tscn")

func _on_logout_pressed():
	Global.logged_user = ""
	get_tree().change_scene_to_file("res://login/control.tscn")
