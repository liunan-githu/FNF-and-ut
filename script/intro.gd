extends Control

## 开场视频：播放 → 进主场景
## 跳过：按住 Enter / 空格 / 左键，圆环排空即跳过

const NEXT_SCENE := "res://scene/2.tscn"
const HOLD_TIME := 1.8      ## 需要按住多久才跳过（秒）
const FRAME_COUNT := 15     ## holdCircle 的帧数
const FRAME_SIZE := 16      ## 每帧 16x16
const FRAME_STEP := 19      ## 每帧的垂直间距（16 + 3 间隔）

@onready var _video: VideoStreamPlayer = $Video
@onready var _hint: HBoxContainer = $SkipHint
@onready var _circle: TextureRect = $SkipHint/Circle
@onready var _label: Label = $SkipHint/Label

var _started := false
var _hold := 0.0
var _elapsed := 0.0
var _frames: Array[AtlasTexture] = []


func _ready() -> void:
	# 把 holdCircle.png（竖排 15 帧）切成 AtlasTexture
	var tex: Texture2D = load("res://holdCircle.png")
	for i in FRAME_COUNT:
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(0, 1 + i * FRAME_STEP, FRAME_SIZE, FRAME_SIZE)
		_frames.append(at)

	if not _frames.is_empty():
		_circle.texture = _frames[0]
	_hint.modulate.a = 0.0

	# 换 8bit 像素字体（关掉抗锯齿/次像素，字才清晰）
	var font := load("res://font/8bit-jve.ttf") as FontFile
	if font:
		font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		_label.add_theme_font_override("font", font)
		_label.add_theme_font_size_override("font_size", 32)

	_video.play()


func _process(delta: float) -> void:
	_elapsed += delta

	if _video.is_playing():
		_started = true

		var holding := Input.is_action_pressed("ui_accept") \
			or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)

		if holding:
			_hold += delta
		else:
			_hold = 0.0

		# 提示渐显 / 渐出
		var target := 1.0 if holding else 0.0
		_hint.modulate.a = move_toward(_hint.modulate.a, target, delta * 4.0)

		# 圆环进度：满(0) → 空(14)
		var idx := 0
		if holding:
			idx = clampi(int(_hold / HOLD_TIME * FRAME_COUNT), 0, FRAME_COUNT - 1)
		if not _frames.is_empty():
			_circle.texture = _frames[idx]

		if _hold >= HOLD_TIME:
			_finish()
	elif _started:
		_finish()
	elif _elapsed > 10.0:
		# 兜底：视频没能播放（解码失败等），别一直卡着
		push_warning("intro video did not start; skipping")
		_finish()


func _finish() -> void:
	set_process(false)
	_change_scene(NEXT_SCENE)


func _change_scene(path: String) -> void:
	# 框架模式：场景在 SceneContainer（SubViewport）内切换
	if global and global.get_scene_container():
		global.get_scene_container().change_scene_to_file(path)
	else:
		get_tree().change_scene_to_file(path)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F11:
		var mode := DisplayServer.window_get_mode()
		if mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
