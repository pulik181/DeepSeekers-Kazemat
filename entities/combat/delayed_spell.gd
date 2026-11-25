extends Node2D

# Delayed Elemental Seal Magic (Mode 1 AoE Magic for Fire/Ice/Lightning/Shadow + Boss Seals).
# Checks line-of-sight against Walls (mask 1) so explosions NEVER hit through walls!

var radius: float = 96.0
var delay_sec: float = 0.72
var damage: int = 74
var from_player: bool = true
var rune_color: Color = Color("#ff8438")
var element_id: String = "fire"

var _elapsed: float = 0.0
var _erupted: bool = false
var _light: PointLight2D


func setup(pos: Vector2, rad: float, delay: float, dmg: int, is_player: bool, col: Color, elem: String = "fire") -> void:
	global_position = pos
	radius = rad
	delay_sec = delay
	damage = dmg
	from_player = is_player
	rune_color = col
	element_id = elem


func _ready() -> void:
	if ResourceLoader.exists("res://assets/sprites/light_radial.png"):
		_light = PointLight2D.new()
		_light.texture = load("res://assets/sprites/light_radial.png")
		_light.color = rune_color
		_light.energy = 0.7
		_light.texture_scale = radius / 75.0
		add_child(_light)
	if from_player:
		AudioManager.play_sfx("magic_charge", -3.5)


func _has_clear_los(target: Node2D) -> bool:
	var q: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(global_position, target.global_position, 1)
	var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(q)
	return hit.is_empty() or hit.get("collider") == target


func _process(delta: float) -> void:
	_elapsed += delta
	if not _erupted:
		var prog: float = clampf(_elapsed / delay_sec, 0.0, 1.0)
		if _light:
			_light.energy = 0.7 + prog * 1.8
		if _elapsed >= delay_sec:
			_trigger_eruption()
	else:
		var post: float = _elapsed - delay_sec
		if _light:
			_light.energy = maxf(0.0, 3.2 * (1.0 - post / 0.38))
		if post >= 0.38:
			queue_free()
			return
	queue_redraw()


func _trigger_eruption() -> void:
	_erupted = true
	AudioManager.play_sfx("magic_boom", -1.5)

	var burst: CPUParticles2D = CPUParticles2D.new()
	burst.emitting = true
	burst.one_shot = true
	burst.explosiveness = 0.92
	burst.amount = 30
	burst.lifetime = 0.48
	burst.direction = Vector2(0, -1)
	burst.spread = 65.0
	burst.gravity = Vector2(0, 120)
	burst.initial_velocity_min = 95.0
	burst.initial_velocity_max = 270.0
	burst.scale_amount_min = 3.5
	burst.scale_amount_max = 7.0
	burst.color = rune_color.lightened(0.25)
	add_child(burst)

	var p_node: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if p_node and p_node.has_method("add_camera_shake"):
		p_node.add_camera_shake(6.5 if from_player else 8.0)

	if from_player:
		var hit_count: int = 0
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if is_instance_valid(enemy) and enemy.global_position.distance_to(global_position) <= radius + 18.0:
				if _has_clear_los(enemy) and enemy.has_method("take_damage"):
					var push: Vector2 = (enemy.global_position - global_position).normalized() * 320.0
					enemy.take_damage(damage, push, element_id)
					hit_count += 1
		if element_id == "shadow" and hit_count > 0:
			CaseManager.player_hp = mini(CaseManager.player_max_hp, CaseManager.player_hp + hit_count * 7)
			CaseManager.state_changed.emit()

		for barrel in get_tree().get_nodes_in_group("breakable_loot"):
			if is_instance_valid(barrel) and barrel.global_position.distance_to(global_position) <= radius + 14.0:
				if _has_clear_los(barrel) and barrel.has_method("smash"):
					barrel.smash()
	else:
		if p_node and is_instance_valid(p_node) and p_node.global_position.distance_to(global_position) <= radius + 10.0:
			if _has_clear_los(p_node) and p_node.has_method("take_damage"):
				var push_p: Vector2 = (p_node.global_position - global_position).normalized() * 260.0
				p_node.take_damage(damage, push_p)


func _draw() -> void:
	if not _erupted:
		var prog: float = clampf(_elapsed / delay_sec, 0.0, 1.0)
		draw_circle(Vector2.ZERO, radius, Color(rune_color.r, rune_color.g, rune_color.b, 0.11 + prog * 0.22))
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, rune_color, 2.5)
		draw_arc(Vector2.ZERO, radius * prog, 0.0, TAU, 32, rune_color.lightened(0.35), 2.0)

		var rot: float = _elapsed * 3.8
		var pts: PackedVector2Array = PackedVector2Array()
		for i in range(7):
			var a: float = rot + float(i) * TAU / 6.0
			pts.append(Vector2(cos(a), sin(a)) * (radius * 0.72))
		for i in range(6):
			draw_line(pts[i], pts[(i + 2) % 6], Color(rune_color.r, rune_color.g, rune_color.b, 0.78), 2.0)
	else:
		var post: float = (_elapsed - delay_sec) / 0.38
		var alpha: float = maxf(0.0, 1.0 - post)
		draw_circle(Vector2.ZERO, radius * (1.0 + post * 0.18), Color(rune_color.r, rune_color.g, rune_color.b, 0.55 * alpha))
		draw_rect(Rect2(-radius * 0.42, -230.0, radius * 0.84, 235.0), Color(rune_color.r, rune_color.g, rune_color.b, 0.52 * alpha))
		draw_rect(Rect2(-radius * 0.20, -230.0, radius * 0.40, 235.0), Color(1.0, 0.98, 0.88, 0.88 * alpha))
