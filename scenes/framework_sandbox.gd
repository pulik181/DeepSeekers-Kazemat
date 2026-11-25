extends Node2D

# Core Dungeon Chamber Scene (`scenes/framework_sandbox.tscn`):
# - 2D movement, dynamic cone/radial lighting, and shadow-casting stone pillars
# - Melee sword, 2 magic modes [Q] (Delayed Seal & Shooting Bolt), and breakable barrels/chest
# - Collectible Clue (`clue_template_1`), which unlocks the Ritual Altar (`sandbox_gate_unlocked`)
# - AI Interrogation with Suspect (`suspect_template`) using RITUAL_KEYWORDS

const FiendScene = preload("res://entities/enemies/dungeon_fiend.tscn")
const BarrelScript = preload("res://entities/combat/loot_barrel.gd")

@onready var floor_rect: TextureRect = $Floor
@onready var walls: StaticBody2D = $Walls
@onready var ysort: Node2D = $YSort
@onready var player: CharacterBody2D = $YSort/Inquisitor
@onready var hud: CanvasLayer = $HUD
@onready var iq_ui: CanvasLayer = $InterrogationUI

var room_size: Vector2 = Vector2(1600, 1080)
var suspect_pos: Vector2 = Vector2(-420, -180)
var clue_pos: Vector2 = Vector2(0, -140)
var altar_pos: Vector2 = Vector2(440, -180)
var chest_pos: Vector2 = Vector2(-420, 260)

var clue_node: Node2D = null
var chest_sprite: Sprite2D = null
var gate_sprite: Sprite2D = null
var active_action: String = ""
var _t: float = 0.0


func _ready() -> void:
	player.allow_combat = true
	player.position = Vector2(0, 220)
	player.health_changed.connect(func(_c, _m): hud.refresh())
	player.player_died.connect(_on_player_died)
	iq_ui.verdict_chosen.connect(_on_verdict_chosen)
	CaseManager.state_changed.connect(_sync_sandbox_state)

	_build_sandbox_room()
	_sync_sandbox_state()


func _add_wall(pos: Vector2, sz: Vector2) -> void:
	var col: CollisionShape2D = CollisionShape2D.new()
	var sh: RectangleShape2D = RectangleShape2D.new()
	sh.size = sz
	col.shape = sh
	col.position = pos
	walls.add_child(col)

	var tex_rect: TextureRect = TextureRect.new()
	tex_rect.texture = load("res://assets/sprites/stone_wall_tile.png")
	tex_rect.stretch_mode = TextureRect.STRETCH_TILE
	tex_rect.position = pos - sz * 0.5
	tex_rect.size = sz
	walls.add_child(tex_rect)

	var occ: LightOccluder2D = LightOccluder2D.new()
	occ.position = pos
	var poly: OccluderPolygon2D = OccluderPolygon2D.new()
	var hx: float = sz.x * 0.5
	var hy: float = sz.y * 0.5
	poly.polygon = PackedVector2Array([Vector2(-hx, -hy), Vector2(hx, -hy), Vector2(hx, hy), Vector2(-hx, hy)])
	occ.occluder = poly
	add_child(occ)


