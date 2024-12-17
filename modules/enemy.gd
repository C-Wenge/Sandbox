
# ================================================
# -
# -                 ENEMY
# -
# -     敌人，虽然叫敌人，但并不会攻击玩家，
# -        在离玩家足够近时会跟随玩家，
# -            反之会随机游荡，
# -        如果超出活动的区域会被卸载
# -
# ================================================

class_name Enemy
extends CharacterBody2D

@onready var _sprite :AnimatedSprite2D = $Body/AnimatedSprite2D
@onready var _shadow :Sprite2D = $Body/Shadow
@onready var _shader :ShaderMaterial = $Body/AnimatedSprite2D.material

# 游荡半径
@export var _patrol_radius := 200.0
# 跟随距离
@export var _track_distance := 200.0

var _jump_velocity := 0.0
var _ground_height := 0.0
var _height := 0.0

var _water_depth := 0.0
var _move_speed_scale := 1.0

# 出生位置（如果离玩家足够远，它会在出生位置附近随机游荡）
var _birth_position := Vector2.ZERO
var _path := PackedVector2Array()

# 获取路线的时间，不要每一帧都去获取路径，相反你应该在一个随机的时间获取，
# 这样当你有很多的敌人（或着类似需要获取路线的节点）时，由于它们的获取时间是随机的，
# 在同一帧只有少量的节点在获取路线，大大增加性能
var _time := 0.0

func _ready() -> void:

    _birth_position = global_position

func _process(delta: float) -> void:

    # 如果没有在活动区域内，就卸载
    if not Global.map_loader.is_in_active(global_position):
        queue_free()

    # 更新时间
    if _time > 0.0:
        _time -= delta

func _physics_process(delta: float) -> void:

    _shadow.position.y = _ground_height
    _sprite.position.y = _height

    _ground_height = move_toward(_ground_height,_water_depth,delta*100.0)

    if (not is_equal_approx(_height,_ground_height)) or not is_zero_approx(_jump_velocity):
        _jump_velocity += Player.GRAVITY * delta
        _height = min(_ground_height,_height+(_jump_velocity*delta))
        if is_equal_approx(_height,_ground_height):
            _jump_velocity = 0.0

    # 传递水的深度给着色器
    _shader.set_shader_parameter("water_depth",_height*_sprite.scale.y)

    # 如果离玩家足够近就跟随玩家
    if global_position.distance_to(Global.player.global_position) < _track_distance:
        _track_player()
    else :
        # 反之随机游荡
        _patrol()

    # 更新动画
    if velocity.is_zero_approx() and not _sprite.animation == "idle":
        _sprite.play("idle")

    if (not velocity.is_zero_approx()) and not _sprite.animation == "run":
        _sprite.play("run")

func _track_player() -> void:

    if global_position.distance_to(Global.player.global_position) < 20.0:
        velocity = Vector2.ZERO
        return

    # 如果时间小于或等于0那就获取一个随机的时间，并且更新路线
    if _time <= 0.0:
        _path = Global.get_astar_path(global_position,Global.player.global_position)

        # 如果路线不为空，并且路线的第一个位置和当前位置处于同一个瓷砖，那就移除第一个点，否则可能会有时不时往回走的Bug
        if not _path.is_empty():
            var coords_a := Global.global_to_tile(_path[0])
            var coords_b := Global.global_to_tile(global_position)
            if coords_a == coords_b:
                _path.remove_at(0)

        _time = randf()*0.3

    if _path.is_empty():
        velocity = Vector2.ZERO
        return

    var dir := global_position.direction_to(_path[0])
    velocity = dir * 80 * _move_speed_scale
    move_and_slide()

    if global_position.distance_to(_path[0]) < 8.0:
        _path.remove_at(0)

func _patrol() -> void:

    # 获取游荡路线不需要更新，获取一次就可以了
    if _path.is_empty():

        var target := _birth_position + Vector2(randf_range(-_patrol_radius,_patrol_radius),randf_range(-_patrol_radius,_patrol_radius))
        _path = Global.get_astar_path(global_position,target)

    if _path.is_empty():
        velocity = Vector2.ZERO
        return

    var dir := global_position.direction_to(_path[0])
    velocity = dir * 80 * _move_speed_scale
    move_and_slide()

    if global_position.distance_to(_path[0]) < 8.0:
        _path.remove_at(0)

# 更新移动速度规格和水的深度，由TileDetector发出，详情请看tile_detector.gd文件
func _on_tile_change(_global_tile_coords:Vector2i, tile_info:Dictionary) -> void:

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
