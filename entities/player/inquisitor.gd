extends CharacterBody2D

# Inquisitor Controller v7:
# - Wall Line-of-Sight raycast check so Sword & Spells NEVER hit through walls!
# - 2 Spell Modes [Q]: Mode 0 = Delayed Elemental AoE Seal, Mode 1 = Shooting Elemental Bolt
# - 4 Elements: Fire, Ice, Lightning, Shadow + Stamina/Exhaustion + Potions [1]/[2]
signal health_changed(current_hp: int, max_hp: int)
signal player_died

const ProjectileScript = preload("res://entities/combat/projectile.gd")
const DelayedSpellScript = preload("res://entities/combat/delayed_spell.gd")
const FloatingTextScript = preload("res://entities/combat/floating_text.gd")

@export var move_speed: float = 300.0
@export var dash_speed: float = 770.0
@export var allow_combat: bool = true

@onready var sprite: Sprite2D = $Sprite2D
@onready var ambient_light: PointLight2D = $AmbientLight
@onready var lantern_pivot: Node2D = $LanternPivot
@onready var beam_light: PointLight2D = $LanternPivot/BeamLight
@onready var weapon_pivot: Node2D = $WeaponPivot
@onready var sword_sprite: Sprite2D = $WeaponPivot/SwordSprite
@onready var cam: Camera2D = $Camera2D

var _elem_color: Color = Color("#ff8438")
var _elem_id: String = "fire"
var _dash_timer: float = 0.0
var _dash_cd: float = 0.0
var _dash_ghost_cd: float = 0.0
var _dash_dir: Vector2 = Vector2.RIGHT

var _melee_cd: float = 0.0
var _magic_cd: float = 0.0
var _invuln_timer: float = 0.0
var _exhausted_timer: float = 0.0
var _exhaust_voice_cd: float = 0.0

var _combo_side: int = 1
var _slash_anim: float = 0.0
var _slash_base_angle: float = 0.0
var _sword_swing_offset: float = 0.55

var _walk_bob: float = 0.0
var _flicker_t: float = 0.0
var _shake_strength: float = 0.0


func _ready() -> void:
	add_to_group("player")
	apply_hero_appearance()
	health_changed.emit(CaseManager.player_hp, CaseManager.player_max_hp)


func apply_hero_appearance() -> void:
	var sp_path: String = CaseManager.get_hero_sprite_path()
	if ResourceLoader.exists(sp_path):
		sprite.texture = load(sp_path)
	if ResourceLoader.exists("res://assets/sprites/sword_blade.png"):
		sword_sprite.texture = load("res://assets/sprites/sword_blade.png")
	if ResourceLoader.exists("res://assets/sprites/light_radial.png"):
		ambient_light.texture = load("res://assets/sprites/light_radial.png")
	if ResourceLoader.exists("res://assets/sprites/light_cone.png"):
		beam_light.texture = load("res://assets/sprites/light_cone.png")

	var skin_info: Dictionary = CaseManager.get_skin_data()
	var elem_info: Dictionary = CaseManager.get_element_data()
	beam_light.color = skin_info["light_color"]
	ambient_light.color = skin_info["light_color"].lightened(0.15)
	_elem_color = elem_info["color"]
	_elem_id = str(elem_info["id"])
	beam_light.texture_scale = 2.10 if CaseManager.hero_skin == 2 else 1.82
	sword_sprite.visible = allow_combat


func _has_clear_los(target: Node2D) -> bool:
	var q: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(global_position, target.global_position, 1)
	var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(q)
	return hit.is_empty() or hit.get("collider") == target


