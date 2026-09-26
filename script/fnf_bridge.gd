extends Node
## FNF 战斗桥：进入战斗时无缝嵌入运行 Codename Engine（另一个游戏），
## 曲终/退出后回到「尘埃传说」并把战斗判为胜利。
## 仅 Windows 生效；其他平台（含移动端）自动跳过。

const ENABLED := true
## 进入 FNF 战斗时切全屏，返回后恢复窗口化（避免开局就强制全屏放大画面）
const FORCE_FULLSCREEN := true

## 开发时 FNF 所在目录（用 Godot 编辑器运行时走这里）
## ⚠️ 必须是纯英文路径：CNE 在中文路径下会卡死
const DEV_FNF_DIR := "D:\\DustLegend\\fnf"
## 备选路径（DEV_FNF_DIR 里没有 CodenameEngine.exe 时会依次尝试）
const DEV_FNF_CANDIDATES: Array[String] = ["D:\\FNF\\CHENAI1"]
## 导出后 FNF 放在「游戏 exe 同级」的这个子目录里
const FNF_SUBDIR := "fnf"

const CNE_ARGS := ["-mod", "dustin", "-dustlink", "broken-reality", "hard"]
const HELPER_PATH := "res://tools/embed_window.ps1"
const RESULT_PATH := "user://fnf_embed_result.txt"
const DEATH_SCENE := "res://Overworld/GameOver.tscn"
const DEBUG_TRIGGER_KEY := KEY_F9

## ============ 触发配置（关键）============
## 只有 encounter 名字/路径命中的战斗才会切到 FNF。
## 名字来自 Encounter 资源里的 `encounter_name`，例如 sans_cpp.tres 是 "SANS_CPP"。
## 留空 = 不自动触发任何战斗（只在你自己调用 start_fnf() 时触发）。
const TRIGGER_ENCOUNTERS := ["SANS_CPP"]
## 调试用：true = 任意战斗都触发（测试完后请改回 false）
const TRIGGER_ANY_BATTLE := false
## 战斗触发时瞬间全黑（消除 Godot 战斗画面闪现）
const INSTANT_BLACKOUT := true

## 红心过场结束后：保持黑屏的短暂停顿，然后进 FNF（不显露大世界）
const TRANSITION_HOLD_TIME := 0.12

var _last_battle: Node = null

var _active := false
var _pid := -1
var _helper_pid := -1
var _from_battle := false
var _overlay_retried := false
var _helper_checked := false
var _transitioning := false
var _forced_fullscreen := false
var pending_death_pos := Vector2.ZERO

var _layer: CanvasLayer
var _fade: ColorRect
var _scene_container: Object = null
var _bus_master := -1

## 运行时解析出来的 FNF 路径
var _fnf_dir := ""
var _exe_path := ""
var _result_file := ""
var _work_dir := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_bus_master = AudioServer.get_bus_index("Master")
	_resolve_fnf_paths()
	_setup_fade()
	if not ENABLED or OS.get_name() != "Windows":
		set_process(false)
		set_process_unhandled_input(false)
		return
	call_deferred("_boot")


## 解析 FNF 路径：
##   导出版  -> exe同级/fnf（自动，随便搬）
##   编辑器  -> 1) user://fnf_dir.txt 里写的路径（改文件即可，不用改代码）
##              2) DEV_FNF_DIR / 候选列表里第一个存在的
func _resolve_fnf_paths() -> void:
	if OS.has_feature("template"):
		_fnf_dir = OS.get_executable_path().get_base_dir().path_join(FNF_SUBDIR)
	else:
		_fnf_dir = _find_dev_fnf_dir()
	_work_dir = _fnf_dir
	_exe_path = _fnf_dir.path_join("CodenameEngine.exe")
	_result_file = _fnf_dir.path_join("dustlink_result.txt")
	print("[FNBBridge] fnf dir = %s" % _fnf_dir)


## 开发期找 FNF：优先 user://fnf_dir.txt，其次候选路径
func _find_dev_fnf_dir() -> String:
	var cfg := "user://fnf_dir.txt"
	if FileAccess.file_exists(cfg):
		var f := FileAccess.open(cfg, FileAccess.READ)
		if f != null:
			var s := f.get_as_text().strip_edges()
			f.close()
			if s != "" and FileAccess.file_exists(s.path_join("CodenameEngine.exe")):
				return s
	var candidates: Array[String] = []
	candidates.append(DEV_FNF_DIR)
	candidates.append_array(DEV_FNF_CANDIDATES)
	for c in candidates:
		if c != "" and FileAccess.file_exists(c.path_join("CodenameEngine.exe")):
			return c
	# 都找不到就返回默认值（后面会报错提示）
	return DEV_FNF_DIR


