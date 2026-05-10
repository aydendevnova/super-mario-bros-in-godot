extends CanvasLayer

@onready var main_menu: CenterContainer = $MainMenu
@onready var main_menu_buttons: MarginContainer = $MainMenu/MarginContainer/VBoxContainer/MainMenuButtons
@onready var options_menu_buttons: MarginContainer = $MainMenu/MarginContainer/VBoxContainer/OptionsMenuButtons

@onready var hud: CenterContainer = $HUD
@onready var transition: Control = $Transition
@onready var transition_content: CenterContainer = $Transition/Transition

@onready var hud_score: Control = $HUD/MarginContainer/UI/BottomLine/Score
@onready var hud_coin: Control = $HUD/MarginContainer/UI/BottomLine/CoinDiv/Coin
@onready var hud_world: Control = $HUD/MarginContainer/UI/BottomLine/Control/World
@onready var hud_time: Control = $HUD/MarginContainer/UI/BottomLine/Time

@onready var trans_world: Control = $Transition/Transition/MarginContainer/VBoxContainer/HBoxContainer/Label
@onready var trans_lives: Control = $Transition/Transition/MarginContainer/VBoxContainer/VBoxContainer/MarginContainer/HBoxContainer2/MarginContainer/HBoxContainer/LivesLabel
@onready var load_timer: Timer = $Transition/Transition/LoadTimer

@onready var coin_bottom_sprite: TextureRect = $HUD/MarginContainer/UI/BottomLine/CoinDiv/CoinBottomSprite

@onready var menu_top_score: Control = $MainMenu/MarginContainer/VBoxContainer/MainMenuButtons/VBoxContainer/MarginContainer/HBoxContainer/Label


func _ready() -> void:
	SignalBus.game_state_changed.connect(_on_state_changed)
	SignalBus.pipe_blackout.connect(_on_pipe_blackout)
	SignalBus.score_updated.connect(func(_v): _refresh_score())
	SignalBus.coins_updated.connect(func(v): hud_coin.text = "*%02d" % v)
	SignalBus.time_updated.connect(func(v):
		if Game.state == Game.GameState.PLAYING or Game.state == Game.GameState.DEAD:
			hud_time.text = str(v).lpad(3, "0")
	)

	load_timer.wait_time = 3.0
	load_timer.one_shot = true
	load_timer.timeout.connect(_on_load_timer_timeout)

	main_menu_buttons.game_start_requested.connect(func(): Game.start_game())
	main_menu_buttons.options_requested.connect(_open_options)
	options_menu_buttons.back_requested.connect(_close_options)

	_show_menu()

func _open_options() -> void:
	main_menu_buttons.deactivate()
	options_menu_buttons.activate()

func _close_options() -> void:
	options_menu_buttons.deactivate()
	main_menu_buttons.activate(2)

func _show_menu() -> void:
	show()
	main_menu.visible = true
	hud.visible = true
	transition.visible = false
	coin_bottom_sprite.visible = true
	options_menu_buttons.deactivate()
	main_menu_buttons.activate()
	_refresh_hud()
	hud_time.text = ""

func _show_transition() -> void:
	main_menu.visible = false
	main_menu_buttons.deactivate()
	options_menu_buttons.deactivate()
	hud.visible = true
	transition_content.visible = true
	transition.visible = true
	coin_bottom_sprite.visible = false
	trans_world.text = "WORLD %s" % Game.get_level_key()
	trans_lives.text = str(Game.lives)
	_refresh_hud()
	hud_time.text = ""
	load_timer.start()

func _show_gameplay() -> void:
	main_menu.visible = false
	main_menu_buttons.deactivate()
	options_menu_buttons.deactivate()
	hud.visible = true
	transition.visible = false
	coin_bottom_sprite.visible = true
	_refresh_hud()

func _on_state_changed(new_state) -> void:
	match new_state:
		Game.GameState.MENU:
			_show_menu()
		Game.GameState.TRANSITION:
			_show_transition()
		Game.GameState.PLAYING:
			_show_gameplay()

func _on_load_timer_timeout() -> void:
	Game.begin_level()

func _refresh_score() -> void:
	hud_score.text = "%06d" % Game.score
	menu_top_score.text = "TOP- %06d" % Game.top_score

func _refresh_hud() -> void:
	hud_score.text = "%06d" % Game.score
	hud_coin.text = "*%02d" % Game.coins
	hud_world.text = Game.get_level_key()
	hud_time.text = str(Game.time).lpad(3, "0")
	menu_top_score.text = "TOP- %06d" % Game.top_score

func _on_pipe_blackout(active: bool) -> void:
	if active:
		transition_content.visible = false
		transition.visible = true
	else:
		transition.visible = false
