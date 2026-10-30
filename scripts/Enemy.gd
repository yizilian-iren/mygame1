extends Area2D

@export var speed: float = -50
@export var health: int = 1
@export var player : Node

@onready var hurt_sound: AudioStreamPlayer = $hurt  # 场景里的播放器

@export var default_hurt_sound: AudioStream# 音频资源（拖入 .ogg）
@export var fireball_hurt_sound: AudioStream 


var is_dead = false

#移动
func _process(delta):
	if not is_dead:
		position += Vector2(speed, 0) * delta
	if position.x < -view_half_width(self) - 60:
		queue_free()


#子弹碰撞
func _on_area_entered(area: Area2D) -> void:
	if is_dead:
		return
	if area.is_in_group("bullet"):
		area.queue_free()
		
		var sound_type = "normal"

		hurt_sound.play()
		#health -= 1
		var damage = area.attack  # 原始攻击力
		var is_crit = randf() < player.crit_rate  # 暴击判定
		var final_damage = damage * (2 if is_crit else 1)  # 暴击伤害加倍

		take_damage(final_damage, area.knockback_strength)
		show_damage_number(final_damage, is_crit)
		$hurt.play()
		flash_red()
		knockback(area.knockback_strength)  # 击退

#爆炸伤害
func take_damage(amount: int, knockback_strength: float, source: String = ""):
	health -= amount
	hurt_sound.play()
	flash_red()
	if health <= 0:
		die()
	else:
		knockback(player.knockback_strength)

#怪物碰撞
func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D and not is_dead:
		body.take_damage(1)

#受击
func knockback(strength: float = 30.0):
	position += Vector2(strength, 0)

func flash_red():
	$AnimatedSprite2D.modulate = Color(1, 0.2, 0.2)  # 红色调
	await get_tree().create_timer(0.1).timeout       # 等 0.1 秒
	$AnimatedSprite2D.modulate = Color(1, 1, 1)       # 恢复原色


func show_damage_number(damage: int, is_crit: bool):
	var damage_label_scene = preload("res://scenes/damage_label.tscn")
	var label = damage_label_scene.instantiate()
	label.global_position = global_position + Vector2(0, -20)  # 敌人上方
	get_tree().current_scene.add_child(label)
	label.start(str(damage), is_crit)

#死亡
func die():
	is_dead = true
	if has_node("AnimatedSprite2D"):
		$AnimatedSprite2D.play("death")
	if has_node("deathsound"):
		$deathsound.play()
	if player:
		player.on_enemy_killed()
	await get_tree().create_timer(0.6).timeout
	queue_free()


# 看得到的世界有多宽的一半（以镜头为中心）。stretch aspect 是 expand，手机横屏比 16:9 宽时这个会变大。
static func view_half_width(node: Node) -> float:
	var cam := node.get_viewport().get_camera_2d()
	var zoom := cam.zoom.x if cam else 1.0
	return node.get_viewport().get_visible_rect().size.x / 2 / zoom
