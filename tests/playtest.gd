extends SceneTree
# 自动试玩（I-9）。改完代码先跑：
#   Godot --headless --path . -s tests/playtest.gd          检查，失败 exit 1
#   tools/record_clip.sh                                     带画面录一段（Movie Maker），给用户看
# headless 下触摸坐标要乘 root.get_final_transform()（见 _touch）。

var fails := 0
var demo := false  # -- --demo：录片段用的那一段，不做检查
var game: Node
var player: Node
var i18n: Node


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	demo = "--demo" in OS.get_cmdline_user_args()
	var had_cfg = FileAccess.file_exists("user://settings.cfg")
	await _load_game()
	i18n = root.get_node("I18n")
	var lang_arg = Array(OS.get_cmdline_user_args()).filter(func(a): return a.begins_with("--lang="))
	i18n._apply(lang_arg[0].substr(7) if lang_arg else "en")
	if demo:
		if "--touch" in OS.get_cmdline_user_args():  # 录手机画面：摇杆和 SWITCH 也显示出来
			game.get_node("TouchControls")._show()
		await _demo()
		quit()
		return

	_static_checks()
	await _keyboard()
	await _kill_and_level_up()
	await _upgrade_buttons_stay_put()
	await _languages()
	await _touch_controls()
	await _aspect_ratios()
	await _game_over_and_restart()

	if not had_cfg:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://settings.cfg"))
	print("FAILS: %d" % fails)
	quit(1 if fails else 0)


func _load_game() -> void:
	change_scene_to_file("res://scenes/game.tscn")
	await process_frame
	await process_frame
	game = current_scene
	player = game.get_node("player")
	game.spawn_timer = 1e9  # 不让怪自己刷出来，测试自己放


func _wait_until(cond: Callable, seconds: float) -> bool:
	var deadline = create_timer(seconds)  # 游戏时间：录片段时 Movie Maker 比实际时间慢
	while deadline.time_left > 0:
		if cond.call():
			return true
		await process_frame
	return cond.call()


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


# ---- 资源：BGM、字体覆盖 ----
func _static_checks() -> void:
	var bgm = game.get_node("AudioStreamPlayer")
	check(bgm.stream.loop and bgm.autoplay, "BGM 循环播放")

	var latin = load("res://AssetBundle/Uranus_Pixel_11Px.ttf")
	var ja = load("res://AssetBundle/Fonts/DotGothic16-Regular.ttf")
	var f = FileAccess.open("res://i18n/strings.csv", FileAccess.READ)
	f.get_csv_line()
	var miss_en = ""; var miss_ja = ""; var miss_zh = ""
	while not f.eof_reached():
		var row = f.get_csv_line()
		if row.size() < 4:
			continue
		for c in row[1].c_unescape():
			if c != "\n" and not latin.has_char(c.unicode_at(0)): miss_en += c
		for c in row[2].c_unescape():
			if c != "\n" and not ja.has_char(c.unicode_at(0)): miss_ja += c
		for c in row[3].c_unescape():
			if c != "\n" and not latin.has_char(c.unicode_at(0)) and not ja.has_char(c.unicode_at(0)): miss_zh += c
	check(miss_en == "", "英文字都有字形 '%s'" % miss_en)
	check(miss_ja == "", "日文字 DotGothic16 都有 '%s'" % miss_ja)
	check(miss_zh == "", "中文字 Uranus / DotGothic16 都有 '%s'" % miss_zh)
	check("\n" in tr("HINT_KEYS"), "CSV 的 \\n 变成换行")

	var tc = game.get_node("TouchControls")
	var screen = game.get_viewport().get_canvas_transform() * player.global_position
	check(screen.distance_to(tc.stick_rest) > tc.STICK_RADIUS + 40 and screen.distance_to(tc.button_pos) > tc.BUTTON_RADIUS + 40, "开局位置不被 SWITCH 和摇杆挡住 %s" % screen)