func _build_sandbox_room() -> void:
	var half: Vector2 = room_size * 0.5
	floor_rect.texture = load("res://assets/sprites/stone_floor.png")
	floor_rect.stretch_mode = TextureRect.STRETCH_TILE
	floor_rect.position = -half
	floor_rect.size = room_size

	var wt: float = 64.0
	_add_wall(Vector2(0, -half.y + wt * 0.5), Vector2(room_size.x, wt))
	_add_wall(Vector2(0, half.y - wt * 0.5), Vector2(room_size.x, wt))
	_add_wall(Vector2(-half.x + wt * 0.5, 0), Vector2(wt, room_size.y))
	_add_wall(Vector2(half.x - wt * 0.5, 0), Vector2(wt, room_size.y))

	var pillar_tex: Texture2D = load("res://assets/sprites/wall_pillar.png")
	var torch_tex: Texture2D = load("res://assets/sprites/torch.png")
	var light_tex: Texture2D = load("res://assets/sprites/light_radial.png")

	# 4 Shadow-Casting Stone Pillars with Torches
	for ppos in [Vector2(-260, -40), Vector2(260, -40), Vector2(-260, 220), Vector2(260, 220)]:
		var p: StaticBody2D = StaticBody2D.new()
		p.position = ppos
		var col: CollisionShape2D = CollisionShape2D.new()
		var rect: RectangleShape2D = RectangleShape2D.new()
		rect.size = Vector2(44, 38)
		col.shape = rect
		col.position = Vector2(0, 14)
		p.add_child(col)

		var psp: Sprite2D = Sprite2D.new()
		psp.texture = pillar_tex
		p.add_child(psp)

		var tsp: Sprite2D = Sprite2D.new()
		tsp.texture = torch_tex
		tsp.position = Vector2(0, 24)
		p.add_child(tsp)

		var l: PointLight2D = PointLight2D.new()
		l.texture = light_tex
		l.color = Color("#ffaa48")
		l.energy = 1.35
		l.texture_scale = 2.2
		p.add_child(l)

		var occ: LightOccluder2D = LightOccluder2D.new()
		var poly: OccluderPolygon2D = OccluderPolygon2D.new()
		poly.polygon = PackedVector2Array([Vector2(-20, -8), Vector2(20, -8), Vector2(20, 30), Vector2(-20, 30)])
		occ.occluder = poly
		p.add_child(occ)
		ysort.add_child(p)

	# 1. Template Suspect NPC (Left)
	var sinfo: Dictionary = CaseManager.SUSPECTS["suspect_template"]
	var ssp: Sprite2D = Sprite2D.new()
	ssp.texture = load(str(sinfo["sprite"]))
	ssp.position = suspect_pos
	ssp.scale = Vector2(1.1, 1.1)
	ysort.add_child(ssp)

	var slbl: Label = Label.new()
	slbl.text = "👤 %s\n[E] ИИ-Допрос" % str(sinfo["name"])
	slbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slbl.position = suspect_pos + Vector2(-110, -76)
	slbl.custom_minimum_size = Vector2(220, 0)
	slbl.add_theme_font_size_override("font_size", 13)
	slbl.add_theme_color_override("font_color", Color("#9effcb"))
	add_child(slbl)

	# 2. Test Glowing Clue (Center-North)
	if not CaseManager.collected_clues.has("clue_template_1"):
		clue_node = Node2D.new()
		clue_node.position = clue_pos
		var csp: Sprite2D = Sprite2D.new()
		csp.texture = load("res://assets/sprites/evidence_glow.png")
		csp.scale = Vector2(1.25, 1.25)
		clue_node.add_child(csp)
		var cl: PointLight2D = PointLight2D.new()
		cl.texture = light_tex
		cl.color = Color("#4dc4ff")
		cl.energy = 1.6
		cl.texture_scale = 1.8
		clue_node.add_child(cl)
		ysort.add_child(clue_node)

	# 3. Ritual / Verdict Altar & Trigger Gate (Right)
	var asp: Sprite2D = Sprite2D.new()
	asp.texture = load("res://assets/sprites/verdict_altar.png")
	asp.position = altar_pos
	asp.scale = Vector2(1.25, 1.25)
	ysort.add_child(asp)

	gate_sprite = Sprite2D.new()
	gate_sprite.position = Vector2(0, -460)
	gate_sprite.scale = Vector2(1.25, 1.25)
	ysort.add_child(gate_sprite)

	var albl: Label = Label.new()
	albl.text = "🔥 Алтарь Ритуала\n[E] Завершить обряд"
	albl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	albl.position = altar_pos + Vector2(-120, -78)
	albl.custom_minimum_size = Vector2(240, 0)
	albl.add_theme_font_size_override("font_size", 13)
	albl.add_theme_color_override("font_color", Color("#ffd685"))
	add_child(albl)

	# 4. 1 Test Enemy Dummy (Right-South)
	var dummy: CharacterBody2D = FiendScene.instantiate()
	dummy.position = Vector2(420, 220)
	dummy.max_hp = 90
	dummy.move_speed = 115.0
	ysort.add_child(dummy)

	# 5. 1 Test Loot Chest + 2 Breakable Barrels
	chest_sprite = Sprite2D.new()
	chest_sprite.texture = load("res://assets/sprites/chest_closed.png")
	chest_sprite.position = chest_pos
	chest_sprite.scale = Vector2(1.18, 1.18)
	ysort.add_child(chest_sprite)

	for i in range(2):
		var br: StaticBody2D = BarrelScript.new()
		br.setup("sb_barrel_%d" % i, Vector2(-320 + i * 70, 260))
		ysort.add_child(br)


