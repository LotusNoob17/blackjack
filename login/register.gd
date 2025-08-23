extends Control
const REGISTER_URL = "http://localhost/blackjack_api/register.php" 

@onready var username_line = $Panel/username_line
@onready var password_line = $Panel/password_line
@onready var confirm_line = $Panel/confirm_line
@onready var error_label = $Panel/error_label

func _ready():
	$Panel/register_button.pressed.connect(_on_register_pressed)
	$Panel/back_button.pressed.connect(_on_back_pressed)

func _on_register_pressed():
	var username = username_line.text.strip_edges()
	var password = password_line.text.strip_edges()
	var confirm = confirm_line.text.strip_edges()
	if username == "" or password == "" or confirm == "":
		_show_error("Todos los campos son obligatorios.")
		return
	if password != confirm:
		_show_error("Las contraseñas no coinciden.")
		return
	register_user(username, password)

func _on_back_pressed():
	get_tree().change_scene_to_file("res://login/control.tscn")

func register_user(username: String, password: String):
	var request = HTTPRequest.new()
	add_child(request)
	request.request_completed.connect(_on_register_response)

	var form = {
		"username": username,
		"password": password
	}
	var body = Utils.http_build_query(form)
	var headers = ["Content-Type: application/x-www-form-urlencoded"]

	request.request("http://localhost/blackjack_api/register.php", headers, HTTPClient.METHOD_POST, body)

func _on_register_response(result, response_code, headers, body):
	var response = body.get_string_from_utf8()
	match response:
		"OK":
			print("✅ Usuario registrado.")
			get_tree().change_scene_to_file("res://login/control.tscn")
		"USER_EXISTS":
			_show_error("❌ El usuario ya existe.")
		"DB_ERROR":
			_show_error("❌ Error en la base de datos.")
		_:
			_show_error("⚠️ Respuesta inesperada: %s" % response)


func _show_error(msg: String):
	error_label.text = msg
	error_label.visible = true
