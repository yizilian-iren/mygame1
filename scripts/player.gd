extends CharacterBody2D


#升级界面
@export var stat_panel: CanvasLayer
var is_panel_open = false
var level = 1
var attribute_points = 5
var attack = 1
var hp = 5
var crit_rate = 0
var remaining = 1
var fireball_explosion_radius = 20.0 #火球大小
@export var knockback_strength: float = 5.0



var current_skin_index = 0  # 0 = Foxy, 1 = Fiery Imp
@onready var skins = [$Foxy,$"Fiery Imp"]  # 注意名字大小写要对上
var is_foxy = true  # 当前是否是Foxy


@export var move_speed : float = 50
@export var animator :AnimatedSprite2D


var is_game_over :bool = false

var current_weapon = "normal"  # 默认武器类型
signal switch_hurt


#枪
@export var bullet_scene : PackedScene

#火球
@export var fireball_scene : PackedScene

var is_attacking = false #攻击动画锁

#升级
var kill_count = 0
var kills_to_level_up = 1
var player_level = 1

@export var shoot_timer: Timer

var fire_cooldown = 0.3  # 当前冷却时间
var fire_timer = 0.0  # 累计时间


		
func switch_skin():
	current_skin_index = (current_skin_index + 1) % skins.size()

	for i in range(skins.size()):
		skins[i].visible = i == current_skin_index
	
	# 更新 animator 引用
	animator = skins[current_skin_index]
	animator.play("idle")  # 初始动画（可选）
	
	
func _process(delta: float) -> void:
	if velocity == Vector2.ZERO or is_game_over:
		$runningsound.stop()
	elif not $runningsound.playing:
		$runningsound.play()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:
	if not is_game_over :
		velocity = Input.get_vector("left","right","up","down") * move_speed
		
		if not is_attacking:
		# 待机和跑步动画
			if  velocity == Vector2.ZERO:
				animator.play("idle")
			else:
				animator.play("run")
				
		move_and_slide()


func game_over():
	if not is_game_over:
		
		is_game_over = true
		
		get_tree().current_scene.show_game_over()
		$gameoversound.play()
		
		
		$RestartTimer.start()


func _unhandled_input(event):
	if event.is_action_pressed("switch_weapon"):
		$switch.play()
		switch_skin()
		if current_weapon == "normal":
			current_weapon = "fireball"
		else:
			current_weapon = "normal"
	
	if event.is_action_pressed("open_stat_panel"):
		toggle_stat_panel()


func _on_fire() -> void:
	if is_game_over or is_attacking:
		return
	
	var bullet
	if current_weapon == "normal":
		bullet = bullet_scene.instantiate()
		bullet.attack = attack 
		bullet.damage_source = "normal"
		$firesound.play()
		bullet.position = position + Vector2(10, 6)
		get_tree().current_scene.add_child(bullet)
	elif current_weapon == "fireball":
		if velocity == Vector2.ZERO: 
			is_attacking = true
			animator.play("shot")
			$fireball_shot.play()
			
			bullet = fireball_scene.instantiate()
			bullet.attack = attack
			bullet.explosion_radius = fireball_explosion_radius  #传入爆炸范围
			bullet.damage_source = "fireball"
			bullet.player = self
			await get_tree().create_timer(0.4).timeout
			
			bullet.position = position + Vector2(10, 6)
			get_tree().current_scene.add_child(bullet)
			return
	else:
		return  # 保险：未知武器不发射


func _reload_scene(_anim_name: String = "") -> void:  # RestartTimer.timeout 不带参数
	get_tree().reload_current_scene()
	
func take_damage(amount: int):
	if is_game_over:
		return
	hp -= amount
	$hurt.play()
	if hp <= 0:
		hp = 0
		animator.play("game_over")
		game_over()
	else:
		flash_red()
		shake_camera()

func on_enemy_killed():
	remaining -= 1
	print("干掉一个，还剩：", remaining, "个")
	if remaining == 0:
		level_up()

func level_up():
	var label = get_tree().current_scene.get_node("level up")
	level += 1
	player_level += 2
	remaining = player_level
	kills_to_level_up += 1

	
	label.position = position + Vector2(-50, -28)
	label.visible = true
	label.get_node("LevelUpAnim").play("show_level_up")
	get_tree().current_scene.show_level_up()
	

	
	print("更吊了！当前等级为：", player_level)
	
	
		
func toggle_stat_panel():
	is_panel_open = !is_panel_open
	stat_panel.visible = is_panel_open
	get_tree().paused = is_panel_open
	
func flash_red():
	modulate = Color(1, 0, 0)  # 变红
	await get_tree().create_timer(0.2).timeout
	modulate = Color(1, 1, 1)  # 恢复原色
	
func shake_camera():
	var camera = get_node("../Camera2D") # 根据实际路径改一下
	var original_offset = camera.offset
	var tween = create_tween()
	
	# 快速左右晃动
	tween.tween_property(camera, "offset", original_offset + Vector2(10, 0), 0.05)
	tween.tween_property(camera, "offset", original_offset - Vector2(10, 0), 0.05)
	tween.tween_property(camera, "offset", original_offset, 0.05)


func _on_fiery_imp_animation_finished() -> void:
	is_attacking = false
