extends CharacterBody2D

@onready var attack_hit_box: Area2D = $AttackHitBox
@onready var swim: AnimatedSprite2D = $swim


const EAT_DEFAULT = preload("res://assets/audio/eat.wav")
const EAT_GLASS = preload("res://assets/audio/glass.mp3")
const EAT_PLASTIC = preload("res://assets/audio/plasticbag.wav")
const EAT_BOTTLE = preload("res://assets/audio/waterbottle.wav")
const ERROR_SOUND = preload("res://assets/audio/error.wav")

signal level_changed
signal trash_eaten(points: int)
signal died

const SPEED = 300.0
const MIN_Y = -190.0
const MAX_Y = 830.0
const MIN_X = -5000
const MAX_X = 5000.0
const IDLE_SPEED = 60.0

var max_health = 100.0
var health = max_health
var is_dead = false

var level = 1
var xp = 0
var xp_required = 100



func _ready() -> void:
	swim.animation_finished.connect(_on_swim_animation_finished)

	# Keep mouth hitbox active permanently
	attack_hit_box.get_node("CollisionShape2D").disabled = false

func _physics_process(delta: float) -> void:
	
	if Input.is_action_just_pressed("ui_accept"):
		print("Overlapping areas:", attack_hit_box.get_overlapping_areas())

	# Health decay
	var health_decay = 6.0 + (level - 1) * 4.75
	health -= health_decay * delta
	health = clamp(health, 0.0, max_health)

	# Death
	if health <= 0 and not is_dead:
		$DeathSound.stream = preload("res://assets/audio/death.wav")
		$DeathSound.play()
		is_dead = true
		died.emit()
		set_physics_process(false)
		return

	# Movement input
	var direction = Input.get_vector(
		"move_left",
		"move_right",
		"move_up",
		"move_down"
	)

	# Movement speed
	var speed = SPEED

	if Input.is_action_pressed("sprint"):
		speed *= 1.5
		swim.speed_scale = 1.5
	else:
		swim.speed_scale = 1.0

	# Automatic forward swimming
	if direction == Vector2.ZERO:
		var facing = -1.0 if swim.flip_h else 1.0
		velocity = Vector2(facing * IDLE_SPEED, 0)
	else:
		velocity = direction * speed
	move_and_slide()
	# Flip shark
	if direction.x > 0:
		swim.flip_h = false
	elif direction.x < 0:
		swim.flip_h = true
	# Tilt shark
	var tilt = direction.y * 0.5
	if swim.flip_h:
		tilt *= -1
	swim.rotation = lerp_angle(
		swim.rotation,
		tilt,
		0.1
	)

	# Position mouth hitbox
	var facing = -1.0 if swim.flip_h else 1.0
	attack_hit_box.position = Vector2(
		25 * facing,
		0
	).rotated(swim.rotation)
	attack_hit_box.rotation = swim.rotation

	position.x = clamp(position.x, MIN_X, MAX_X)
	position.y = clamp(position.y, MIN_Y, MAX_Y)


# Automatically eat trash when mouth touches it
func _on_attack_hit_box_area_entered(area: Area2D) -> void:
	if is_dead:
		return
	if area.is_in_group("marine_life"):
		var fish = area.get_parent()
	
		if fish.is_dead:
			return
	
		if level >= fish.required_level:
			fish.die()
			gain_xp(fish.xp_reward)
			health = min(health + fish.health_reward, max_health)
		
			swim.play("attack")
		
			$EatSound.volume_db = 6
			$EatSound.play()
			swim.play("attack")
	
			$EatSound.stream = EAT_DEFAULT
			$EatSound.volume_db = 6
			$EatSound.play()
	
		else:
			show_level_warning(fish.required_level)
	
			$EatSound.stream = ERROR_SOUND
			$EatSound.volume_db = -10
			$EatSound.play()

		return

	if area.is_in_group("trash"):
		if level < area.required_level:
			show_level_warning(area.required_level)
			$EatSound.stream = ERROR_SOUND
			$EatSound.volume_db = -10
			$EatSound.play()
			return

		swim.play("attack")

		play_eat_sound(area)

		health = min(health + area.health_reward, max_health)
		gain_xp(area.xp_reward)
		trash_eaten.emit(area.score_reward)

		area.queue_free()


# Return to swimming after eating
func _on_swim_animation_finished() -> void:
	if swim.animation == "attack":
		swim.play("swim")

# XP system
func gain_xp(amount: int) -> void:
	xp += amount
	while xp >= xp_required:
		xp -= xp_required
		level_up()


# Levelling system
func level_up() -> void:
	level += 1
	xp_required = int(xp_required * 1.5)
	scale *= 1.15
	max_health += 20.0
	health = min(health + 15.0, max_health)
	level_changed.emit()
	
var warning_tween: Tween

func show_level_warning(required_level: int) -> void:
	if warning_tween and warning_tween.is_running():
		warning_tween.kill()

	var warning = $LevelWarning

	warning.position.y = -65
	warning.text = "LEVEL " + str(required_level) + " REQUIRED!"
	warning.modulate.a = 1.0
	warning.show()

	warning_tween = create_tween()
	warning_tween.tween_property(warning, "position:y", -85.0, 0.5)
	warning_tween.parallel().tween_property(warning, "modulate:a", 0.0, 0.5)
	warning_tween.tween_callback(warning.hide)
	
	
func play_eat_sound(trash: Area2D) -> void:
	var sound = EAT_DEFAULT
	match trash.scene_file_path.get_file():
		"screen.tscn":
			sound = EAT_GLASS
		"trash.tscn":
			sound = EAT_PLASTIC
		"bottle.tscn":
			sound = EAT_BOTTLE

	$EatSound.stream = sound
	$EatSound.play()

func _on_eat_sound_finished() -> void:
	$EatSound.volume_db = 0


func take_damage(amount: float) -> void:
	if is_dead:
		return
	health = maxf(0.0, health - amount)

	if health <= 0:
		$DeathSound.stream = preload("res://assets/audio/death.wav")
		$DeathSound.play()
		is_dead = true
		died.emit()
		set_physics_process(false)
