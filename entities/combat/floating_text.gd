extends Node2D

# Crisp floating combat & loot text popup (-48, УСТАЛОСТЬ!, +35 ЗОЛОТА)

var text: String = ""
var text_color: Color = Color("#ffd978")
var _life: float = 0.75
var _vel: Vector2 = Vector2(0, -52)
var _lbl: Label


func setup(pos: Vector2, msg: String, col: Color = Color("#ffd978"), font_sz: int = 16) -> void:
	global_position = pos + Vector2(randf_range(-10, 10), -26)
	text = msg
	text_color = col
	_lbl = Label.new()
	_lbl.text = msg
	_lbl.position = Vector2(-60, -12)
	_lbl.custom_minimum_size = Vector2(120, 0)
	_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl.add_theme_font_size_override("font_size", font_sz)
	_lbl.add_theme_color_override("font_color", col)
	_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	_lbl.add_theme_constant_override("outline_size", 4)
	add_child(_lbl)


func _process(delta: float) -> void:
	position += _vel * delta
	_vel.y = lerpf(_vel.y, -10.0, 5.0 * delta)
	_life -= delta
	if _life < 0.25 and _lbl:
		_lbl.modulate.a = maxf(0.0, _life / 0.25)
	if _life <= 0.0:
		queue_free()