func _physics_process(delta: float) -> void:
	sword_sprite.visible = allow_combat
	_update_visual_effects(delta)

	if CaseManager.ui_locked or CaseManager.player_hp <= 0:
		velocity = Vector2.ZERO
		return

	if _dash_cd > 0.0: _dash_cd -= delta
	if _melee_cd > 0.0: _melee_cd -= delta
	if _magic_cd > 0.0: _magic_cd -= delta
	if _invuln_timer > 0.0: _invuln_timer -= delta
	if _exhaust_voice_cd > 0.0: _exhaust_voice_cd -= delta

	if _exhausted_timer > 0.0:
		_exhausted_timer -= delta
		CaseManager.player_stamina = minf(CaseManager.player_max_stamina, CaseManager.player_stamina + 35.0 * delta)
		queue_redraw()
	elif _dash_timer <= 0.0 and _melee_cd <= 0.08:
		CaseManager.player_stamina = minf(CaseManager.player_max_stamina, CaseManager.player_stamina + 28.0 * delta)

	# Switch Spell Mode [Q]: Delayed Seal <-> Shooting Bolt
	if Input.is_action_just_pressed("toggle_spell_mode"):
		CaseManager.toggle_spell_mode()
		var mode_txt: String = "Режим: Стреляющий Заряд" if CaseManager.spell_mode == 1 else "Режим: Задержанная Печать"
		_spawn_popup(mode_txt, _elem_color)

	if Input.is_action_just_pressed("use_hp_potion"):
		if CaseManager.use_healing_potion():
			_spawn_popup("+60 HP", Color("#7dffb3"))
	if Input.is_action_just_pressed("use_stamina_tonic"):
		if CaseManager.use_stamina_tonic():
			_exhausted_timer = 0.0
			_spawn_popup("+100% БОДРОСТЬ", Color("#7ce8ff"))

	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var to_mouse: Vector2 = get_global_mouse_position() - global_position
	var aim_dir: Vector2 = to_mouse.normalized() if to_mouse.length_squared() > 1.0 else Vector2.RIGHT
	sprite.flip_h = aim_dir.x < 0.0
	lantern_pivot.rotation = lerp_angle(lantern_pivot.rotation, aim_dir.angle(), 16.0 * delta)

	var target_sword_rot: float = aim_dir.angle() + _sword_swing_offset * float(_combo_side)
	weapon_pivot.rotation = lerp_angle(weapon_pivot.rotation, target_sword_rot, 26.0 * delta)

	if Input.is_action_just_pressed("dash") and _dash_cd <= 0.0 and _exhausted_timer <= 0.0:
		if _consume_stamina(24.0):
			_dash_dir = input_dir if input_dir != Vector2.ZERO else aim_dir
			_dash_timer = 0.16
			_dash_cd = 0.46
			_invuln_timer = 0.28
			AudioManager.play_sfx("dash", -3.0)

	if allow_combat and _exhausted_timer <= 0.0:
		if Input.is_action_just_pressed("attack_melee") and _melee_cd <= 0.0:
			if _consume_stamina(14.0):
				_perform_sword_slash(aim_dir)
		elif Input.is_action_pressed("attack_ranged") and _magic_cd <= 0.0:
			if CaseManager.spell_mode == 1:
				if _consume_stamina(16.0):
					_cast_shooting_bolt(aim_dir)
			elif Input.is_action_just_pressed("attack_ranged"):
				if _consume_stamina(28.0):
					_cast_delayed_seal()

	var spd_mult: float = 0.64 if _exhausted_timer > 0.0 else 1.0
	if _dash_timer > 0.0:
		_dash_timer -= delta
		velocity = _dash_dir * dash_speed
		_dash_ghost_cd -= delta
		if _dash_ghost_cd <= 0.0:
			_dash_ghost_cd = 0.045
			_spawn_dash_ghost()
	else:
		velocity = velocity.move_toward(input_dir * (move_speed * spd_mult), 2200.0 * delta)

	move_and_slide()

	if velocity.length() > 18.0:
		_walk_bob += delta * 15.0
		sprite.position.y = -14.0 - absf(sin(_walk_bob)) * 4.0
	else:
		sprite.position.y = lerpf(sprite.position.y, -14.0, 12.0 * delta)


