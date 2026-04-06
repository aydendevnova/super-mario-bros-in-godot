extends Node

signal game_palette_updated
signal player_died
signal level_completed

signal game_state_changed(state)
signal score_updated(score: int)
signal coins_updated(coins: int)
signal time_updated(time: int)
signal pipe_blackout(active: bool)
signal star_power_ended