# ---- 键盘：移动、换武器 ----
func _keyboard() -> void:
	var x0 = player.position.x
	_key(KEY_D, true)
	await _frames(15)
	check(player.velocity.x > 0 and player.position.x > x0 + 5, "按 D 往右走 %.1f → %.1f" % [x0, player.position.x])
	_key(KEY_D, false)
	await _frames(3)
	check(player.velocity == Vector2.ZERO, "松开 D 停下")
	var y0 = player.position.y
	_key(KEY_W, true)
	await _frames(8)
	_key(KEY_W, false)
	await _frames(2)
	check(player.position.y < y0, "按 W 往上走")

	var w0 = player.current_weapon
	_key(KEY_Q, true); await process_frame; _key(KEY_Q, false); await process_frame
	check(player.current_weapon != w0, "按 Q 换武器 %s → %s" % [w0, player.current_weapon])
	_key(KEY_Q, true); await process_frame; _key(KEY_Q, false); await process_frame
	check(player.current_weapon == w0, "再按 Q 换回来")


# ---- 自动射击打死怪 → 升级弹出三个选项 → 选一个继续 ----
func _kill_and_level_up() -> void:
	var slime = game.slime_scene.instantiate()
	slime.player = player
	slime.position = player.position + Vector2(140, 4)  # 子弹从 player + (10, 6) 出去
	game.add_child(slime)
	var killed = await _wait_until(func(): return player.level == 2, 12.0)
	check(killed, "自动射击打死放在前面的史莱姆，升到 2 级")
	if not killed:
		return
	await process_frame
	var panel = game.get_node("CanvasLayer/LevelUpPanel")
	check(panel.visible and paused, "弹出升级选项并暂停")
	var texts = game.upgrade_buttons.map(func(b): return b.text)
	check(texts.size() == 3 and texts[0] != texts[1] and texts[1] != texts[2] and texts[0] != texts[2], "三个不同的选项 %s" % [texts])

	var before = _stats()
	await create_timer(0.3).timeout
	check(game.upgrade_buttons[0].scale.x < 0.01, "黑幕走到一半前选项还没出来（scale %.3f）" % game.upgrade_buttons[0].scale.x)
	await create_timer(game.REVEAL_DELAY).timeout
	var s = game.upgrade_buttons[0].scale.x
	check(s > 0.05 and s < 0.9, "出来后 0.3 s 选项还在慢慢飘（scale %.2f）" % s)
	var r = game.get_node("CanvasLayer/ScreenMask").material.get_shader_parameter("radius")
	var t = 0.3 / game.REVEAL_TIME
	check(absf(s - Tween.interpolate_value(0.0, 1.0, t, 1.0, game.REVEAL_TRANS, game.REVEAL_EASE)) < 0.1
		and absf(r - Tween.interpolate_value(1.5, -1.5, t + game.REVEAL_DELAY / game.REVEAL_TIME, 1.0, game.REVEAL_TRANS, game.REVEAL_EASE)) < 0.15,
		"选项和黑幕按同一条曲线走（scale %.2f，radius %.2f）" % [s, r])
	game.upgrade_buttons[0].pressed.emit()  # 飘出来途中点也能选
	await process_frame
	check(not panel.visible and not paused, "选完关掉面板、继续游戏")
	check(_stats() != before, "选的升级生效了（%s）" % texts[0])
	var x0 = player.position.x
	_key(KEY_D, true)
	await _frames(10)
	_key(KEY_D, false)
	check(player.position.x > x0, "升级后还能动")


func _stats() -> Array:
	return [player.attack, player.move_speed, player.hp, player.shoot_timer.wait_time,
		player.crit_rate, player.fireball_explosion_radius, player.knockback_strength]


# ---- 升级按钮每次停在同样的位置（I-4） ----
func _upgrade_buttons_stay_put() -> void:
	var rests = []
	var tween_counts = []
	for round in 6:
		player.level_up()
		await create_timer(game.REVEAL_DELAY + game.REVEAL_TIME + 0.05).timeout
		rests.append(game.upgrade_buttons.map(func(b): return [b.position, b.size, b.scale, b.rotation]))
		game.upgrade_buttons[1].pressed.emit()
		await process_frame
		tween_counts.append(get_processed_tweens().size())
	var center = root.get_visible_rect().size / 2
	for i in 3:
		var xs = rests.map(func(r): return r[i][0].x)
		var ys = rests.map(func(r): return r[i][0].y)
		var rest = center + game.UPGRADE_SLOTS[i] - rests[0][i][1] / 2
		check(xs.max() - xs.min() < 0.01, "按钮%d x 每次一样" % i)
		check(ys.min() >= rest.y - game.FLOAT_HEIGHT - 0.01 and ys.max() <= rest.y + 0.01, "按钮%d y 在浮动范围内 %s" % [i, ys])
		check(rests.all(func(r): return r[i][2].is_equal_approx(Vector2.ONE)), "按钮%d 弹出后 scale=1" % i)
		check(rests.all(func(r): return is_zero_approx(r[i][3])), "按钮%d 到位后 rotation=0" % i)
	check(tween_counts.max() <= 1, "选完以后 tween 不累积 %s" % [tween_counts])
	for b in game.upgrade_buttons:
		var w = b.get_theme_font("font").get_string_size(tr(b.text), HORIZONTAL_ALIGNMENT_LEFT, -1, b.get_theme_font_size("font_size")).x
		check(w < b.size.x, "按钮文字不超出 %s" % tr(b.text))


