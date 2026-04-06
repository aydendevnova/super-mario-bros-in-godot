extends PanelContainer

## Real-time NES 4-channel audio visualizer.
## Drives scene UI nodes from AudioSystem debug info each frame.
## Channel checkboxes toggle mute on the AudioSystem for demo purposes.

const CH_COLORS: Array[Color] = [
	Color("#5C94FC"),
	Color("#58D854"),
	Color("#F07858"),
	Color("#A8A8A8"),
]
const SFX_COLOR := Color("#F8D878")
const DIM := Color(0.22, 0.22, 0.22)
const BOX_BG := Color(0.05, 0.05, 0.07)
const BOX_BG_ACTIVE := Color(0.08, 0.08, 0.12)

var _time := 0.0
var _checkboxes: Array[CheckBox] = []
var _status_styles: Array[StyleBoxFlat] = []
var _ch_labels: Array[Label] = []
var _type_labels: Array[Label] = []
var _stream_labels: Array[Label] = []
var _timer_bars: Array[ColorRect] = []
var _status_boxes: Array[PanelContainer] = []

@onready var _track_label: Label = %TrackLabel


func _ready() -> void:
	var channels := $Margin/Layout/Channels
	for i in 4:
		var row: HBoxContainer = channels.get_node("Channel%d" % i)

		var toggle: CheckBox = row.get_node("MarginContainer/ChannelToggle")
		toggle.toggled.connect(_on_channel_toggled.bind(i))
		_checkboxes.append(toggle)

		_ch_labels.append(row.get_node("ChannelLabel"))

		var col: VBoxContainer = row.get_node("StatusColumn")
		var box: PanelContainer = col.get_node("StatusBox")
		_status_boxes.append(box)
		var box_style: StyleBoxFlat = box.get_theme_stylebox("panel").duplicate()
		box.add_theme_stylebox_override("panel", box_style)
		_status_styles.append(box_style)

		var stack: VBoxContainer = box.get_node("StatusStack")
		_type_labels.append(stack.get_node("TypeLabel"))
		_stream_labels.append(stack.get_node("StreamLabel"))
		_timer_bars.append(col.get_node("TimerBar"))

	for tb in _timer_bars:
		tb.modulate.a = 0
		tb.show()
	hide()


func _on_channel_toggled(enabled: bool, ch: int) -> void:
	AudioSystem.set_channel_muted(ch, not enabled)


func _process(delta: float) -> void:
	_time += delta
	var info: Dictionary = AudioSystem.get_debug_info()
	_track_label.text = info.track
	for i in 4:
		_update_channel(info, i)


func _update_channel(info: Dictionary, i: int) -> void:
	var ch: Dictionary = info.channels[i]
	var playing: bool = ch.playing
	var sfx: bool = ch.sfx 
	var color: Color = CH_COLORS[i]

	_ch_labels[i].add_theme_color_override("font_color", color if playing else DIM)
	_status_styles[i].bg_color = BOX_BG_ACTIVE if playing else BOX_BG

	if sfx:
		_type_labels[i].text = "SFX"
		_type_labels[i].add_theme_color_override("font_color", SFX_COLOR)
		
		_set_stream_name(i, ch.stream)
		_stream_labels[i].visible = true
		if ch.sfx_left > 0:
			var dur := _find_sfx_duration(ch.stream, i)
			var ratio := clampf(ch.sfx_left / dur, 0.0, 1.0)
			_timer_bars[i].modulate.a = 1
			_timer_bars[i].custom_minimum_size.x = _status_boxes[i].size.x * ratio
		else:
			_timer_bars[i].modulate.a = 0
	elif playing:
		_type_labels[i].text = "MUSIC"
		_type_labels[i].add_theme_color_override("font_color", color)
		_set_stream_name(i, ch.stream)
		_stream_labels[i].visible = true
		_timer_bars[i].modulate.a = 0
	else:
		_type_labels[i].text = "---"
		_type_labels[i].add_theme_color_override("font_color", DIM)
		_stream_labels[i].visible = false
		_timer_bars[i].modulate.a = 0


func _set_stream_name(i: int, stream: String) -> void:
	var sname := stream
	if sname.length() > 22:
		sname = sname.left(20) + ".."
	_stream_labels[i].text = sname


func _find_sfx_duration(stream_name: String, ch: int) -> float:
	for key in AudioData.TRACKS:
		var t: Dictionary = AudioData.TRACKS[key]
		if t.group != "sfx":
			continue
		var expected := "%s__%s" % [key, AudioData.CHANNEL_NAMES[ch]]
		if stream_name == expected:
			return t.duration
	return 1.0
