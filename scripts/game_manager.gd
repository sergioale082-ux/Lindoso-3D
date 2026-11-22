extends Node3D
## Lindoso 3D - regras, turnos, vitória, tabuleiro e interface.
## Regras: 6 para sair da base | 6 joga de novo | comer manda o peão à base
## (exceto em casas seguras, marcadas em dourado) | vence quem levar os 4 peões ao centro.

enum State { MENU, WAIT_ROLL, WAIT_PICK, BUSY, GAME_OVER }

var state: State = State.MENU
var players: Array[LudoPlayer] = []
var current := 0
var dice_value := 0
var movable: Array[int] = []
var _game_id := 0

var camera: Camera3D
var dice: Dice3D
var turn_label: Label
var msg_label: Label
var roll_button: Button
var pick_box: HBoxContainer
var pick_buttons: Array[Button] = []
var menu_panel: Control
var win_panel: Control
var win_label: Label


func _ready() -> void:
	randomize()
	_build_environment()
	_build_board()
	_build_ui()
	_show_menu()


# ---------------------------------------------------------------- cena 3D

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.53, 0.81, 0.98)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.6
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 25, 0)
	sun.shadow_enabled = true
	add_child(sun)

	# Câmera a 45 graus; KEEP_WIDTH garante o tabuleiro inteiro em tela vertical
	camera = Camera3D.new()
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.fov = 58.0
	add_child(camera)
	camera.position = Vector3(0, 12, 12)
	camera.look_at(Vector3.ZERO)
	camera.make_current()

	dice = Dice3D.new()
	dice.position = Vector3(0, 0.9, 10)
	add_child(dice)


func _mat(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.6
	return m


func _box(size: Vector3, pos: Vector3, col: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = _mat(col)
	mi.position = pos
	add_child(mi)
	return mi


func _disc(radius: float, height: float, pos: Vector3, col: Color) -> void:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = radius
	c.bottom_radius = radius
	c.height = height
	mi.mesh = c
	mi.material_override = _mat(col)
	mi.position = pos
	add_child(mi)


func _triangle(a: Vector3, b: Vector3, c: Vector3, col: Color) -> void:
	var mesh := ArrayMesh.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([a, b, c])
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.UP, Vector3.UP, Vector3.UP])
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var m := _mat(col)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	add_child(mi)


func _cell_world(g: Vector2i) -> Vector3:
	return Vector3(g.x - 7.0, 0.0, g.y - 7.0)


func _build_board() -> void:
	# Mesa
	_box(Vector3(18, 0.3, 21), Vector3(0, -0.25, 1.5), Color(0.55, 0.85, 0.5))

	# Bases coloridas com 4 encaixes
	for s in 4:
		var c: Color = LudoPlayer.COLORS[s]
		var bc: Vector2 = LudoPlayer.BASE_CENTERS[s]
		var wp := Vector3(bc.x - 7.0, 0.0, bc.y - 7.0)
		_box(Vector3(5, 0.12, 5), wp, c.lightened(0.15))
		for i in 4:
			var off: Vector2 = LudoPlayer.SLOT_OFFSETS[i] * 0.9
			_disc(0.5, 0.04, wp + Vector3(off.x, 0.07, off.y), Color.WHITE)

	# 52 casas da trilha
	for idx in 52:
		var g: Vector2i = LudoPlayer.TRACK[idx]
		var col := Color(1.0, 0.98, 0.88)
		var start_seat: int = LudoPlayer.START_INDEX.find(idx)
		if start_seat >= 0:
			col = LudoPlayer.COLORS[start_seat]
		var wp := _cell_world(g)
		_box(Vector3(0.92, 0.2, 0.92), wp, col)
		if idx in LudoPlayer.SAFE_CELLS:
			_disc(0.25, 0.04, wp + Vector3(0, 0.11, 0), Color(1.0, 0.8, 0.1))

	# Reta final
	for s in 4:
		for g in LudoPlayer.HOME[s]:
			_box(Vector3(0.92, 0.2, 0.92), _cell_world(g), (LudoPlayer.COLORS[s] as Color).lightened(0.1))

	# Centro: 4 triângulos coloridos
	var y := 0.11
	var tl := Vector3(-1.5, y, -1.5)
	var tr := Vector3(1.5, y, -1.5)
	var bl := Vector3(-1.5, y, 1.5)
	var br := Vector3(1.5, y, 1.5)
	var mid := Vector3(0, y, 0)
	_triangle(tl, bl, mid, LudoPlayer.COLORS[0])  # esquerda: vermelho
	_triangle(tl, tr, mid, LudoPlayer.COLORS[1])  # topo: verde
	_triangle(tr, br, mid, LudoPlayer.COLORS[2])  # direita: amarelo
	_triangle(bl, br, mid, LudoPlayer.COLORS[3])  # baixo: azul


