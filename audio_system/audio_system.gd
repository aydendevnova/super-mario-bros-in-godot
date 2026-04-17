extends Node

## NES-style 4-channel audio system.
## Channels: 0=Pulse1, 1=Pulse2, 2=Triangle, 3=Noise
## Music plays across multiple channels simultaneously.
## SFX interrupts a single channel and restores music when done.

const CH_COUNT := 4

@onready var audio_sys_node = $"/root/Main/AudioSystem"
@onready var _ch := [audio_sys_node.get_node("Pulse1"), audio_sys_node.get_node("Pulse2"), audio_sys_node.get_node("Triangle"), audio_sys_node.get_node("Noise")]

# --- Music state ---
var _track := ""
var _voices: Array[int] = []
var _music_stream: Array = [null, null, null, null]

# --- Per-channel SFX state ---
var _sfx_on: Array[bool] = [false, false, false, false]
var _sfx_left: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _sfx_age: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _sfx_name: Array[String] = ["", "", "", ""]
const MIN_SFX_PLAY := 0.064

# --- Fade-in on music restore ---
const FADE_IN_DB := -20.0
const FADE_IN_DURATION := 0.025
var _fade_tween: Array = [null, null, null, null]

# --- Demo channel mute (does not affect play state, only audio output) ---
var _channel_muted: Array[bool] = [false, false, false, false]


func play_music(track_name: String) -> void:
	if track_name == _track:
		return
	stop_music()

	var t: Dictionary = AudioData.TRACKS.get(track_name, {})
	if t.is_empty():
		push_error("AudioSystem: unknown track '%s'" % track_name)
		return

	_track = track_name
	_voices.clear()
	for v in t.voices:
		_voices.append(v as int)

	# Preload all streams before starting any playback
	for v in _voices:
		if v >= CH_COUNT:
			continue
		var s := _load_stream(t.group, track_name, v)
		if s:
			_music_stream[v] = s
			_ch[v].stream = s

	# Start all channels in a tight loop — no I/O between plays
	for v in _voices:
		if v < CH_COUNT and _ch[v].stream:
			_ch[v].play()


func stop_music() -> void:
	_track = ""
	_voices.clear()
	for i in CH_COUNT:
		_sfx_on[i] = false
		_sfx_left[i] = 0.0
		if _fade_tween[i]:
			_fade_tween[i].kill()
			_fade_tween[i] = null
		_ch[i].stop()
		_ch[i].volume_db = 0.0
		_ch[i].stream = null
		_music_stream[i] = null


func play_sfx(sfx_name: String) -> void:
	var t: Dictionary = AudioData.TRACKS.get(sfx_name, {})
	if t.is_empty():
		push_error("AudioSystem: unknown sfx '%s'" % sfx_name)
		return
	for v in t.voices:
		var ch: int = v as int
		if ch >= CH_COUNT:
			continue
		var s := _load_stream(t.group, sfx_name, ch)
		if not s:
			continue
		if _sfx_on[ch] and _sfx_name[ch] == sfx_name and _sfx_age[ch] < MIN_SFX_PLAY:
			_sfx_left[ch] = maxf(_sfx_left[ch], t.duration)
			continue
		if _fade_tween[ch]:
			_fade_tween[ch].kill()
			_fade_tween[ch] = null
		_sfx_on[ch] = true
		_sfx_left[ch] = t.duration
		_sfx_age[ch] = 0.0
		_sfx_name[ch] = sfx_name
		_ch[ch].volume_db = -80.0 if _channel_muted[ch] else 0.0
		_ch[ch].stream = s
		_ch[ch].play()


func _process(delta: float) -> void:
	for i in CH_COUNT:
		if _sfx_on[i]:
			_sfx_age[i] += delta
			_sfx_left[i] -= delta
			if _sfx_left[i] <= 0.0:
				_restore_channel(i)
		if _channel_muted[i]:
			_ch[i].volume_db = -80.0


func _restore_channel(ch: int) -> void:
	_sfx_on[ch] = false
	_sfx_left[ch] = 0.0
	_sfx_age[ch] = 0.0
	_sfx_name[ch] = ""

	if _music_stream[ch] == null:
		_ch[ch].stop()
		_ch[ch].stream = null
		return

	# If any other voice finished naturally (not looping), the track is over
	for v in _voices:
		if v == ch or v >= CH_COUNT or _sfx_on[v]:
			continue
		if not _ch[v].playing:
			_ch[ch].stop()
			_ch[ch].stream = null
			return

	var pos := _get_sync_position(ch)
	_ch[ch].stream = _music_stream[ch]
	_ch[ch].volume_db = FADE_IN_DB
	_ch[ch].play(pos)

	if _fade_tween[ch]:
		_fade_tween[ch].kill()
	_fade_tween[ch] = create_tween()
	_fade_tween[ch].tween_property(_ch[ch], "volume_db", 0.0, FADE_IN_DURATION)


func _get_sync_position(exclude_ch: int) -> float:
	for v in _voices:
		if v != exclude_ch and v < CH_COUNT and not _sfx_on[v] and _ch[v].playing:
			return _ch[v].get_playback_position()
	return 0.0


func get_debug_info() -> Dictionary:
	if not OS.is_debug_build():
		return {}
	var ch_info := []
	for i in CH_COUNT:
		var stream_name := ""
		if _ch[i].stream:
			stream_name = _ch[i].stream.resource_path.get_file().get_basename()
		ch_info.append({
			"playing": _ch[i].playing,
			"sfx": _sfx_on[i],
			"sfx_left": snappedf(_sfx_left[i], 0.01),
			"stream": stream_name,
			"vol_db": snappedf(_ch[i].volume_db, 0.1),
		})
	return {
		"track": _track if _track != "" else "(none)",
		"voices": _voices,
		"channels": ch_info,
	}


func set_channel_muted(ch: int, muted: bool) -> void:
	if ch < 0 or ch >= CH_COUNT:
		return
	_channel_muted[ch] = muted
	if muted:
		_ch[ch].volume_db = -80.0
	else:
		_ch[ch].volume_db = 0.0


func is_music_playing() -> bool:
	if _track == "":
		return false
	for v in _voices:
		if v < CH_COUNT and _ch[v].playing:
			return true
	return false


func is_channel_muted(ch: int) -> bool:
	return _channel_muted[ch] if ch >= 0 and ch < CH_COUNT else false


func _load_stream(group: String, track_name: String, ch: int) -> AudioStream:
	var path := "res://assets/%s/%s__%s.ogg" % [group, track_name, AudioData.CHANNEL_NAMES[ch]]
	var s = load(path)
	if s == null:
		push_warning("AudioSystem: missing '%s'" % path)
		return null
	var t: Dictionary = AudioData.TRACKS.get(track_name, {})
	if s is AudioStreamOggVorbis:
		s.loop = t.get("loop", false)
	return s as AudioStream
