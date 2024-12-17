
# ================================================
# -
# -                DOOR SCENE
# -
# -        门场景，它会被添加到TileSet中，
# -     在打开门时，它会将所在的瓷砖注册为障碍物，
# -               反之则取消注册
# -
# ================================================

class_name DoorScene
extends StaticBody2D

@onready var _collision :CollisionShape2D = $CollisionShape2D
@onready var _door :Sprite2D = $Door
@onready var _shader :ShaderMaterial = $Door.material
@onready var _astar_agent :AStarAgent = $AStarAgent

@export var _open_door_height := 32.0

# 是否打开门，会更新障碍物注册状态
var _open := false :
    
    set(new_value):
        _open = new_value
        # 打开门时禁用碰撞反之启用
        _collision.disabled = _open
        # 打开门时注销障碍物，反之注册
        _astar_agent.register_obstacle = not _open

var _player :Player

func _process(delta: float) -> void:

    # 按照打开或关闭设置门精灵的高度
    _door.position.y = move_toward(_door.position.y,-_open_door_height if _open else 0.0,100.0*delta)

    # 如果玩家在附近设置交互文本
    if is_instance_valid(_player):
        _player.set_interaction_text("关闭门" if _open else "打开门")

# 交互
func _interaction() -> void:
    _open = not _open

# 玩家进入门的交互区域
func _on_body_entered(body:Node2D) -> void:

    if body is Player:
        _shader.set_shader_parameter("focus",1.0)
        _player = body
        _player.interaction.connect(_interaction)

# 玩家退出门的交互区域
func _on_body_exited(body:Node2D) -> void:

    if body is Player:
        _shader.set_shader_parameter("focus",0.0)
        _player.set_interaction_text("")
        _player.interaction.disconnect(_interaction)
        _player = null