# ---------------------------------------------------------------- interface

func _style_button(b: Button, col: Color) -> void:
	for st in ["normal", "hover", "pressed", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = col if st != "pressed" else col.darkened(0.25)
		if st == "disabled":
			sb.bg_color = col.darkened(0.4)
		sb.set_corner_radius_all(32)
		sb.set_border_width_all(6)
		sb.border_color = Color.WHITE
		b.add_theme_stylebox_override(st, sb)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	b.add_theme_constant_override("outline_size", 8)


func _make_button(text: String, min_size: Vector2, font_size: int, col: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", font_size)
	_style_button(b, col)
	return b


func _make_label(text: String, font_size: int, col: Color = Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 12)
	return l


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	# Topo: vez do jogador + botão Menu
	var top := HBoxContainer.new()
	top.anchor_right = 1.0
	top.offset_left = 20
	top.offset_right = -20
	top.offset_top = 30
	top.add_theme_constant_override("separation", 12)
	root.add_child(top)
	turn_label = _make_label("", 48)
	turn_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(turn_label)
	var menu_btn := _make_button("Menu", Vector2(170, 90), 38, Color(0.35, 0.35, 0.5))
	menu_btn.pressed.connect(_show_menu)
	top.add_child(menu_btn)

	msg_label = _make_label("", 40)
	msg_label.anchor_right = 1.0
	msg_label.offset_left = 20
	msg_label.offset_right = -20
	msg_label.offset_top = 140
	msg_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(msg_label)

	# Rodapé: botões de peão + rolar dado
	var bottom := VBoxContainer.new()
	bottom.anchor_left = 0.0
	bottom.anchor_right = 1.0
	bottom.anchor_top = 1.0
	bottom.anchor_bottom = 1.0
	bottom.offset_left = 20
	bottom.offset_right = -20
	bottom.offset_top = -40
	bottom.offset_bottom = -40
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom.add_theme_constant_override("separation", 18)
	root.add_child(bottom)

	pick_box = HBoxContainer.new()
	pick_box.alignment = BoxContainer.ALIGNMENT_CENTER
	pick_box.add_theme_constant_override("separation", 14)
	bottom.add_child(pick_box)
	for i in 4:
		var b := _make_button(str(i + 1), Vector2(160, 160), 70, Color(0.5, 0.5, 0.5))
		b.pressed.connect(_on_pick_pressed.bind(i))
		pick_box.add_child(b)
		pick_buttons.append(b)
	pick_box.hide()

	roll_button = _make_button("ROLAR DADO", Vector2(0, 180), 68, Color(1.0, 0.55, 0.1))
	roll_button.pressed.connect(_roll)
	bottom.add_child(roll_button)

	# Menu inicial
	menu_panel = ColorRect.new()
	(menu_panel as ColorRect).color = Color(0.1, 0.15, 0.4, 0.94)
	menu_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(menu_panel)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu_panel.add_child(center)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 26)
	center.add_child(vb)
	vb.add_child(_make_label("LINDOSO 3D", 96, Color(1, 0.85, 0.2)))
	vb.add_child(_make_label("Escolha o modo", 44))
	var modes := [
		["1 Jogador vs 3 Bots", 1, Color(0.9, 0.25, 0.25)],
		["2 Jogadores", 2, Color(0.2, 0.7, 0.3)],
		["3 Jogadores", 3, Color(0.95, 0.7, 0.1)],
		["4 Jogadores", 4, Color(0.2, 0.45, 0.95)],
	]
	for m in modes:
		var b := _make_button(m[0], Vector2(620, 150), 52, m[2])
		b.pressed.connect(_start_game.bind(m[1]))
		vb.add_child(b)

	# Tela de vitória
	win_panel = ColorRect.new()
	(win_panel as ColorRect).color = Color(0, 0, 0, 0.75)
	win_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(win_panel)
	var wc := CenterContainer.new()
	wc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	win_panel.add_child(wc)
	var wv := VBoxContainer.new()
	wv.add_theme_constant_override("separation", 40)
	wc.add_child(wv)
	win_label = _make_label("", 80)
	wv.add_child(win_label)
	var again := _make_button("Jogar de novo", Vector2(620, 160), 56, Color(0.2, 0.7, 0.3))
	again.pressed.connect(_show_menu)
	wv.add_child(again)
	win_panel.hide()


func _show_menu() -> void:
	_game_id += 1
	state = State.MENU
	_clear_players()
	pick_box.hide()
	roll_button.hide()
	turn_label.text = ""
	msg_label.text = ""
	win_panel.hide()
	menu_panel.show()


# ---------------------------------------------------------------- partida

func _clear_players() -> void:
	for p in players:
		p.queue_free()
	players.clear()


func _start_game(humans: int) -> void:
	_game_id += 1
	_clear_players()
	var seats: Array[int]
	match humans:
		2: seats = [0, 2]
		3: seats = [0, 1, 2]
		_: seats = [0, 1, 2, 3]
	for n in seats.size():
		var p := LudoPlayer.new()
		add_child(p)
		p.setup(seats[n], n >= humans)  # humanos primeiro, o resto são bots
		players.append(p)
	current = 0
	menu_panel.hide()
	win_panel.hide()
	_begin_turn()


func _begin_turn() -> void:
	var gid := _game_id
	var p := players[current]
	state = State.WAIT_ROLL
	dice.set_tint(p.color)
	turn_label.text = "Vez: %s%s" % [LudoPlayer.NAMES[p.seat], " (Bot)" if p.is_bot else ""]
	turn_label.add_theme_color_override("font_color", p.color.lightened(0.2))
	pick_box.hide()
	roll_button.visible = not p.is_bot
	roll_button.disabled = false
	if p.is_bot:
		await get_tree().create_timer(0.8).timeout
		if gid != _game_id:
			return
		_roll()


func _roll() -> void:
	if state != State.WAIT_ROLL:
		return
	state = State.BUSY
	roll_button.disabled = true
	var gid := _game_id
	var p := players[current]
	dice_value = await dice.roll()
	if gid != _game_id:
		return
	msg_label.text = "%s tirou %d" % [LudoPlayer.NAMES[p.seat], dice_value]
	movable = p.movable_pawns(dice_value)

	if movable.is_empty():
		msg_label.text += " - sem jogadas"
		await get_tree().create_timer(1.0).timeout
		if gid != _game_id:
			return
		_next_turn()
	elif p.is_bot:
		await get_tree().create_timer(0.5).timeout
		if gid != _game_id:
			return
		_do_move(LudoBot.choose(p, dice_value, players))
	elif movable.size() == 1:
		await get_tree().create_timer(0.4).timeout
		if gid != _game_id:
			return
		_do_move(movable[0])
	else:
		_show_pick(p)


func _show_pick(p: LudoPlayer) -> void:
	state = State.WAIT_PICK
	roll_button.hide()
	msg_label.text += "\nToque no peão ou no botão"
	for i in 4:
		var ok := i in movable
		pick_buttons[i].visible = ok
		if ok:
			_style_button(pick_buttons[i], p.color.darkened(0.1))
			p.set_highlight(i, true)
	pick_box.show()


func _on_pick_pressed(i: int) -> void:
	if state == State.WAIT_PICK and i in movable:
		_do_move(i)


func _unhandled_input(event: InputEvent) -> void:
	if state != State.WAIT_PICK:
		return
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	var p := players[current]
	var best := -1
	var best_d := 110.0
	for i in movable:
		var sp := camera.unproject_position(p.pawns[i].global_position + Vector3(0, 0.5, 0))
		var d := sp.distance_to(mb.position)
		if d < best_d:
			best_d = d
			best = i
	if best >= 0:
		_do_move(best)


func _do_move(i: int) -> void:
	state = State.BUSY
	var gid := _game_id
	var p := players[current]
	p.clear_highlights()
	pick_box.hide()
	await p.move_pawn(i, dice_value)
	if gid != _game_id:
		return
	await _resolve_capture(p, i)
	if gid != _game_id:
		return
	if p.all_finished():
		_win(p)
		return
	if dice_value == 6:
		msg_label.text = "Tirou 6, joga de novo!"
		_begin_turn()
	else:
		_next_turn()


## Comer: peões inimigos na mesma casa (que não seja segura) voltam à base.
func _resolve_capture(p: LudoPlayer, i: int) -> void:
	var cell := p.abs_index(i)
	if cell < 0 or cell in LudoPlayer.SAFE_CELLS:
		return
	var hit := false
	for other in players:
		if other == p:
			continue
		for j in 4:
			if other.abs_index(j) == cell:
				hit = true
				other.send_to_base(j)
	if hit:
		msg_label.text = "%s comeu um peão!" % LudoPlayer.NAMES[p.seat]
		await get_tree().create_timer(0.7).timeout


func _next_turn() -> void:
	current = (current + 1) % players.size()
	_begin_turn()


func _win(p: LudoPlayer) -> void:
	state = State.GAME_OVER
	roll_button.hide()
	win_label.text = "%s venceu!" % LudoPlayer.NAMES[p.seat]
	win_label.add_theme_color_override("font_color", p.color.lightened(0.2))
	win_panel.show()
