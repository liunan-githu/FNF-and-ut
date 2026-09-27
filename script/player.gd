extends CharacterBody2D

## 探索场景：主角（四向走动 + 走路动画 + 像素碰撞）
## 方向键 或 WASD；F11 全屏

@export var speed: float = 260.0      ## 移动速度（世界像素/秒）
@export var map_scale: float = 3.0    ## 背景放大倍数（世界坐标 = 图像坐标 × 该值）

const BG_PATH := "res://assets/room1.png"
const SHEET_PATH := "res://dustinbf.png"

## dustinbf 网格（4 列 × 3 行，每格 30×39）各方向的帧序列
const DIR_FRAMES := {
	"down":  [0, 1, 2, 1],
	"left":  [3, 4, 5, 4],
	"up":    [6, 7, 8, 7],
	"right": [9, 10, 11, 10],
}

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D

var _bg: Image = null
var _w := false
var _a := false
var _s := false
var _d := false


func _ready() -> void:
	_sprite.sprite_frames = _build_frames()
	_sprite.animation = "down"
	_sprite.play()

	var tex: Texture2D = load(BG_PATH)
	if tex:
		_bg = tex.get_image()
		if _bg:
			_bg.convert(Image.FORMAT_RGBA8)


func _build_frames() -> SpriteFrames:
	var tex: Texture2D = load(SHEET_PATH)
	var sf := SpriteFrames.new()
	for name in DIR_FRAMES:
		sf.add_animation(name)
		sf.set_animation_loop(name, true)
		sf.set_animation_speed(name, 9.0)
		for idx in DIR_FRAMES[name]:
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2((idx % 4) * 30, (idx / 4) * 39, 30, 39)
			sf.add_frame(name, at)
	sf.remove_animation("default")
	return sf


## 脚底所在的位置能不能站（非黑色即可走）
func _walkable(p: Vector2) -> bool:
	if _bg == null:
		return true
	var ix := int(p.x / map_scale)
	var iy := int(p.y / map_scale)
	if ix < 0 or iy < 0 or ix >= _bg.get_width() or iy >= _bg.get_height():
		return false
	var c := _bg.get_pixel(ix, iy)
	return (c.r + c.g + c.b) / 3.0 > 0.157


func _physics_process(delta: float) -> void:
	var dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if _a: dir.x -= 1.0
	if _d: dir.x += 1.0
	if _w: dir.y -= 1.0
	if _s: dir.y += 1.0
	dir = dir.limit_length(1.0)

	# 朝向 + 动画
	if dir.length() > 0.01:
		var d := "down"
		if absf(dir.x) > absf(dir.y):
			d = "right" if dir.x > 0.0 else "left"
		else:
			d = "down" if dir.y > 0.0 else "up"
		if _sprite.animation != d:
			_sprite.animation = d
		_sprite.play()
	else:
		_sprite.pause()
		_sprite.frame = 0

	# 分轴移动 + 像素碰撞（卡在不可走处时放开，能走出来）
	var step := dir * speed * delta
	var np := position
	if _walkable(np):
		if _walkable(np + Vector2(step.x, 0.0)):
			np.x += step.x
		if _walkable(np + Vector2(0.0, step.y)):
			np.y += step.y
	else:
		np += step
	position = np


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		match event.physical_keycode:
			KEY_W: _w = event.pressed
			KEY_A: _a = event.pressed
			KEY_S: _s = event.pressed
			KEY_D: _d = event.pressed
