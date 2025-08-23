extends Control
const LOGIN_URL = "http://localhost/blackjack_api/login.php" 

@onready var username_line = $Panel/username_line
@onready var password_line = $Panel/password_line
@onready var error_label = $Panel/error_label

func _ready():
	$Panel/login_button.pressed.connect(_on_login_pressed)
	$Panel/register_button.pressed.connect(_on_register_pressed)

func _on_login_pressed():
	var username = username_line.text.strip_edges()
	var password = password_line.text.strip_edges()
	if username == "" or password == "":
		_show_error("Todos los campos son obligatorios.")
		return
	login_user(username, password)

func _on_register_pressed():
	get_tree().change_scene_to_file("res://login/register.tscn")

func login_user(username: String, password: String):
	var request = HTTPRequest.new()
	add_child(request)
	request.request_completed.connect(_on_login_response)

	var form = {
		"username": username,
		"password": password
	}
	var body = Utils.http_build_query(form)
	var headers = ["Content-Type: application/x-www-form-urlencoded"]

	request.request("http://localhost/blackjack_api/login.php", headers, HTTPClient.METHOD_POST, body)

func _on_login_response(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
	var response = body.get_string_from_utf8()
	match response:
		"OK":
			Global.logged_user = $Panel/username_line.text.strip_edges()
			print("✅ Login exitoso como:", Global.logged_user)
			get_tree().change_scene_to_file("res://menus/main_menu.tscn")
		"INVALID_PASS":
			_show_error("❌ Contraseña incorrecta.")
		"NO_USER":
			_show_error("❌ Usuario no encontrado.")
		"DB_ERROR":
			_show_error("❌ Error en la base de datos.")
		_:
			_show_error("⚠️ Respuesta inesperada: %s" % response)

func _show_error(msg: String):
	error_label.text = msg
	error_label.visible = true