func _sync_sandbox_state() -> void:
	var unlocked: bool = CaseManager.has_flag("sandbox_gate_unlocked")
	if gate_sprite:
		gate_sprite.texture = load("res://assets/sprites/iron_gate_open.png" if unlocked else "res://assets/sprites/iron_gate_closed.png")

	var words: String = ", ".join(CaseManager.get_ritual_keywords())
	if not CaseManager.collected_clues.has("clue_template_1"):
		hud.set_quest("Каземат: Найди Рунный Осколок [E], испытай оружие (ЛКМ/ПКМ/Q) и допроси узника (Руны: %s)" % words)
	else:
		hud.set_quest("Улика найдена! Предъяви её Узнику Каземата [E] или активируй Алтарь Ритуала справа [E]!")


func _process(delta: float) -> void:
	_t += delta
	if is_instance_valid(clue_node):
		clue_node.position.y = clue_pos.y + sin(_t * 4.2) * 4.0

	if CaseManager.ui_locked:
		hud.set_prompt("")
		return

	active_action = ""
	if is_instance_valid(clue_node) and not CaseManager.collected_clues.has("clue_template_1") and player.global_position.distance_to(clue_pos) < 88.0:
		active_action = "pickup_clue"
		hud.set_prompt("[E] Подобрать: Тестовая Улика №1 (Рунный Осколок)")
	elif player.global_position.distance_to(suspect_pos) < 96.0:
		active_action = "interrogate"
		hud.set_prompt("[E] Открыть окно ИИ-допроса: Тестовый Подозреваемый")
	elif player.global_position.distance_to(altar_pos) < 100.0:
		active_action = "altar"
		hud.set_prompt("[E] Алтарь Ритуала (Вынести вердикт)")
	elif not bool(CaseManager.opened_chests.get("sandbox_chest", false)) and player.global_position.distance_to(chest_pos) < 88.0:
		active_action = "chest"
		hud.set_prompt("[E] Открыть тестовый сундук с припасами")
	else:
		hud.set_prompt("")


func _unhandled_input(_event: InputEvent) -> void:
	if CaseManager.ui_locked or active_action.is_empty():
		return
	if Input.is_action_just_pressed("interact"):
		match active_action:
			"pickup_clue":
				CaseManager.add_clue("clue_template_1")
				if is_instance_valid(clue_node):
					clue_node.queue_free()
				_sync_sandbox_state()
			"interrogate":
				iq_ui.open_interrogation("suspect_template")
			"altar":
				iq_ui.open_verdict_menu()
			"chest":
				chest_sprite.texture = load("res://assets/sprites/chest_open.png")
				var msg: String = CaseManager.grant_chest_loot("sandbox_chest", 50, 1, 1, 5)
				hud.show_toast(msg, 4.5)


func _on_verdict_chosen(accused_id: String) -> void:
	var sname: String = str(CaseManager.SUSPECTS.get(accused_id, {"name": accused_id})["name"])
	var words: String = " • ".join(CaseManager.get_ritual_keywords())
	hud.show_ending(
		"РИТУАЛ ДОЗНАНИЯ ЗАВЕРШЁН",
		"Вынесен вердикт в отношении: %s.\nКлючевые рунные знаки обряда активированы: [ %s ]." % [sname, words],
		true
	)


func _on_player_died() -> void:
	hud.show_ending(
		"ТЕСТОВЫЙ БОЙ ОКОНЧЕН",
		"Герой пал в тренировочной песочнице. Нажмите «Перезапустить песочницу», чтобы продолжить тест.",
		false
	)
