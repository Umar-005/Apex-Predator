extends Node2D

@onready var shark = $Shark
@onready var score_label: Label = $CanvasLayer/ScoreLabel
@onready var level: Label = $CanvasLayer/HUD/XPBar/Level
@onready var xp_bar: ProgressBar = $CanvasLayer/HUD/XPBar
@onready var health_bar: ProgressBar = $CanvasLayer/HUD/HealthBar
@onready var hud: Panel = $CanvasLayer/HUD
@onready var trash_spawner: Timer = $TrashSpawner
@onready var score_request: HTTPRequest = $ScoreRequest

const API_URL = "http://localhost:3000/scores"

const TRASH_SCENES = [
	preload("res://scenes/trash/bottle.tscn"),
	preload("res://scenes/trash/box.tscn"),
	preload("res://scenes/trash/trash.tscn"),
	preload("res://scenes/trash/screen.tscn"),
	preload("res://scenes/trash/computer.tscn"),
	preload("res://scenes/trash/small_bin.tscn"),
	preload("res://scenes/trash/dumpster.tscn")
]

const TRASH_WEIGHTS = {
	1: [30, 25, 20, 10, 7, 5, 3],
	2: [25, 20, 20, 15, 10, 7, 3],
	3: [20, 15, 15, 20, 15, 10, 5],
	4: [15, 10, 10, 20, 20, 15, 10],
	5: [10, 10, 10, 15, 20, 20, 15]
}

var score = 0
var score_submitted = false

const MAX_TRASH = 280
const STARTING_TRASH = 160


func _ready() -> void:
	$BackgroundAudio.play()

	$Shark.died.connect(_on_shark_died)
	$Shark.trash_eaten.connect(_on_shark_trash_eaten)
	$Shark.level_changed.connect(update_spawn_rate)

	score_request.request_completed.connect(_on_score_submitted)

	update_spawn_rate()

	score_label.text = "Score: " + str(score)

	for i in range(STARTING_TRASH):
		spawn_trash()


func _process(delta: float) -> void:
	health_bar.max_value = shark.max_health
	health_bar.value = shark.health

	var fill = health_bar.get_theme_stylebox("fill") as StyleBoxFlat

	if shark.health / shark.max_health > 0.5:
		fill.bg_color = Color.GREEN
	elif shark.health / shark.max_health > 0.25:
		fill.bg_color = Color.YELLOW
	else:
		fill.bg_color = Color.RED

	xp_bar.max_value = shark.xp_required
	xp_bar.value = shark.xp

	level.text = "Level " + str(shark.level)

	var screen_y = shark.get_global_transform_with_canvas().origin.y
	var target_alpha = 0.25 if screen_y > 270 else 1.0

	hud.modulate.a = move_toward(
		hud.modulate.a,
		target_alpha,
		3.0 * delta
	)


func _on_shark_died() -> void:
	submit_score()

	$CanvasLayer/GameOver.show()

	$CanvasLayer/GameOver/CenterContainer/VBoxContainer/FinalScore.text = \
		"FINAL SCORE: " + str(score)

	$CanvasLayer/HUD.hide()
	health_bar.hide()
	xp_bar.hide()
	score_label.hide()


func submit_score() -> void:
	if score_submitted:
		return

	var data = {
		"username": Global.username,
		"score": score,
		"level": shark.level
	}

	var headers = ["Content-Type: application/json"]

	var error = score_request.request(
		API_URL,
		headers,
		HTTPClient.METHOD_POST,
		JSON.stringify(data)
	)

	if error == OK:
		score_submitted = true
	else:
		print("Failed to start score submission: ", error)


func _on_score_submitted(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	_body: PackedByteArray
) -> void:
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 201:
		print("Score submitted successfully!")
	else:
		print("Score submission failed: ", response_code)


func _on_button_pressed() -> void:
	get_tree().reload_current_scene()


func _on_shark_trash_eaten(points: int) -> void:
	score += points
	score_label.text = "Score: " + str(score)


func _on_main_menu_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func spawn_trash() -> void:
	var trash_scene = pick_trash_scene()
	var trash = trash_scene.instantiate()

	trash.position = Vector2(
		randf_range(-4900, 4900),
		randf_range(-150, 790)
	)

	add_child(trash)


func _on_trash_spawner_timeout() -> void:
	if get_tree().get_nodes_in_group("trash").size() < MAX_TRASH:
		spawn_trash()


func pick_trash_scene() -> PackedScene:
	var current_level = mini($Shark.level, 5)
	var weights = TRASH_WEIGHTS[current_level]

	var roll = randi_range(1, 100)
	var total = 0

	for i in range(TRASH_SCENES.size()):
		total += weights[i]

		if roll <= total:
			return TRASH_SCENES[i]

	return TRASH_SCENES[0]


func update_spawn_rate() -> void:
	var new_wait_time = max(
		0.5,
		2.0 - ($Shark.level - 1) * 0.3
	)

	trash_spawner.wait_time = new_wait_time
