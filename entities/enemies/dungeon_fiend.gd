extends CharacterBody2D

# Universal Enemy Controller:
# Supports melee & ranged enemy archetypes, wall line-of-sight checks,
# Ice slow, Lightning stun, knockback, and optional boss health bar signals.
signal boss_damaged(boss_name: String, cur_hp: int, max_hp: int)
signal boss_defeated(enemy_kind: String, death_pos: Vector2)

const ProjectileScript = preload("res://entities/combat/projectile.gd")
const FloatingTextScript = preload("res://entities/combat/floating_text.gd")

@export var enemy_kind: String = "dummy_fiend"
@export var max_hp: int = 90
@export var move_speed: float = 135.0
@export var display_name: String = "Манекен Каземата"
@export var is_boss: bool = false
@export var is_ranged: bool = false

@onready var sprite: Sprite2D = $Sprite2D
@onready var eye_glow: PointLight2D = $EyeGlow

var hp: int = 90
var _chill_timer: float = 0.0
var _stun_timer: float = 0.0
var _knockback: Vector2 = Vector2.ZERO
var _attack_cd: float = 1.0
var _wobble_t: float = 0.0


func _ready() -> void:
	add_to_group("enemies")
	if ResourceLoader.exists("res://assets/sprites/enemy_dummy.png"):
		sprite.texture = load("res://assets/sprites/enemy_dummy.png")
	if ResourceLoader.exists("res://assets/sprites/light_radial.png"):
		eye_glow.texture = load("res://assets/sprites/light_radial.png")
	eye_glow.color = Color("#ff4c68")
	hp = max_hp
	_wobble_t = randf() * TAU


func _has_los_to(target: Node2D) -> bool:
	var q: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(global_position, target.global_position, 1)
	var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(q)
	return hit.is_empty() or hit.get("collider") == target


func _physics_process(delta: float) -> void:
	if CaseManager.ui_locked:
		velocity = Vector2.ZERO
		return

	if _chill_timer > 0.0:
		_chill_timer -= delta
	if _stun_timer > 0.0:
		_stun_timer -= delta
		velocity = _knockback
		_knockback = _knockback.move_toward(Vector2.ZERO, 900.0 * delta)
		move_and_slide()
		return

	if _attack_cd > 0.0:
		_attack_cd -= delta

	var p: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	var chase_vel: Vector2 = Vector2.ZERO

	if p and is_instance_valid(p) and CaseManager.player_hp > 0:
		var diff: Vector2 = p.global_position - global_position
		var dist: float = diff.length()
		var has_los: bool = dist < 520.0 and _has_los_to(p)

		if has_los:
			var dir: Vector2 = diff.normalized()
			sprite.flip_h = dir.x < 0.0
			var cur_spd: float = move_speed * (0.48 if _chill_timer > 0.0 else 1.0)

			if is_ranged:
				if dist > 240.0:
					chase_vel = dir * cur_spd
				elif dist < 140.0:
					chase_vel = -dir * (cur_spd * 0.7)
				if _attack_cd <= 0.0 and dist < 420.0:
					_attack_cd = 1.85
					_shoot_bolt(dir)
			else:
				chase_vel = dir * cur_spd
				if dist <= 46.0 and _attack_cd <= 0.0 and p.has_method("take_damage"):
					_attack_cd = 1.05
					p.take_damage(14, dir * 240.0)

	_knockback = _knockback.move_toward(Vector2.ZERO, 950.0 * delta)
	velocity = chase_vel + _knockback
	move_and_slide()

	if velocity.length() > 12.0:
		_wobble_t += delta * 12.0
		sprite.position.y = -10.0 - absf(sin(_wobble_t)) * 3.0
	else:
		sprite.position.y = lerpf(sprite.position.y, -10.0, 10.0 * delta)


func _shoot_bolt(dir: Vector2) -> void:
	var b: Area2D = ProjectileScript.new()
	b.global_position = global_position + dir * 22.0
	b.setup(dir, 390.0, 14, false, Color("#ff684c"), "fire")
	get_tree().current_scene.add_child(b)
	AudioManager.play_sfx("firebolt", -5.0)


func take_damage(amount: int, impulse: Vector2, elem_id: String = "physical") -> void:
	if hp <= 0:
		return
	hp = maxi(0, hp - amount)
	_knockback = impulse
	AudioManager.play_sfx("hit", -2.5)

	if elem_id == "ice":
		_chill_timer = 2.5
		sprite.modulate = Color("#7ce8ff")
	elif elem_id == "lightning":
		_stun_timer = 0.35
		sprite.modulate = Color("#fff068")
	else:
		sprite.modulate = Color("#ff5277")

	var tw: Tween = create_tween()
	tw.tween_property(sprite, "modulate", Color("#9ee8ff") if _chill_timer > 0.0 else Color.WHITE, 0.22)

	var ft: Node2D = FloatingTextScript.new()
	get_tree().current_scene.add_child(ft)
	ft.setup(global_position, "-%d" % amount, Color("#ffd668"), 16)

	if is_boss:
		boss_damaged.emit(display_name, hp, max_hp)

	if hp <= 0:
		_die()


func _die() -> void:
	CaseManager.gold += 15
	CaseManager.state_changed.emit()
	if is_boss:
		boss_defeated.emit(enemy_kind, global_position)
	queue_free()
