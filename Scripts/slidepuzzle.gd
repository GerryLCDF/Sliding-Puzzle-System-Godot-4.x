extends Node2D

@export_category("sobre la imagen")
@export var image: Texture2D
@export_range(2, 10) var cols: int = 3##divicion en columnas 
@export_range(2, 10) var rows: int = 3##divicion de filas 
@export_range(0.1, 10.0, 0.05) var scale_factor: float = 1.0##escala de la imagen 
@export_category("sobre los colores")
@export var border_color: Color = Color(0.4, 0.2, 0.1)##Colore del borde 
@export var border_width: float = 20.0##ancho del margen que rodea a la imagen 
@export var piece_bg_color: Color = Color.WHITE##Color que se le da a la pieza faltante 
@export var scene_bg_color: Color = Color(0.2, 0.2, 0.2) ##color para usarce de fondo 

@onready var punto: Node2D = $punto
@onready var win_label: Label = $Ganaste

var piece_size := Vector2()
var pieces: Array = []
var matrix: Array = []
var empty_pos := Vector2i()
var is_shuffling := false
var is_solved := false
var last_piece: TextureRect


func _ready():
	# 🎨 Fondo de color plano desde (0,0) del Node2D y muy grande
	var scene_bg := ColorRect.new()
	scene_bg.color = scene_bg_color
	scene_bg.position = Vector2.ZERO
	scene_bg.size = Vector2(5000, 5000) 
	scene_bg.z_index = -1000
	add_child(scene_bg)

	if win_label:
		win_label.visible = true
		win_label.modulate.a = 0.0

	if not image:
		return

	var img = image.get_image()
	img.resize(img.get_width() * scale_factor, img.get_height() * scale_factor)
	piece_size = Vector2(img.get_width() / cols, img.get_height() / rows)

	var puzzle_size = Vector2(img.get_width(), img.get_height())
	var base_pos = punto.global_position

	# Marco
	var border_rect = ColorRect.new()
	border_rect.color = border_color
	border_rect.size = puzzle_size + Vector2(border_width * 2, border_width * 2)
	border_rect.position = base_pos - Vector2(border_width, border_width)
	border_rect.z_index = -20
	add_child(border_rect)

	# Fondo de piezas
	for y in range(rows):
		for x in range(cols):
			var bg_rect := ColorRect.new()
			bg_rect.color = piece_bg_color
			bg_rect.size = piece_size
			bg_rect.position = base_pos + Vector2(x, y) * piece_size
			bg_rect.z_index = -10
			add_child(bg_rect)

	matrix.clear()
	for y in range(rows):
		matrix.append([])
		for x in range(cols):
			matrix[y].append(null)


	matrix.clear()
	for y in range(rows):
		matrix.append([])
		for x in range(cols):
			matrix[y].append(null)

	for y in range(rows):
		for x in range(cols):
			if x == cols - 1 and y == rows - 1:
				empty_pos = Vector2i(x, y)
				continue

			var region = Rect2(Vector2(x, y) * piece_size, piece_size)
			var sub_img = img.get_region(region)
			var tex = ImageTexture.create_from_image(sub_img)

			var tr := TextureRect.new()
			tr.texture = tex
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP
			tr.size = piece_size
			tr.position = base_pos + Vector2(x, y) * piece_size
			tr.mouse_filter = Control.MOUSE_FILTER_PASS
			add_child(tr)

			var piece = {
				"tex_rect": tr,
				"original_pos": Vector2i(x, y)
			}
			matrix[y][x] = piece
			pieces.append(piece)

	# Última pieza oculta
	var last_region = Rect2(Vector2(cols - 1, rows - 1) * piece_size, piece_size)
	var last_img = img.get_region(last_region)
	var last_tex = ImageTexture.create_from_image(last_img)

	last_piece = TextureRect.new()
	last_piece.texture = last_tex
	last_piece.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	last_piece.stretch_mode = TextureRect.STRETCH_KEEP
	last_piece.size = piece_size
	last_piece.position = base_pos + Vector2(cols - 1, rows - 1) * piece_size
	last_piece.visible = false
	add_child(last_piece)

	shuffle_pieces()

func shuffle_pieces():
	is_shuffling = true
	is_solved = false
	if win_label:
		win_label.visible = false
		win_label.modulate.a = 0.0

	var num_moves = cols * rows * 10 
	for i in range(num_moves):
		await get_tree().create_timer(0.02).timeout
		random_move()
	is_shuffling = false

func random_move():
	var directions = [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]
	directions.shuffle()

	for dir in directions:
		var new_pos = empty_pos + dir
		if new_pos.x >= 0 and new_pos.x < cols and new_pos.y >= 0 and new_pos.y < rows:
			var piece = matrix[new_pos.y][new_pos.x]
			if piece:
				piece["tex_rect"].position = punto.global_position + Vector2(empty_pos) * piece_size
				matrix[empty_pos.y][empty_pos.x] = piece
				matrix[new_pos.y][new_pos.x] = null
				empty_pos = new_pos
			break

func _input(event):
	if is_shuffling or is_solved:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var base_pos = punto.global_position
		var click_pos = (event.position - base_pos) / piece_size
		var piece_pos = Vector2i(click_pos)

		if piece_pos.x >= 0 and piece_pos.x < cols and piece_pos.y >= 0 and piece_pos.y < rows:
			var piece = matrix[piece_pos.y][piece_pos.x]
			if piece and (abs(piece_pos.x - empty_pos.x) + abs(piece_pos.y - empty_pos.y) == 1):
				piece["tex_rect"].position = base_pos + Vector2(empty_pos) * piece_size
				matrix[empty_pos.y][empty_pos.x] = piece
				matrix[piece_pos.y][piece_pos.x] = null
				empty_pos = piece_pos
				check_if_solved()

func check_if_solved():
	if is_shuffling:
		return

	for piece in pieces:
		var expected_pos = punto.global_position + Vector2(piece["original_pos"]) * piece_size
		if piece["tex_rect"].position != expected_pos:
			return

	is_solved = true
	show_last_piece()

func show_last_piece():
	last_piece.visible = true
	last_piece.modulate = Color(1, 1, 1, 0)

	var tween = create_tween()
	tween.tween_property(last_piece, "modulate:a", 1.0, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	if win_label:
		win_label.visible = true
		var tween_label = create_tween()
		tween_label.tween_property(win_label, "modulate:a", 1.0, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
