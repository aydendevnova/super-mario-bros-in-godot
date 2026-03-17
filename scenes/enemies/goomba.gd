extends Enemy

@onready var animplayer: AnimationPlayer = $AnimationPlayer

func _ready():
	super()
	animplayer.play("walk")

func _freeze() -> void:
	super._freeze()
	if animplayer:
		animplayer.pause()

func stomp(player: Player):
	AudioSystem.play_sfx("stomp")
	die_procedure()
	die_score_popup()
	Game.up_score(100)
	animplayer.play("stomped")
	stomped = true
	animplayer.animation_finished.connect(
		func(anim_name):
			if (anim_name == "stomped"):
				queue_free()
			
	)