## 兼容导出后的命令行：同时识别 `--flag` 与 `-- --flag` 两种写法
func _has_flag(flag: String) -> bool:
	return OS.get_cmdline_user_args().has(flag) or OS.get_cmdline_args().has(flag)


func _setup_fade() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 128
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.anchor_right = 1.0
	_fade.anchor_bottom = 1.0
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_fade)
	add_child(_layer)


func _boot() -> void:
	# 等 SceneContainer 就绪
	for i in 1200:
		if _get_container() != null:
			break
		await get_tree().process_frame

	_scene_container = _get_container()
	if _scene_container == null:
		push_warning("[FNBBridge] SceneContainer not found")

	# 自测钩子：godot ... -- --fnf-test
	if _has_flag("--fnf-test"):
		print("[FNBBridge] self-test in 2s")
		await get_tree().create_timer(2.0).timeout
		start_fnf(false)

	# 整链自测：模拟加载一场战斗，验证「战斗→FNF→返回判胜」
	if _has_flag("--fnf-battle-test"):
		print("[FNBBridge] battle self-test in 3s")
		await get_tree().create_timer(3.0).timeout
		var tres = load("res://Battle/tres/sans_cpp.tres")
		if tres != null and scene_changer:
			scene_changer.load_battle(tres)
		else:
			push_error("[FNBBridge] cannot load test battle")

	# 拦截自测：模拟你脚本里的用法，验证「零闪烁直接进 FNF」
	if _has_flag("--fnf-intercept-test"):
		print("[FNBBridge] intercept self-test in 3s")
		await get_tree().create_timer(3.0).timeout
		var enc = load("res://Battle/tres/sans_cpp.tres")
		if enc != null:
			if not intercept_encounter(enc):
				scene_changer.load_battle(enc)
		else:
			push_error("[FNBBridge] cannot load test encounter")

	# 死亡场景自测
	if _has_flag("--death-test"):
		print("[FNBBridge] death self-test in 3s")
		await get_tree().create_timer(3.0).timeout
		_go_game_over()


func _get_container() -> Object:
	if not global:
		return null
	if not global.has_method("get_scene_container"):
		return null
	return global.get_scene_container()


## 进 FNF 前切全屏（需要 SceneContainer；直接运行子场景时跳过）
func _enter_fullscreen() -> void:
	if not FORCE_FULLSCREEN or not global:
		return
	if _get_container() == null:
		return
	if global.has_method("get_fullscreen") and global.has_method("toggle_fullscreen"):
		if not global.get_fullscreen():
			global.toggle_fullscreen()
			_forced_fullscreen = true
			print("[FNBBridge] fullscreen on")


## FNF 结束后恢复窗口化（只恢复我们自己切的）
func _restore_windowed() -> void:
	if not _forced_fullscreen:
		return
	_forced_fullscreen = false
	if global and global.has_method("get_fullscreen") and global.has_method("toggle_fullscreen"):
		if global.get_fullscreen():
			global.toggle_fullscreen()
			print("[FNBBridge] fullscreen off")


# ---------------------------------------------------------------- battle detection
# 框架用 scene_changer.load_battle() 直接设场景，不发 change_scene 信号，
# 所以这里每帧轮询当前场景是否为 BattleMain，并按 encounter 名字匹配。
func _poll_battle() -> void:
	var sc := _get_container()
	if sc == null:
		return
	var cur: Node = sc.get_current_scene() if sc.has_method("get_current_scene") else null
	if cur == null or not cur.is_class("BattleMain"):
		_last_battle = null
		return
	if cur == _last_battle:
		return
	_last_battle = cur
	_maybe_trigger_for_battle(cur)


func _maybe_trigger_for_battle(battle: Node) -> void:
	var enc = battle.call("get_encounter") if battle.has_method("get_encounter") else null
	if _matches_encounter(enc):
		print("[FNBBridge] battle match -> launching FNF")
		start_fnf(true)


func _matches_encounter(enc) -> bool:
	if TRIGGER_ANY_BATTLE:
		return true
	if enc == null or TRIGGER_ENCOUNTERS.is_empty():
		return false
	var enc_name := ""
	if enc.has_method("get_encounter_name"):
		enc_name = str(enc.call("get_encounter_name"))
	var enc_path := ""
	if enc is Resource:
		enc_path = (enc as Resource).resource_path
	for want in TRIGGER_ENCOUNTERS:
		var w := str(want)
		if enc_name == w or enc_path == w or enc_name.to_lower() == w.to_lower():
			return true
	return false


