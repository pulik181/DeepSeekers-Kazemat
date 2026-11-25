extends Area2D

# Elemental Projectile Bolt (Mode 2 Shooting Magic for Fire/Ice/Lightning/Shadow + Bandit/Boss shots).
# Stops cleanly on any StaticBody2D wall (no shooting through walls!).

var direction: Vector2 = Vector2.RIGHT
var speed: float = 720.0
var damage: int = 38
var from_player: bool = true
var orb_color: Color = Color("#ff8438")
var element_id: String = "fire"
var life_left: float = 1.5


func setup(dir: Vector2, spd: float, dmg: int, is_player_shot: bool, col: Color, elem: String = "fire") -> void:
	direction = dir.normalized()
	speed = spd
	damage = dmg
	from_player = is_player_shot
	orb_color = col
	element_id = elem


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 | 2 | 4 | 8
	var col_shape: CollisionShape2D = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = 8.0
	col_shape.shape = circle
	add_child(col_shape)

	if ResourceLoader.exists("res://assets/sprites/light_radial.png"):
		var light: PointLight2D = PointLight2D.new()
		light.texture = load("res://assets/sprites/light_radial.png")
		light.color = orb_color
		light.energy = 1.25
		light.texture_scale = 0.85
		add_child(light)

	body_entered.connect(_on_body_entered)
	queue_redraw()


func _physics_process(delta: float) -> void:
	var next_pos: Vector2 = global_position + direction * speed * delta
	# Sweep ray against walls (mask 1) so high-speed bolts never tunnel through walls!
	var q: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(global_position, next_pos, 1)
	var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		var col_obj: Variant = hit.get("collider")
		if from_player and col_obj != null and col_obj.is_in_group("breakable_loot") and col_obj.has_method("smash"):
			col_obj.smash()
		_spawn_impact(hit["position"])
		queue_free()
		return

	global_position = next_pos
	life_left -= delta
	if life_left <= 0.0:
		queue_free()


func _draw() -> void:
	draw_circle(Vector2.ZERO, 12.0, Color(orb_color.r, orb_color.g, orb_color.b, 0.34))
	draw_line(-direction * 20.0, Vector2.ZERO, Color(orb_color.r, orb_color.g, orb_color.b, 0.72), 6.0)
	draw_circle(Vector2.ZERO, 6.5, orb_color)
	draw_circle(Vector2.ZERO, 3.2, Color.WHITE)


func _spawn_impact(pos: Vector2) -> void:
	if get_parent() == null:
		return
	var p: CPUParticles2D = CPUParticles2D.new()
	p.global_position = pos
	p.emitting = true
	p.one_shot = true
	p.explosiveness = 0.92
	p.amount = 12
	p.lifetime = 0.28
	p.spread = 180.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 50.0
	p.initial_velocity_max = 150.0
	p.scale_amount_min = 2.5
	p.scale_amount_max = 5.0
	p.color = orb_color
	get_parent().add_child(p)
	get_tree().create_timer(0.35).timeout.connect(p.queue_free)


func _on_body_entered(body: Node) -> void:
	if from_player and body.is_in_group("player"):
		return
	if not from_player and body.is_in_group("enemies"):
		return

	if from_player and body.is_in_group("enemies") and body.has_method("take_damage"):
		body.take_damage(damage, direction * 250.0, element_id)
		if element_id == "shadow":
			CaseManager.player_hp = mini(CaseManager.player_max_hp, CaseManager.player_hp + 6)
			CaseManager.state_changed.emit()
		_spawn_impact(global_position)
		queue_free()
	elif from_player and body.is_in_group("breakable_loot") and body.has_method("smash"):
		body.smash()
		_spawn_impact(global_position)
		queue_free()
	elif not from_player and body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(damage, direction * 220.0)
		_spawn_impact(global_position)
		queue_free()
	elif body is StaticBody2D:
		_spawn_impact(global_position)
		queue_free()
