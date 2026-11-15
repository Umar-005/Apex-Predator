extends Area2D
@export var required_level: int = 1
@export var drift_speed = 25.0
@export var bob_speed = 2.0
@export var bob_amount = 8.0

@export var health_reward = 15.0
@export var xp_reward = 10
@export var score_reward = 10

const MIN_Y = -190.0
const MAX_Y = 830.0
const MIN_X = -5000
const MAX_X = 5000.0

var time = 0.0
var start_y = 0.0

func _ready() -> void:
	start_y = position.y
	drift_speed *= [-1, 1].pick_random()
	time = randf_range(0.0, TAU)

func _process(delta: float) -> void:
	time += delta

	# Horizontal drifting
	position.x += drift_speed * delta

	# Reverse direction at map boundaries
	if position.x <= MIN_X:
		position.x = MIN_X
		drift_speed = abs(drift_speed)

	elif position.x >= MAX_X:
		position.x = MAX_X
		drift_speed = -abs(drift_speed)

	# Floating animation
	position.y = start_y + sin(time * bob_speed) * bob_amount

	# Keep trash inside vertical boundaries
	position.y = clamp(position.y, MIN_Y, MAX_Y)


func _on_animated_sprite_2d_frame_changed() -> void:
	var frame = $AnimatedSprite2D.frame

	if frame == 1:
		$DoorSound.play()