# ---- 语言切换（I-3、I-10） ----
func _languages() -> void:
	var lang = game.get_node("CanvasLayer/LangSwitch")
	var level_label = game.get_node("CanvasLayer/Status/LevelLabel")
	var cases = {"JA": ["ja", "レベル", i18n.ja_font], "ZH": ["zh", "等级", i18n.latin_font], "EN": ["en", "Level", i18n.latin_font]}
	for btn in cases:
		var c = cases[btn]
		await _tap(lang.get_node(btn).get_global_rect().get_center(), 0)
		await process_frame
		await process_frame
		check(i18n.current() == c[0] and i18n.ui_font.base_font == c[2], "点 %s → %s，字体对" % [btn, c[0]])
		check(level_label.text.begins_with(c[1]), "%s 的状态面板：%s" % [c[0], level_label.text])
		var cfg = ConfigFile.new(); cfg.load("user://settings.cfg")
		check(cfg.get_value("game", "lang", "") == c[0], "记住了 %s" % c[0])
		check(lang.get_node(btn).modulate.a == 1.0, "%s 按钮亮" % btn)
		var w = game.get_node("CanvasLayer/Status").get_combined_minimum_size().x
		check(w < 300, "%s 状态面板宽 %.0f < 300" % [c[0], w])


# ---- 手机：SWITCH、摇杆（I-1、I-5） ----
func _touch_controls() -> void:
	var tc = game.get_node("TouchControls")
	tc._show()
	var size = root.get_visible_rect().size
	var panel_bottom = game.get_node("CanvasLayer/Status/Stats").get_global_rect().end.y
	check(tc.button_pos.x < size.x * 0.1 and tc.button_pos.y - tc.BUTTON_RADIUS > panel_bottom, "SWITCH 在属性面板正下方 %s" % tc.button_pos)
	check(tc.stick_rest.x < size.x * 0.25 and tc.stick_rest.y + tc.STICK_RADIUS <= size.y and tc.stick_rest.y > size.y * 0.7, "摇杆停在左下角 %s" % tc.stick_rest)
	check(tc.stick_rest.distance_to(tc.button_pos) > tc.STICK_RADIUS + tc.BUTTON_RADIUS, "摇杆起始圈不压 SWITCH")

	var w0 = player.current_weapon
	_touch(1, tc.button_pos + Vector2(tc.BUTTON_RADIUS + 15, 0), true); await process_frame
	check(tc.button_touch == 1 and tc.stick_touch == -1, "按 SWITCH（圆外一点）不起摇杆")
	_touch(1, tc.button_pos, false); await process_frame
	check(player.current_weapon != w0, "SWITCH 换武器")
	_touch(1, tc.button_pos, true); await process_frame
	_touch(1, tc.button_pos, false); await process_frame

	_touch(0, Vector2(400, 450), true)
	_drag(0, Vector2(480, 450))
	await _frames(3)
	check(tc.stick_touch == 0 and player.velocity.x > 0, "左半屏拖动 → 往右走")
	_touch(0, Vector2(480, 450), false)
	await _frames(2)
	check(player.velocity == Vector2.ZERO, "松手停下")
	_touch(2, Vector2(size.x * 0.75, 450), true); await process_frame
	check(tc.stick_touch == -1, "右半屏不起摇杆")
	_touch(2, Vector2(size.x * 0.75, 450), false)
	check(game.get_node("CanvasLayer/Label").text == "HINT_TOUCH", "提示换成手机版")