func _consume_stamina(cost: float) -> bool:
	if CaseManager.player_stamina < 5.0:
		_trigger_exhaustion()
		return false
	CaseManager.player_stamina = maxf(0.0, CaseManager.player_stamina - cost)
	if CaseManager.player_stamina <= 0.5:
		_trigger_exhaustion()
	return true


func _trigger_exhaustion() -> void:
	_exhausted_timer = 1.25
	_spawn_popup("УСТАЛОСТЬ!", Color("#ff9d5c"))
	if _exhaust_voice_cd <= 0.0:
		_exhaust_voice_cd = 9.5
		var hkey: String = CaseManager.get_hero_voice_key()
		AudioManager.speak_line(hkey + "_exhausted", hkey)


func _perform_sword_slash(aim_dir: Vector2) -> void:
	_melee_cd = 0.26
	_combo_side = -_combo_side
	_sword_swing_offset = 1.25
	_slash_anim = 1.0
	_slash_base_angle = aim_dir.angle()
	velocity += aim_dir * 125.0
	AudioManager.play_sfx("slash", -1.5)

	var dmg: int = 24 + CaseManager.bonus_sword_dmg
	var hit_any: bool = false

	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		var diff: Vector2 = enemy.global_position - global_position
		if diff.length() <= 116.0 and diff.normalized().dot(aim_dir) >= 0.05:
			# Check wall line-of-sight so sword CANNOT hit through walls!
			if _has_clear_los(enemy) and enemy.has_method("take_damage"):
				enemy.take_damage(dmg, aim_dir * 360.0, "physical")
				_spawn_hit_sparks(enemy.global_position)
				hit_any = true

	for barrel in get_tree().get_nodes_in_group("breakable_loot"):
		if is_instance_valid(barrel) and barrel.global_position.distance_to(global_position) <= 104.0:
			if _has_clear_los(barrel) and barrel.has_method("smash"):
				barrel.smash()
				hit_any = true

	if hit_any:
		add_camera_shake(5.5)
	queue_redraw()


func _cast_shooting_bolt(aim_dir: Vector2) -> void:
	_magic_cd = 0.34
	var bolt: Area2D = ProjectileScript.new()
	bolt.global_position = global_position + aim_dir * 26.0
	var spd: float = 820.0 if _elem_id == "lightning" else 700.0
	bolt.setup(aim_dir, spd, 18 + CaseManager.bonus_magic_dmg / 2, true, _elem_color, _elem_id)
	get_tree().current_scene.add_child(bolt)
	AudioManager.play_sfx("firebolt", -3.5)


func _cast_delayed_seal() -> void:
	_magic_cd = 1.10
	var target_pos: Vector2 = get_global_mouse_position()
	var to_target: Vector2 = target_pos - global_position
	if to_target.length() > 380.0:
		target_pos = global_position + to_target.normalized() * 380.0

	# Clamp target in front of walls so you cannot cast delayed runes behind solid walls!
	var q: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(global_position, target_pos, 1)
	var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		target_pos = hit["position"] - to_target.normalized() * 26.0

	var spell: Node2D = DelayedSpellScript.new()
	spell.setup(target_pos, 96.0, 0.72, 48 + CaseManager.bonus_magic_dmg, true, _elem_color, _elem_id)
	get_tree().current_scene.add_child(spell)


func _spawn_hit_sparks(pos: Vector2) -> void:
	var spk: CPUParticles2D = CPUParticles2D.new()
	spk.global_position = pos
	spk.emitting = true
	spk.one_shot = true
	spk.explosiveness = 0.95
	spk.amount = 14
	spk.lifetime = 0.28
	spk.spread = 180.0
	spk.gravity = Vector2.ZERO
	spk.initial_velocity_min = 90.0
	spk.initial_velocity_max = 220.0
	spk.scale_amount_min = 2.5
	spk.scale_amount_max = 4.5
	spk.color = _elem_color.lightened(0.35)
	get_tree().current_scene.add_child(spk)
	get_tree().create_timer(0.35).timeout.connect(spk.queue_free)


