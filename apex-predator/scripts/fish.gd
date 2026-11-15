extends CharacterBody2D

@export var swim_speed = 80.0
@export var territory_radius = 250.0
@export var chase_speed = 300.0
@export var required_level = 3
@export var attack_damage = 10.0
@export var attack_cooldown = 0.3
@export var attack_range = 80.0
@export var xp_reward = 30
@export var health_reward = 10

enum State {
	PASSIVE,
	WARNING,
	AGGRESSIVE
}
var shark: Node2D = null
var state = State.PASSIVE
var time_in_domain = 0.0
var shark_in_domain = false

var home_position: Vector2
var target_position: Vector2
var is_dead = false


var attack_timer = 0.0

func _ready() -> void:
	home_position = global_position
	pick_new_target()

func _physics_process(delta: float) -> void:
	# Update attack cooldown
	attack_timer = maxf(0.0, attack_timer - delta)

	# Update aggression
	if shark_in_domain:
		time_in_domain += delta

		if time_in_domain >= 2.25:
			state = State.AGGRESSIVE
		elif time_in_domain >= 1.0:
			state = State.WARNING
		else:
			state = State.PASSIVE

	# Movement
	var direction: Vector2 = Vector2.ZERO

	if state == State.AGGRESSIVE and shark != null:
		direction = global_position.direction_to(shark.global_position)
		var distance = global_position.distance_to(shark.global_position)

		# Chase until within attack range
		if distance > attack_range:
			velocity = direction * chase_speed
		else:
			# Stop moving and attack
			velocity = Vector2.ZERO

			if attack_timer <= 0.0:
				attack()

	else:
		direction = global_position.direction_to(target_position)
		velocity = direction * swim_speed

	move_and_slide()
	
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
	
		if collision.get_collider() == shark:
			velocity = Vector2.ZERO
	
			if state == State.AGGRESSIVE and attack_timer <= 0.0:
				attack()

	# Sprite direction
	if direction.x != 0:
		$AnimatedSprite2D.flip_h = direction.x < 0

	# Random swimming
	if state == State.PASSIVE:
		if global_position.distance_to(target_position) < 10:
			pick_new_target()

	# Warning indicator
	match state:
		State.PASSIVE:
			$WarningLabel.hide()

		State.WARNING:
			$WarningLabel.text = "!"
			$WarningLabel.show()

		State.AGGRESSIVE:
			$WarningLabel.text = "!!"
			$WarningLabel.show()


func pick_new_target() -> void:
	var direction = [-1.0, 1.0].pick_random()

	target_position = Vector2(
		clamp(
			global_position.x + direction * randf_range(150.0, 300.0),
			home_position.x - territory_radius,
			home_position.x + territory_radius
		),
		clamp(
			global_position.y + randf_range(-40.0, 40.0),
			home_position.y - 60.0,
			home_position.y + 60.0
		)
	)


func _on_domain_body_entered(body: Node2D) -> void:
	if body.is_in_group("shark"):
		shark = body
		shark_in_domain = true


func _on_domain_body_exited(body: Node2D) -> void:
	if body == shark:
		shark_in_domain = false
		shark = null
		time_in_domain = 0.0
		state = State.PASSIVE
		$WarningLabel.hide()
		
func attack() -> void:
	attack_timer = attack_cooldown
	$AnimatedSprite2D.play("attack")

	if not $AttackSound.playing:
		$AttackSound.play()

	shark.take_damage(attack_damage)
	


func _on_animated_sprite_2d_animation_finished() -> void:
	if $AnimatedSprite2D.animation == "attack":
		$AnimatedSprite2D.play("default")

	elif $AnimatedSprite2D.animation == "death":
		queue_free()

func die() -> void:
	if is_dead:
		return

	is_dead = true
	velocity = Vector2.ZERO
	$WarningLabel.hide()
	$AnimatedSprite2D.play("death")
	set_physics_process(false)


func _on_hit_box_area_entered(area: Area2D) -> void:
	print("FISH HITBOX DETECTED:", area.name)
