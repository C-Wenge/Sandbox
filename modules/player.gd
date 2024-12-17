
# ================================================
# -
# -                 PLAYER
# -
# -     玩家，可以移动跳跃，和对导航进行测试
# -
# ================================================

class_name Player
extends CharacterBody2D

## 按下交互键时发出的信号
signal interaction()

const GRAVITY := 800.0

@onready var _line :Line2D = $Line2D
@onready var _sprite :AnimatedSprite2D = $Body/AnimatedSprite2D
@onready var _shadow :Sprite2D = $Body/Shadow
@onready var _shader :ShaderMaterial = $Body/AnimatedSprite2D.material
@onready var _label :Label = $Body/Label

var _start_position := Vector2.ZERO

var _jump_velocity := 0.0
var _ground_height := 0.0
var _height := 0.0

var _water_depth := 0.0
var _move_speed_scale := 1.0

func _enter_tree() -> void:
	Global.player = self

func _physics_process(delta: float) -> void:

	# 发出交互
	if Input.is_action_just_pressed("interaction"):
		interaction.emit()

	_shadow.position.y = _ground_height
	_sprite.position.y = _height
	_label.position.y = -55+_height

	_ground_height = move_toward(_ground_height,_water_depth,delta*100.0)

	if (not is_equal_approx(_height,_ground_height)) or not is_zero_approx(_jump_velocity):
		_jump_velocity += GRAVITY * delta
		_height = min(_ground_height,_height+(_jump_velocity*delta))
		if is_equal_approx(_height,_ground_height):
			_jump_velocity = 0.0

	# 传递水的深度给着色器
	_shader.set_shader_parameter("water_depth",_height)

	# 跳跃
	if Input.is_action_just_pressed("jump"):
		_jump_velocity = -300.0

	# 记录当前位置
	if Input.is_action_just_pressed("start"):
		_start_position = global_position

	# 获取一条从开始位置到当前位置的路线，使用Line2D显示出来
	if Input.is_action_just_pressed("end"):

		_line.points = Global.get_astar_path(_start_position,global_position)

	# 将玩家的位置传递给地图加载器，让它加载玩家周围的地图区块
	Global.map_loader.target_position = global_position

	# 移动
	var vec := Input.get_vector("move_left","move_right","move_up","move_down")
	velocity = vec * 200.0 * _move_speed_scale
	move_and_slide()

	# 更新动画
	if velocity.is_zero_approx() and not _sprite.animation == "idle":
		_sprite.play("idle")

	if (not velocity.is_zero_approx()) and not _sprite.animation == "run":
		_sprite.play("run")

# 更新移动速度规格和水的深度，由TileDetector发出，详情请看tile_detector.gd文件
func _on_tile_detector_tile_change(_global_tile_coords:Vector2i, tile_info:Dictionary) -> void:

	if tile_info.is_empty():
		return

	_move_speed_scale = tile_info["move_speed_scale"]

	var tile_type :MapLoader.TileType = tile_info["tile_type"]

	if tile_type == MapLoader.TileType.SHALLOW_WATER:
		_water_depth = 10
		_shadow.visible = true
	elif tile_type == MapLoader.TileType.WATER:
		_water_depth = 30
		_shadow.visible = false
	else :
		_water_depth = 0
		_shadow.visible = true

## 设置交互的文本
func set_interaction_text(text: String) -> void:

	if text.is_empty():
		_label.text = ""
	else :
		_label.text = "按F%s"%text