func _spawn_popup(msg: String, col: Color) -> void:
	var ft: Node2D = FloatingTextScript.new()
	get_tree().current_scene.add_child(ft)
	ft.setup(global_position, msg, col, 15)


func _spawn_dash_ghost() -> void:
	if sprite.texture == null or get_parent() == null:
		return
	var ghost: Sprite2D = Sprite2D.new()
	ghost.texture = sprite.texture
	ghost.flip_h = sprite.flip_h
	ghost.global_position = sprite.global_position
	ghost.modulate = Color(_elem_color.r, _elem_color.g, _elem_color.b, 0.48)
	get_parent().add_child(ghost)
	var tw: Tween = ghost.create_tween()
	tw.tween_property(ghost, "modulate:a", 0.0, 0.22)
	tw.tween_callback(ghost.queue_free)


func _update_visual_effects(delta: float) -> void:
	_flicker_t += delta * 10.5
	beam_light.energy = 1.52 + sin(_flicker_t) * 0.08
	ambient_light.energy = 0.92 + cos(_flicker_t * 0.8) * 0.05

	if _slash_anim > 0.0:
		_slash_anim = maxf(0.0, _slash_anim - delta * 5.2)
		queue_redraw()

	if _shake_strength > 0.1:
		_shake_strength = lerpf(_shake_strength, 0.0, 14.0 * delta)
		cam.offset = Vector2(randf_range(-_shake_strength, _shake_strength), randf_range(-_shake_strength, _shake_strength))
	else:
		cam.offset = Vector2.ZERO


func _draw() -> void:
	if _slash_anim > 0.0:
		var span: float = 1.28
		var a0: float = _slash_base_angle - span
		var a1: float = _slash_base_angle + span
		var steps: int = 20
		var poly: PackedVector2Array = PackedVector2Array()
		for i in range(steps + 1):
			var a: float = lerpf(a0, a1, float(i) / float(steps))
			poly.append(Vector2(cos(a), sin(a)) * 96.0)
		for i in range(steps, -1, -1):
			var a: float = lerpf(a0, a1, float(i) / float(steps))
			poly.append(Vector2(cos(a), sin(a)) * 50.0)
		draw_colored_polygon(poly, Color(_elem_color.r, _elem_color.g, _elem_color.b, _slash_anim * 0.62))
		draw_arc(Vector2.ZERO, 94.0, a0, a1, 24, Color(1.0, 0.98, 0.90, _slash_anim * 0.95), 5.0)
		draw_arc(Vector2.ZERO, 76.0, a0 + 0.15, a1 - 0.15, 20, Color(_elem_color.r, _elem_color.g, _elem_color.b, _slash_anim * 0.85), 8.0)

	if _exhausted_timer > 0.0:
		var ratio: float = clampf(CaseManager.player_stamina / CaseManager.player_max_stamina, 0.0, 1.0)
		draw_rect(Rect2(-24, 24, 48, 5), Color(0.08, 0.06, 0.10, 0.9))
		draw_rect(Rect2(-24, 24, 48.0 * ratio, 5), Color("#ff884d"))


func add_camera_shake(amount: float) -> void:
	_shake_strength = maxf(_shake_strength, amount)


func take_damage(amount: int, impulse: Vector2) -> void:
	if _invuln_timer > 0.0 or CaseManager.ui_locked or CaseManager.player_hp <= 0:
		return
	CaseManager.player_hp = maxi(0, CaseManager.player_hp - amount)
	_invuln_timer = 0.55
	velocity += impulse
	add_camera_shake(7.5)
	AudioManager.play_sfx("hit", -1.5)
	_spawn_popup("-%d" % amount, Color("#ff4c70"))
	health_changed.emit(CaseManager.player_hp, CaseManager.player_max_hp)
	CaseManager.state_changed.emit()

	sprite.modulate = Color("#ff4769")
	var tw: Tween = create_tween()
	tw.tween_property(sprite, "modulate", Color.WHITE, 0.24)
	if CaseManager.player_hp <= 0:
		player_died.emit()
