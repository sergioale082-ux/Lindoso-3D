class_name LudoPlayer
extends Node3D
## Um jogador (cor) com 4 peões 3D e o movimento deles.
## rel: -1 = base | 0..50 = trilha (0 = casa de saída) | 51..55 = reta final | 56 = centro

const BASE_REL = -1
const FINISH_REL = 56
const START_INDEX = [0, 13, 26, 39]
const SAFE_CELLS = [0, 8, 13, 21, 26, 34, 39, 47]
const NAMES = ["Vermelho", "Verde", "Amarelo", "Azul"]
const COLORS = [
	Color(0.93, 0.20, 0.20), Color(0.20, 0.78, 0.30),
	Color(1.00, 0.84, 0.10), Color(0.20, 0.45, 1.00),
]
const BASE_CENTERS = [Vector2(2.5, 2.5), Vector2(11.5, 2.5), Vector2(11.5, 11.5), Vector2(2.5, 11.5)]
const SLOT_OFFSETS = [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]
const CENTER_DIRS = [Vector2(-1, 0), Vector2(0, -1), Vector2(1, 0), Vector2(0, 1)]

# Reta final de cada cor (grade 15x15)
const HOME = [
	[Vector2i(1, 7), Vector2i(2, 7), Vector2i(3, 7), Vector2i(4, 7), Vector2i(5, 7)],
	[Vector2i(7, 1), Vector2i(7, 2), Vector2i(7, 3), Vector2i(7, 4), Vector2i(7, 5)],
	[Vector2i(13, 7), Vector2i(12, 7), Vector2i(11, 7), Vector2i(10, 7), Vector2i(9, 7)],
	[Vector2i(7, 13), Vector2i(7, 12), Vector2i(7, 11), Vector2i(7, 10), Vector2i(7, 9)],
]

# As 52 casas da trilha em cruz, no sentido horário
const TRACK = [
	Vector2i(1, 6), Vector2i(2, 6), Vector2i(3, 6), Vector2i(4, 6), Vector2i(5, 6),
	Vector2i(6, 5), Vector2i(6, 4), Vector2i(6, 3), Vector2i(6, 2), Vector2i(6, 1), Vector2i(6, 0),
	Vector2i(7, 0), Vector2i(8, 0),
	Vector2i(8, 1), Vector2i(8, 2), Vector2i(8, 3), Vector2i(8, 4), Vector2i(8, 5),
	Vector2i(9, 6), Vector2i(10, 6), Vector2i(11, 6), Vector2i(12, 6), Vector2i(13, 6), Vector2i(14, 6),
	Vector2i(14, 7), Vector2i(14, 8),
	Vector2i(13, 8), Vector2i(12, 8), Vector2i(11, 8), Vector2i(10, 8), Vector2i(9, 8),
	Vector2i(8, 9), Vector2i(8, 10), Vector2i(8, 11), Vector2i(8, 12), Vector2i(8, 13), Vector2i(8, 14),
	Vector2i(7, 14), Vector2i(6, 14),
	Vector2i(6, 13), Vector2i(6, 12), Vector2i(6, 11), Vector2i(6, 10), Vector2i(6, 9),
	Vector2i(5, 8), Vector2i(4, 8), Vector2i(3, 8), Vector2i(2, 8), Vector2i(1, 8), Vector2i(0, 8),
	Vector2i(0, 7), Vector2i(0, 6),
]

var seat := 0
var is_bot := false
var color := Color.WHITE
var pawns: Array[Node3D] = []
var rel: Array[int] = [-1, -1, -1, -1]
var _materials: Array[StandardMaterial3D] = []
var _labels: Array[Label3D] = []


func setup(p_seat: int, p_is_bot: bool) -> void:
	seat = p_seat
	is_bot = p_is_bot
	color = COLORS[seat]
	for i in 4:
		_make_pawn(i)
		pawns[i].position = world_pos_for(i)