# ---- 手机横屏等不同比例：不留黑边，HUD 和按钮都在屏内（I-15） ----
func _aspect_ratios() -> void:
	var win = root.size
	var tc = game.get_node("TouchControls")
	var cam = game.get_node("Camera2D")
	for c in [[Vector2i(2532, 1170), "19.5:9"], [Vector2i(1024, 768), "4:3"]]:
		root.size = c[0]
		await _frames(3)
		var view = root.get_visible_rect()
		var aspect = float(c[0].x) / c[0].y
		check(absf(view.size.x / view.size.y - aspect) < 0.01, "%s：画面和窗口同比例，没有黑边 %s" % [c[1], view.size])
		var hud_ok = true
		for path in ["CanvasLayer/Status", "CanvasLayer/LangSwitch", "CanvasLayer/Label"]:
			hud_ok = hud_ok and view.encloses(game.get_node(path).get_global_rect())
		check(hud_ok, "%s：状态面板、语言按钮、提示都在屏内" % c[1])
		check(view.has_point(tc.button_pos) and view.has_point(tc.stick_rest + Vector2(0, tc.STICK_RADIUS)), "%s：SWITCH 和摇杆在屏内" % c[1])
		check(game.get_node("CanvasLayer/ScreenMask").get_global_rect().encloses(view), "%s：升级时的遮罩盖满全屏" % c[1])
		# 世界里看得到的范围都铺着背景（背景 4 列 × 3 排、240×280 一张，中心在镜头处）
		var half = view.size / 2 / cam.zoom
		check(half.x <= 480 and half.y <= 420, "%s：背景盖得住看得到的世界 ±%s" % [c[1], half])
		check(game.EnemyScript.view_half_width(game) > half.x - 1, "%s：怪从屏幕外出来" % c[1])
	root.size = win
	await _frames(3)


# ---- GAME OVER 后自己重开 ----
func _game_over_and_restart() -> void:
	var old = game
	player.take_damage(999)
	await process_frame
	check(player.is_game_over and game.get_node("CanvasLayer/game over label").visible, "HP 到 0 显示 GAME OVER")
	var restarted = await _wait_until(func(): return current_scene != null and current_scene != old, 6.0)
	check(restarted, "几秒后重开")
	if restarted:
		await process_frame
		await process_frame
		var p = current_scene.get_node("player")
		check(not p.is_game_over and p.hp > 0 and p.level == 1, "重开后从 1 级、满血开始")


# ---- 录片段用的一段（约 8 秒，不检查）：走、打死怪、升级、选、换成火球再打一只 ----
func _demo() -> void:
	_spawn_slime(Vector2(140, 4))
	_key(KEY_D, true); await create_timer(0.6).timeout; _key(KEY_D, false)
	_key(KEY_W, true); await create_timer(0.3).timeout; _key(KEY_W, false)
	_key(KEY_S, true); await create_timer(0.3).timeout; _key(KEY_S, false)
	await _wait_until(func(): return paused, 6.0)
	await create_timer(3.6).timeout
	game.upgrade_buttons[0].pressed.emit()
	await create_timer(0.3).timeout
	_key(KEY_Q, true); await process_frame; _key(KEY_Q, false)
	_spawn_slime(Vector2(120, 4))
	await create_timer(2.2).timeout


func _spawn_slime(offset: Vector2) -> void:
	var slime = game.slime_scene.instantiate()
	slime.player = player
	slime.position = player.position + offset
	game.add_child(slime)


func _key(keycode: Key, pressed: bool) -> void:
	var e = InputEventKey.new()
	e.physical_keycode = keycode
	e.keycode = keycode
	e.pressed = pressed
	Input.parse_input_event(e)


func _tap(p: Vector2, i: int) -> void:
	_touch(i, p, true)
	await process_frame
	_touch(i, p, false)


func _touch(i: int, p: Vector2, pressed: bool) -> void:
	var e = InputEventScreenTouch.new()
	e.index = i; e.position = root.get_final_transform() * p; e.pressed = pressed
	Input.parse_input_event(e)


func _drag(i: int, p: Vector2) -> void:
	var e = InputEventScreenDrag.new()
	e.index = i; e.position = root.get_final_transform() * p
	Input.parse_input_event(e)