# ---------------------------------------------------------------- 公开 API
## 【推荐】在你自己触发战斗的地方先问一句：
##   if not fnf_bridge.intercept_encounter(encounter_res):
##       scene_changer.load_battle(encounter_res)   # 不匹配才走原版战斗
## 匹配时会先播框架的红心战斗过场（battle_transition），播完再进 FNF。
## FNF 结束后直接回到大地图（无需判胜，因为没有战斗场景）。
func intercept_encounter(enc) -> bool:
	if not ENABLED or OS.get_name() != "Windows":
		return false
	if _active or _pid > 0 or _transitioning:
		return true
	if not _matches_encounter(enc):
		return false
	print("[FNBBridge] intercept encounter -> battle transition, then FNF")
	_play_transition_then_fnf()
	return true


## 播放框架原版战斗过场（红心闪烁），播完后：黑幕交接 → 淡出回到大世界 → 停一下 → 渐渐变黑 → FNF
func _play_transition_then_fnf() -> void:
	_transitioning = true
	var sc := _get_container()
	var cur: Node = sc.get_current_scene() if sc != null and sc.has_method("get_current_scene") else null
	var ts = load("res://Engine/Overworld/battle_transition.tscn")
	if ts == null or cur == null:
		_transitioning = false
		start_fnf(false)
		return
	var t: Node = ts.instantiate()
	t.set_target(Vector2(48, 452))
	cur.add_child(t)
	t.completed.connect(func():
		if is_instance_valid(t):
			t.queue_free()
		_transition_done_to_fnf()
	)
	t.transition()


## 过场结束（此刻框架黑幕正好是黑的）：无缝接住黑屏，不露大世界，直接进 FNF。
func _transition_done_to_fnf() -> void:
	# 1) 立刻用我们的黑幕接管（框架黑幕此刻正好是黑的，交接无痕）
	_fade.color.a = 1.0
	# 2) 短暂停顿后进入 FNF（保持全黑，不显示大世界）
	await get_tree().create_timer(TRANSITION_HOLD_TIME).timeout
	_transitioning = false
	start_fnf(false, true)


## 在任意事件/脚本里直接切到 FNF。from_battle=true 时结束后会把当前战斗判胜。
func trigger_fnf(from_battle := true) -> void:
	start_fnf(from_battle)


func is_fnf_active() -> bool:
	return _active or _transitioning


# ---------------------------------------------------------------- core flow
func start_fnf(from_battle := false, already_black := false) -> void:
	if _active or _pid > 0:
		return
	_active = true
	_from_battle = from_battle
	_overlay_retried = false
	_helper_checked = false

	# 战斗触发时立刻全黑，避免 Godot 战斗画面闪现（最多 1 帧）
	if already_black:
		_fade.color.a = 1.0
	elif from_battle and INSTANT_BLACKOUT:
		_fade.color.a = 1.0
	else:
		await _fade_to(1.0, 0.35)

	# 全黑之后再切全屏，避免看到画面放大的一瞬间
	_enter_fullscreen()

	if _bus_master >= 0:
		AudioServer.set_bus_mute(_bus_master, true)
	get_tree().paused = true

	if FileAccess.file_exists(_result_file):
		DirAccess.remove_absolute(_result_file)

	_pid = OS.create_process(_exe_path, CNE_ARGS)
	if _pid <= 0:
		push_error("[FNBBridge] failed to launch FNF")
		_finish_fnf()
		return
	print("[FNBBridge] FNF pid=%d" % _pid)

	_spawn_helper(false)
	# 让加载期间保持黑屏（Godot 暂停仍会渲染，fade 保持在 1）


func _spawn_helper(overlay: bool) -> void:
	var hwnd := int(DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE))
	var helper_abs := _materialize_helper()
	var result_abs := ProjectSettings.globalize_path(RESULT_PATH)
	if FileAccess.file_exists(RESULT_PATH):
		DirAccess.remove_absolute(result_abs)
	var args := [
		"-NoProfile", "-ExecutionPolicy", "Bypass", "-File", helper_abs,
		"-ParentHwnd", str(hwnd), "-ChildPid", str(_pid), "-ResultFile", result_abs
	]
	if overlay:
		args.append("-Overlay")
	_helper_pid = OS.create_process("powershell.exe", args)
	print("[FNBBridge] helper pid=%d overlay=%s" % [_helper_pid, str(overlay)])