func _make_pawn(i: int) -> void:
	var root := Node3D.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.35
	mat.emission_enabled = true
	mat.emission = color.lightened(0.4)
	mat.emission_energy_multiplier = 0.0

	var body := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.18
	cyl.bottom_radius = 0.32
	cyl.height = 0.5
	body.mesh = cyl
	body.material_override = mat
	body.position.y = 0.25
	root.add_child(body)

	var head := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.24
	sph.height = 0.48
	head.mesh = sph
	head.material_override = mat
	head.position.y = 0.66
	root.add_child(head)

	var lbl := Label3D.new()
	lbl.text = str(i + 1)
	lbl.font_size = 72
	lbl.pixel_size = 0.009
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.outline_size = 18
	lbl.position = Vector3(0, 1.3, 0)
	lbl.visible = false
	root.add_child(lbl)

	add_child(root)
	pawns.append(root)
	_materials.append(mat)
	_labels.append(lbl)


func abs_index(i: int) -> int:
	var r: int = rel[i]
	if r < 0 or r > 50:
		return -1
	var idx: int = (START_INDEX[seat] + r) % 52
	return idx


func world_pos_for(i: int) -> Vector3:
	var r: int = rel[i]
	var g := Vector2.ZERO
	var y := 0.1
	var jitter := Vector2((i % 2) - 0.5, floorf(i / 2.0) - 0.5) * 0.22
	if r == BASE_REL:
		g = BASE_CENTERS[seat] + SLOT_OFFSETS[i] * 0.9
		y = 0.08
	elif r <= 50:
		var idx: int = (START_INDEX[seat] + r) % 52
		g = Vector2(TRACK[idx]) + jitter
	elif r < FINISH_REL:
		g = Vector2(HOME[seat][r - 51]) + jitter
	else:
		var dir: Vector2 = CENTER_DIRS[seat]
		var perp := Vector2(-dir.y, dir.x)
		g = Vector2(7, 7) + dir * 0.7 + perp * (i - 1.5) * 0.28
		y = 0.12
	return Vector3(g.x - 7.0, y, g.y - 7.0)


func can_move(i: int, d: int) -> bool:
	var r: int = rel[i]
	if r == FINISH_REL:
		return false
	if r == BASE_REL:
		return d == 6
	return r + d <= FINISH_REL


func movable_pawns(d: int) -> Array[int]:
	var out: Array[int] = []
	for i in 4:
		if can_move(i, d):
			out.append(i)
	return out


func finished_count() -> int:
	var n := 0
	for r in rel:
		if r == FINISH_REL:
			n += 1
	return n


func all_finished() -> bool:
	return finished_count() == 4


func move_pawn(i: int, d: int) -> void:
	if rel[i] == BASE_REL:
		rel[i] = 0
		await _hop_to(i, world_pos_for(i), 0.3)
		return
	for _s in d:
		rel[i] += 1
		await _hop_to(i, world_pos_for(i), 0.16)


func send_to_base(i: int) -> void:
	rel[i] = BASE_REL
	await _hop_to(i, world_pos_for(i), 0.5)


func set_highlight(i: int, on: bool) -> void:
	_materials[i].emission_energy_multiplier = 0.9 if on else 0.0
	pawns[i].scale = Vector3.ONE * (1.3 if on else 1.0)
	_labels[i].visible = on


func clear_highlights() -> void:
	for i in 4:
		set_highlight(i, false)


func _hop_to(i: int, target: Vector3, dur: float) -> void:
	var p := pawns[i]
	var tw := create_tween()
	tw.tween_method(_hop_step.bind(p, p.position, target), 0.0, 1.0, dur)
	await tw.finished


func _hop_step(t: float, p: Node3D, start: Vector3, target: Vector3) -> void:
	var pos := start.lerp(target, t)
	pos.y += sin(t * PI) * 0.5
	p.position = pos
