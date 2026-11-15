extends Node2D

@export var marine_life_scenes: Array[PackedScene]
@export var max_fish = 15
var spawn_weights: Array[int] = []
@onready var shark = get_parent().get_node("Shark")

func _ready() -> void:
	update_spawn_weights(shark.level)

	shark.level_changed.connect(_on_shark_level_changed)

	for i in range(max_fish):
		spawn_fish()

func spawn_fish() -> void:
	var spawn_position: Vector2

	for attempt in range(100):
		spawn_position = Vector2(
			randf_range(-4800, 4800),
			randf_range(-100, 730)
		)

		if spawn_position.distance_to(shark.global_position) < 500:
			continue

		var valid = true

		for creature in get_children():
			if spawn_position.distance_to(creature.global_position) < 350:
				valid = false
				break

		if not valid:
			continue

		var scene = pick_weighted_scene()
		var creature = scene.instantiate()

		add_child(creature)
		creature.global_position = spawn_position
		creature.tree_exited.connect(respawn_marine_life)
		return

func pick_weighted_scene() -> PackedScene:
	var total_weight = 0

	for weight in spawn_weights:
		total_weight += weight

	var roll = randi_range(1, total_weight)
	var cumulative_weight = 0

	for i in range(spawn_weights.size()):
		cumulative_weight += spawn_weights[i]

		if roll <= cumulative_weight:
			return marine_life_scenes[i]

	return marine_life_scenes[0]
	
func respawn_marine_life() -> void:
	if not is_inside_tree():
		return

	await get_tree().create_timer(5.0).timeout

	if not is_inside_tree():
		return

	spawn_fish()
	
	
func _on_shark_level_changed() -> void:
	update_spawn_weights(shark.level)
	
	
func update_spawn_weights(player_level: int) -> void:
	if player_level <= 2:
		spawn_weights = [50, 25, 15, 5, 3, 2]

	elif player_level <= 4:
		spawn_weights = [35, 30, 20, 10, 3, 2]

	elif player_level <= 6:
		spawn_weights = [20, 20, 25, 20, 10, 5]

	else:
		spawn_weights = [10, 15, 20, 20, 20, 15]
