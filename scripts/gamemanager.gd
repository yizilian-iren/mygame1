extends Node2D

@export var slime_scene : PackedScene
@export var slime_timer : Timer

@export var dino_scene : PackedScene
@export var dino_timer : Timer

@export var dog_scene: PackedScene
@export var dog_timer : Timer

@export var skeleton_scene: PackedScene
@export var skeleton_timer : Timer

@export var frog_scene: PackedScene
@export var frog_timer : Timer

var enemy_scenes = []
var unlocked_count = 1
var spawn_timer = 0.0
var unlock_timer = 0.0
var spawn_interval = 3.0
var unlock_interval = 40.0
var spawn_count = 1

@export var score : int = 0
@export var score_label : Label
@export var game_over_label: Label
@export var player: Node
@export var level_up_label : Label

# name 是 i18n/strings.csv 里的 key
var upgrades = [
	{ "name": "UPG_ATTACK", "effect": func(): player.attack += 1 },
	{ "name": "UPG_SPEED", "effect": func(): player.move_speed += 5},
	{ "name": "UPG_HP", "effect": func(): player.hp += 2 },
	{ "name": "UPG_FIRE_RATE", "effect": func(): player.shoot_timer.wait_time *= 0.7 },
	{ "name": "UPG_CRIT", "effect": func(): player.crit_rate += 0.1 },
	{ "name": "UPG_BLAST", "effect": func(): player.fireball_explosion_radius += 8 },
	{ "name": "UPG_KNOCKBACK", "effect": func(): player.knockback_strength += 3 },
]

var selected_effects = []
# 升级的三个按钮停下的位置（相对屏幕中心）：上中、左下、右下。每次都停在这里，只上下浮动。
const UPGRADE_SLOTS = [Vector2(0, -95), Vector2(-195, 60), Vector2(195, 60)]
const FLOAT_HEIGHT = 14.0
const FLOAT_HALF = 0.9  # 上下浮动半个来回的时间
# 升级时黑幕收拢和三个选项飘出来用同一组时长和曲线，同时开始、同时到位（I-11）。
# 黑幕原来写的是 EXPO / EASE_OUT，但 set_trans 写在 tween_property 之后没生效，屏幕上一直是匀速；先保持看到的样子。
const REVEAL_TIME = 1.5
const REVEAL_TRANS = Tween.TRANS_LINEAR
const REVEAL_EASE = Tween.EASE_OUT
const REVEAL_DELAY = 0.75  # 选项等黑幕走到一半再出来，自己的入场同样是 REVEAL_TIME
# 飘出来：从停下位置下方 RISE 往上浮，冲过停的位置约 10 px（RISE_BACK 是回弹曲线的系数）再落回去；同时左右摆（旋转 SWAY_DEG、水平 SWAY_X），越摆越小，到位时归零
const RISE = 60.0
const RISE_BACK = 2.3
const SWAY_DEG = 4.0
const SWAY_X = 6.0
const SWAY_TURNS = 2.0  # 整个入场摆几个来回
var upgrade_tweens: Array[Tween] = []
@onready var upgrade_buttons = [
	$CanvasLayer/LevelUpPanel/Button,
	$CanvasLayer/LevelUpPanel/Button2,
	$CanvasLayer/LevelUpPanel/Button3
]


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	enemy_scenes = [
	{ "scene": slime_scene, "weight": 100 },
	{ "scene": dino_scene, "weight": 30 },
	{ "scene": dog_scene, "weight": 20 },
	{ "scene": skeleton_scene, "weight": 5 },
	{ "scene": frog_scene, "weight": 1 },
	]
	hide_screen_mask()
	# BGM 循环：.import 里也设了 loop，这里再保险一次（重新导入时 loop 曾被重置成 false）
	$AudioStreamPlayer.stream.loop = true
	for i in range(upgrade_buttons.size()):
		upgrade_buttons[i].pressed.connect(_on_upgrade_chosen.bind(i))




# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:#每帧运行
	update_status_panel()
	#怪物生成间隔
	
	if get_tree().paused:#如果暂停则不运行
		return
	spawn_timer -= delta
	if spawn_timer <= 0:
		spawn_timer = spawn_interval
		call_deferred("_spawn_multiple_enemies", spawn_count)

	unlock_timer += delta
	if unlock_timer >= unlock_interval:
		unlock_timer = 0.0
		if unlocked_count < enemy_scenes.size():
			unlocked_count += 1
		spawn_count += 5
		spawn_interval = max(0.1, spawn_interval * 0.95)



#生成怪物
func spawn_enemy():
	if get_tree().paused:
		return  # 暂停时不生成怪物
	var pool: Array = []

	# 用当前解锁数量限制敌人
	for i in range(unlocked_count):
		var item = enemy_scenes[i]
		for j in range(item["weight"]):
			pool.append(item["scene"])
			
	var scene = pool[randi() % pool.size()]
	var enemy = scene.instantiate()
	enemy.position = Vector2(260, randf_range(45, 130))
	enemy.player = player
	add_child(enemy)

