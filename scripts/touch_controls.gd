extends CanvasLayer
# 手机上的虚拟摇杆和按钮：只在触屏设备上显示（或第一次收到触摸时显示）。
# 两个都在左手（D-002）：SWITCH 在左下角，左半屏其余地方是浮动摇杆；右半屏不放控件，看得清右边来的怪。
# 摇杆按下 left / right / up / down，按钮发 switch_weapon，和键盘走同一套 Input action，player.gd 不用改。

const STICK_RADIUS := 90.0
const KNOB_RADIUS := 38.0
const BUTTON_RADIUS := 72.0
const FULLSCREEN_RADIUS := 34.0

var font: Font = preload("res://AssetBundle/Uranus_Pixel_11Px.ttf")
var pad := Node2D.new()

var stick_rest := Vector2.ZERO
var stick_center := Vector2.ZERO
var stick_knob := Vector2.ZERO
var stick_touch := -1  # 按着摇杆的那根手指，-1 = 没有
var button_pos := Vector2.ZERO
var button_touch := -1
var fullscreen_pos := Vector2.ZERO


func _ready() -> void:
	layer = 50
	pad.draw.connect(_draw_pad)
	add_child(pad)
	get_viewport().size_changed.connect(_layout)
	_layout()
	visible = false
	if DisplayServer.is_touchscreen_available():
		_show()


func _show() -> void:
	visible = true
	var hint = get_node_or_null("../CanvasLayer/Label")
	if hint:
		hint.text = "HINT_TOUCH"  # i18n/strings.csv 的 key


func _layout() -> void:
	var size = get_viewport().get_visible_rect().size
	button_pos = Vector2(115, size.y - 115)
	stick_rest = Vector2(330, size.y - 160)
	fullscreen_pos = Vector2(size.x - 48, 104)  # 右上角语言按钮的下面
	if stick_touch == -1:
		stick_center = stick_rest
		stick_knob = stick_rest
	pad.queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if not visible:
			_show()
		if event.pressed:
			_on_press(event.index, event.position)
		else:
			_on_release(event.index)
	elif event is InputEventScreenDrag and event.index == stick_touch:
		_move_stick(event.position)
		get_viewport().set_input_as_handled()


func _on_press(index: int, pos: Vector2) -> void:
	var size = get_viewport().get_visible_rect().size
	if _fullscreen_shown() and pos.distance_to(fullscreen_pos) < FULLSCREEN_RADIUS * 1.5:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		get_viewport().set_input_as_handled()
	elif button_touch == -1 and pos.distance_to(button_pos) < BUTTON_RADIUS * 1.3:
		button_touch = index
		_send_action("switch_weapon", true)
		get_viewport().set_input_as_handled()
	elif stick_touch == -1 and pos.x < size.x * 0.5:
		# 摇杆跟着手指落下的地方出现
		stick_touch = index
		stick_center = pos
		_move_stick(pos)
		get_viewport().set_input_as_handled()
	pad.queue_redraw()


func _on_release(index: int) -> void:
	if index == stick_touch:
		_release_stick()
	if index == button_touch:
		_release_button()


func _move_stick(pos: Vector2) -> void:
	var offset = (pos - stick_center).limit_length(STICK_RADIUS)
	stick_knob = stick_center + offset
	var v = offset / STICK_RADIUS
	_set_action("left", -v.x)
	_set_action("right", v.x)
	_set_action("up", -v.y)
	_set_action("down", v.y)
	pad.queue_redraw()


func _release_stick() -> void:
	stick_touch = -1
	stick_center = stick_rest
	stick_knob = stick_rest
	for action in ["left", "right", "up", "down"]:
		Input.action_release(action)
	pad.queue_redraw()


func _release_button() -> void:
	button_touch = -1
	_send_action("switch_weapon", false)
	pad.queue_redraw()


func _set_action(action: String, strength: float) -> void:
	if strength > 0.0:
		Input.action_press(action, strength)
	else:
		Input.action_release(action)


func _send_action(action: String, pressed: bool) -> void:
	var event = InputEventAction.new()
	event.action = action
	event.pressed = pressed
	Input.parse_input_event(event)


func _fullscreen_shown() -> bool:
	# iPhone 的 Safari 不支持网页全屏
	return OS.has_feature("web") and not OS.has_feature("web_ios") \
		and DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_FULLSCREEN


func _notification(what: int) -> void:
	# 升级、暂停时这里收不到松手的事件，先全部松开
	if what == NOTIFICATION_PAUSED or what == NOTIFICATION_EXIT_TREE:
		if stick_touch != -1:
			_release_stick()
		if button_touch != -1:
			_release_button()


func _draw_pad() -> void:
	var white = Color(1, 1, 1)
	pad.draw_circle(stick_center, STICK_RADIUS, Color(1, 1, 1, 0.12))
	pad.draw_arc(stick_center, STICK_RADIUS, 0, TAU, 48, Color(1, 1, 1, 0.45), 3)
	pad.draw_circle(stick_knob, KNOB_RADIUS, Color(1, 1, 1, 0.45 if stick_touch != -1 else 0.3))

	var pressed = button_touch != -1
	pad.draw_circle(button_pos, BUTTON_RADIUS, Color(1, 0.55, 0.2, 0.55 if pressed else 0.3))
	pad.draw_arc(button_pos, BUTTON_RADIUS, 0, TAU, 48, Color(1, 1, 1, 0.5), 3)
	pad.draw_string_outline(font, button_pos + Vector2(-BUTTON_RADIUS, 9), "SWITCH",
		HORIZONTAL_ALIGNMENT_CENTER, BUTTON_RADIUS * 2, 24, 8, Color(0, 0, 0, 0.6))
	pad.draw_string(font, button_pos + Vector2(-BUTTON_RADIUS, 9), "SWITCH",
		HORIZONTAL_ALIGNMENT_CENTER, BUTTON_RADIUS * 2, 24, white)

	if _fullscreen_shown():
		# 四个角的全屏图标
		var c = fullscreen_pos
		var r = 16.0
		var l = 9.0
		var col = Color(1, 1, 1, 0.7)
		pad.draw_circle(c, FULLSCREEN_RADIUS, Color(0, 0, 0, 0.3))
		for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
			var p = c + corner * r
			pad.draw_line(p, p - Vector2(corner.x * l, 0), col, 3)
			pad.draw_line(p, p - Vector2(0, corner.y * l), col, 3)
