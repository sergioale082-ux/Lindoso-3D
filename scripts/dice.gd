class_name Dice3D
extends Node3D
## Dado 3D com animação. Faces opostas somam 7.

const SIZE = 1.2
# [valor, normal da face, rotação do texto em graus]
const FACES = [
	[1, Vector3(0, 1, 0), Vector3(-90, 0, 0)],
	[6, Vector3(0, -1, 0), Vector3(90, 0, 0)],
	[3, Vector3(1, 0, 0), Vector3(0, 90, 0)],
	[4, Vector3(-1, 0, 0), Vector3(0, -90, 0)],
	[2, Vector3(0, 0, 1), Vector3(0, 0, 0)],
	[5, Vector3(0, 0, -1), Vector3(0, 180, 0)],
]

var value := 1
var _cube: MeshInstance3D
var _mat: StandardMaterial3D


func _ready() -> void:
	_cube = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3.ONE * SIZE
	_cube.mesh = box
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = Color.WHITE
	_mat.roughness = 0.3
	_cube.material_override = _mat
	add_child(_cube)
	for f in FACES:
		var lbl := Label3D.new()
		lbl.text = str(f[0])
		lbl.font_size = 100
		lbl.pixel_size = 0.008
		lbl.modulate = Color(0.1, 0.1, 0.25)
		lbl.position = (f[1] as Vector3) * (SIZE / 2.0 + 0.01)
		lbl.rotation_degrees = f[2]
		_cube.add_child(lbl)


func set_tint(c: Color) -> void:
	_mat.albedo_color = Color.WHITE.lerp(c, 0.35)


## Rola o dado e devolve o valor (1-6) ao fim da animação.
func roll() -> int:
	value = randi_range(1, 6)
	var start_q := Quaternion(_cube.basis.orthonormalized())
	var final_q := Quaternion(_face_basis(value))
	var axis := Vector3(randf() - 0.5, randf() - 0.5, randf() - 0.5)
	if axis.length() < 0.01:
		axis = Vector3.UP
	axis = axis.normalized()

	var spin := create_tween()
	spin.tween_method(_spin_step.bind(start_q, final_q, axis), 0.0, 1.0, 1.0) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	var bounce := create_tween()
	bounce.tween_property(_cube, "position:y", 1.8, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	bounce.tween_property(_cube, "position:y", 0.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	bounce.tween_property(_cube, "position:y", 0.5, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	bounce.tween_property(_cube, "position:y", 0.0, 0.13).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	await spin.finished
	return value


func _spin_step(t: float, start_q: Quaternion, final_q: Quaternion, axis: Vector3) -> void:
	var extra := Quaternion(axis, TAU * 3.0 * t)  # 3 voltas; em t=1 vira identidade
	_cube.basis = Basis(extra * start_q.slerp(final_q, t))


func _face_basis(v: int) -> Basis:
	match v:
		6: return Basis(Vector3.RIGHT, PI)
		3: return Basis(Vector3.BACK, PI / 2.0)
		4: return Basis(Vector3.BACK, -PI / 2.0)
		2: return Basis(Vector3.RIGHT, -PI / 2.0)
		5: return Basis(Vector3.RIGHT, PI / 2.0)
	return Basis()