func _spawn_multiple_enemies(count: int) -> void:
	for i in range(count):
		var delay = randf_range(0.0, 1.0)
		await get_tree().create_timer(delay).timeout
		spawn_enemy()
	
func show_game_over():
	game_over_label.visible = true


func show_level_up():
	if player.is_game_over:
		return 
	$"time stop".play()
	shrink_black_mask_to_circle()
	get_tree().paused = true
	
	var chosen = upgrades.duplicate()
	chosen.shuffle()
	chosen = chosen.slice(0, 3)

	selected_effects.clear()
	_stop_upgrade_tweens()
	var center = get_viewport().get_visible_rect().size / 2

	for i in range(3):
		var upgrade = chosen[i]
		var button = upgrade_buttons[i]
		button.text = upgrade["name"]  # key，按钮自己翻译，换语言时跟着变
		selected_effects.append(upgrade["effect"])

		# 固定大小、固定位置，从中心弹出来
		var rest = center + UPGRADE_SLOTS[i] - button.size / 2
		button.position = rest
		button.pivot_offset = button.size / 2
		button.scale = Vector2.ZERO

		button.rotation = 0.0

		# 三个按钮摆动的相位错开；到位后接上下浮动
		var phase = i * TAU / 3 + randf_range(-0.3, 0.3)
		var pop = create_tween()
		_float_in(0.0, button, rest, phase)
		pop.tween_interval(REVEAL_DELAY)
		pop.tween_method(_float_in.bind(button, rest, phase), 0.0, 1.0, REVEAL_TIME)
		pop.tween_callback(_start_float.bind(button, rest))
		upgrade_tweens.append(pop)


	level_up_label.visible = true
	get_node("level up/LevelUpAnim").play("show_level_up")
	$CanvasLayer/LevelUpPanel.visible = true
#选择完成
func _on_upgrade_chosen(index: int):
	$button.play()
	selected_effects[index].call()  # 执行玩家选的那个升级效果

	_stop_upgrade_tweens()
	$CanvasLayer/LevelUpPanel.visible = false
	hide_screen_mask()
	get_tree().paused = false


# t 是入场的时间进度 0→1；大小和上升按黑幕的曲线走，摆动按时间走、幅度跟着收到 0
func _float_in(t: float, button: Button, rest: Vector2, phase: float):
	var p = Tween.interpolate_value(0.0, 1.0, t, 1.0, REVEAL_TRANS, REVEAL_EASE)
	var swing = sin(phase + t * SWAY_TURNS * TAU) * (1.0 - t)
	button.scale = Vector2.ONE * p
	button.rotation = deg_to_rad(SWAY_DEG) * swing
	var u = t - 1.0
	var rise = 1.0 + (RISE_BACK + 1.0) * u * u * u + RISE_BACK * u * u  # back-out：0→冲过 1→1
	button.position = rest + Vector2(SWAY_X * sin(phase - PI / 2 + t * SWAY_TURNS * TAU) * (1.0 - t), RISE * (1.0 - rise))

# 上下浮动：每个按钮起步时间不同，看起来不呆板；但只在停下的位置上方 FLOAT_HEIGHT 内动
func _start_float(button: Button, rest: Vector2):
	var float_tween = create_tween().set_loops()
	float_tween.tween_interval(randf_range(0.0, 0.5))
	float_tween.tween_property(button, "position:y", rest.y - FLOAT_HEIGHT, FLOAT_HALF).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	float_tween.tween_property(button, "position:y", rest.y, FLOAT_HALF).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	upgrade_tweens.append(float_tween)

func _stop_upgrade_tweens():
	for t in upgrade_tweens:
		t.kill()
	upgrade_tweens.clear()

func shrink_black_mask_to_circle():
	var mask = $CanvasLayer/ScreenMask
	mask.visible = true
	
	mask.material.set_shader_parameter("radius", 1.5)  # 一开始全透明
	

	var tween = create_tween()
	tween.tween_property(mask.material, "shader_parameter/radius", 0.0, REVEAL_TIME).set_trans(REVEAL_TRANS).set_ease(REVEAL_EASE)


func hide_screen_mask():
	$CanvasLayer/ScreenMask.hide()
	
func update_status_panel():
	var status = $CanvasLayer/Status
	var stats = $CanvasLayer/Status/Stats
	status.get_node("LevelLabel").text = tr("LEVEL") % player.level
	status.get_node("NextLabel").text = tr("NEXT_LEVEL") % player.remaining
	stats.get_node("HPValue").text = str(player.hp)
	stats.get_node("AttackValue").text = str(player.attack)
	stats.get_node("CritValue").text = "%d%%" % round(player.crit_rate * 100)
	stats.get_node("IntervalValue").text = tr("SECONDS") % player.shoot_timer.wait_time
	stats.get_node("SpeedValue").text = str(int(player.move_speed))
	stats.get_node("BlastValue").text = str(int(player.fireball_explosion_radius))
	stats.get_node("KnockbackValue").text = str(int(player.knockback_strength))
