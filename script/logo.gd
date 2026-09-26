extends Node2D

## Logo 场景：淡入 Logo + 播放音效，按 Z 进探索场景

const NEXT_SCENE := "res://Core/Custom/title.tscn"
const SOUND := "res://audio/mus_intronoise.ogg"
const FADE_TIME := 1.2

@onready var _logo: Sprite2D = $Logo
@onready var _hint: Label = $Hint

var _t := 0.0
var _can_start := false


func _ready() -> void:
	_logo.modulate.a = 0.0
	_hint.modulate.a = 0.0

	# 像素字体（关抗锯齿）
	var font := load("res://font/8bit-jve.ttf") as FontFile
	if font:
		font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		_hint.add_theme_font_override("font", font)
		_hint.add_theme_font_size_override("font_size", 28)

	# 音效
	var stream := load(SOUND)
	if stream:
		var p := AudioStreamPlayer.new()
		p.stream = stream
		add_child(p)
		p.play()


func _process(delta: float) -> void:
	_t += delta
	_logo.modulate.a = clampf(_t / FADE_TIME, 0.0, 1.0)
	if _t >= FADE_TIME:
		_can_start = true
		_hint.modulate.a = 0.6 + 0.4 * sin(_t * 4.0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_F11:
			var mode := DisplayServer.window_get_mode()
			if mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			else:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
			return
		if _can_start and event.keycode in [KEY_Z, KEY_ENTER, KEY_SPACE]:
			if global and global.get_scene_container():
				global.get_scene_container().change_scene_to_file(NEXT_SCENE)
			else:
				get_tree().change_scene_to_file(NEXT_SCENE)
