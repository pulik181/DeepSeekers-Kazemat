extends StaticBody2D

# Breakable medieval supply barrel/crate that drops gold or potions when hit by sword or magic!

const FloatingTextScript = preload("res://entities/combat/floating_text.gd")

var barrel_id: String = ""
var _smashed: bool = false


func setup(bid: String, pos: Vector2) -> void:
	barrel_id = bid
	position = pos


func _ready() -> void:
	if CaseManager.opened_chests.get(barrel_id, false):
		queue_free()
		return
	add_to_group("breakable_loot")
	collision_layer = 8
	collision_mask = 0
	var col: CollisionShape2D = CollisionShape2D.new()
	var cir: CircleShape2D = CircleShape2D.new()
	cir.radius = 18.0
	col.shape = cir
	add_child(col)

	var sp: Sprite2D = Sprite2D.new()
	sp.texture = load("res://assets/sprites/loot_barrel.png")
	add_child(sp)


func smash() -> void:
	if _smashed:
		return
	_smashed = true
	CaseManager.opened_chests[barrel_id] = true
	AudioManager.play_sfx("hit", -2.0)
	AudioManager.play_sfx("loot", -3.0)

	var roll: int = randi() % 100
	var msg: String = ""
	var col: Color = Color("#ffd966")
	if roll < 28:
		CaseManager.hp_potions += 1
		msg = "+1 Зелье крови [1]"
		col = Color("#ff6e8a")
	elif roll < 54:
		CaseManager.stamina_tonics += 1
		msg = "+1 Бодрость [2]"
		col = Color("#7ce8ff")
	else:
		var g: int = randi_range(12, 26)
		CaseManager.gold += g
		msg = "+%d Золота" % g

	CaseManager.state_changed.emit()

	var ft: Node2D = FloatingTextScript.new()
	get_tree().current_scene.add_child(ft)
	ft.setup(global_position, msg, col, 15)
	queue_free()
