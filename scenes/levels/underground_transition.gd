extends Node2D

func _ready() -> void:
	var pipe := find_child("PipeEntrance", true, false) as PipeEntrance
	assert(pipe, "Level will not load")
	if pipe:
		pipe.dest_scene_path = Game.get_level_scene_path()