## 取出嵌入辅助脚本：编辑器直接用 res:// 实体文件；
## 导出后它是 pck 里的非资源文件，先释放到 user:// 再调用。
func _materialize_helper() -> String:
	var res_abs := ProjectSettings.globalize_path(HELPER_PATH)
	var user_abs := ProjectSettings.globalize_path("user://embed_window.ps1")
	if FileAccess.file_exists(HELPER_PATH):
		var src := FileAccess.open(HELPER_PATH, FileAccess.READ)
		if src != null:
			var txt := src.get_as_text()
			src.close()
			var out := FileAccess.open("user://embed_window.ps1", FileAccess.WRITE)
			if out != null:
				out.store_string(txt)
				out.close()
				return user_abs
	return res_abs


func _process(_delta: float) -> void:
	if not _active:
		if not _transitioning:
			_poll_battle()
		return
	if _pid <= 0:
		return

	if not OS.is_process_running(_pid):
		_finish_fnf()
		return

	# 嵌入失败则自动降级为无边框全屏叠加
	if not _helper_checked and _helper_pid > 0 and not OS.is_process_running(_helper_pid):
		_helper_checked = true
		var res := _read_result()
		print("[FNBBridge] helper result: %s" % res)
		if res.begins_with("ERROR") and not _overlay_retried and OS.is_process_running(_pid):
			_overlay_retried = true
			print("[FNBBridge] embed failed -> overlay fallback")
			_spawn_helper(true)


func _finish_fnf() -> void:
	var exited_pid := _pid
	_active = false
	if _pid > 0 and OS.is_process_running(_pid):
		OS.kill(_pid)
	_pid = -1

	if _helper_pid > 0 and OS.is_process_running(_helper_pid):
		OS.kill(_helper_pid)
	_helper_pid = -1

	get_tree().paused = false
	if _bus_master >= 0:
		AudioServer.set_bus_mute(_bus_master, false)

	# 黑屏还在，静默恢复窗口化
	_restore_windowed()

	var result := _read_fnf_result(exited_pid)
	print("[FNBBridge] FNF result: %s" % result)

	# 失败 -> 死亡动画
	if result == "lose":
		_from_battle = false
		_go_game_over()
		return

	await _fade_to(0.0, 0.3)

	if _from_battle:
		_end_battle()
	_from_battle = false
	print("[FNBBridge] returned from FNF")


func _read_fnf_result(pid: int) -> String:
	# 优先读 FNF 写的结果文件
	if FileAccess.file_exists(_result_file):
		var f := FileAccess.open(_result_file, FileAccess.READ)
		if f != null:
			var s := f.get_as_text().strip_edges().to_lower()
			f.close()
			if s != "":
				return s
	# 退回用退出码：2 = 失败
	if pid > 0:
		var code := OS.get_process_exit_code(pid)
		if code == 2:
			return "lose"
	return "win"


## 失败：切到死亡动画场景（保持黑幕，不露大世界），播完回大地图。
func _go_game_over() -> void:
	var sc := _get_container()
	var cur: Node = sc.get_current_scene() if sc != null and sc.has_method("get_current_scene") else null
	if cur != null and cur.has_method("get_player"):
		var pl = cur.get_player()
		if pl != null:
			pending_death_pos = pl.global_position
	_fade.color.a = 0.0
	var done := false
	if sc != null and sc.has_method("change_scene_to_file"):
		sc.change_scene_to_file(DEATH_SCENE)
		done = true
	if not done:
		get_tree().change_scene_to_file(DEATH_SCENE)
	print("[FNBBridge] FNF failed -> death scene")


func _end_battle() -> void:
	var sc := _get_container()
	if sc == null:
		return
	var cur: Node = sc.get_current_scene() if sc.has_method("get_current_scene") else null
	if cur == null:
		return
	if cur.has_method("spare_enemy"):
		cur.call("spare_enemy", 0)
		print("[FNBBridge] battle spared")
	elif cur.has_method("kill_enemy"):
		cur.call("kill_enemy", 0)
		print("[FNBBridge] battle killed")


# ---------------------------------------------------------------- helpers
func _read_result() -> String:
	if not FileAccess.file_exists(RESULT_PATH):
		return ""
	var f := FileAccess.open(RESULT_PATH, FileAccess.READ)
	if f == null:
		return ""
	var s := f.get_as_text().strip_edges()
	f.close()
	return s


func _fade_to(a: float, t: float) -> void:
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(_fade, "color:a", a, t)
	await tw.finished


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == DEBUG_TRIGGER_KEY:
		if _active:
			print("[FNBBridge] debug: killing FNF")
			if _pid > 0:
				OS.kill(_pid)
		else:
			print("[FNBBridge] debug: launching FNF (test)")
			start_fnf(false)
