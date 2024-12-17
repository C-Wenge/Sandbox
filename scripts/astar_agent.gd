
# ================================================
# -
# -               ASTAR AGENT
# -
# -       A*的代理节点，可以动态的对A*进行更新，
# -      并且可以更改移动速度规格和瓷砖类型等信息
# -
# -   注意！如果你使用代码添加这个节点，节点的位置在添加前就应该设置，
# -     因为坐标会在进入时确定，之后在对这个节点进行移动将没有效果
# -
# -     有两个模式，Coords（坐标模式）和Shape（形状模式）
# -
# -     Coords模式：
# -       在这个模式下用户可以提供坐标进行精准的控制，
# -     比如用户提供0,0处的坐标，它会注册所在全局瓷砖坐标，
# -  如果是-1,0处的坐标，那就是所在的全局瓷砖左边偏移一个瓷砖的坐标，
# -                可以添加多个坐标
# -
# -     Shape模式：
# -             在这个模式下用户需要提供一个形状，
# -  它会自动计算所有和这个形状产生碰撞的瓷砖，让后对这些瓷砖进行注册
# -
# ================================================

@tool
class_name AStarAgent
extends Node2D

# ---------下面这些属性在运行时可以更改，它们会及时更新------->>>

## 瓷砖类型，如果是IGNORE，将不会对瓷砖类型进行注册
@export var tile_type :MapLoader.TileType :

    set(new_value):
        tile_type = new_value

        _tile_type_update = true
        _update = true

## 是否注册权重
@export var register_weight := false :

    set(new_value):
        register_weight = new_value

        _weight_update = true
        _update = true

## 注册的权重
@export var weight := 1.0 :

    set(new_value):
        weight = new_value

        _weight_update = true
        _update = true

## 是否注册移动速度规格
@export var register_move_speed_scale := false :

    set(new_value):
        register_move_speed_scale = new_value

        _move_speed_scale_update = true
        _update = true

## 注册的移动速度规格
@export var move_speed_scale := 1.0 :

    set(new_value):
        move_speed_scale = new_value

        _move_speed_scale_update = true
        _update = true

## 是否注册障碍物
@export var register_obstacle := true :

    set(new_value):
        register_obstacle = new_value

        _obstacle_update = true
        _update = true

## 注册的障碍物
@export var obstacle := true :

    set(new_value):
        obstacle = new_value

        _obstacle_update = true
        _update = true

# ----------------------------------------------------->>>

## 模式，在进入场景前设置
@export_enum("Shape","Coords") var _mode :int :

    set(new_value):
        _mode = new_value

        if _mode == 1:
            coordinates = [Vector2i.ZERO]
            
        notify_property_list_changed()

## 如果模式是Shape，就需要提供这个形状
var shape :Shape2D = null :

    set(new_value):
        shape = new_value

        if is_instance_valid(shape):
            shape.changed.connect(
                func () -> void:
                    queue_redraw()
            )
        queue_redraw()

## 如果模式是Coords，需要提供的坐标
var coordinates :Array[Vector2i] = []

var _update := false
var _tile_type_update := false
var _weight_update := false
var _move_speed_scale_update := false
var _obstacle_update := false

## 需要注册的全局瓷砖坐标数组
var _tiles := []

func _ready() -> void:

    if Engine.is_editor_hint():
        return

    _tiles.clear()

    # 模式是Shape，计算与形状产生碰撞的瓷砖
    if _mode == 0:

        var global_rect := get_global_transform() * shape.get_rect()

        var begin := Global.global_to_tile(global_rect.position)
        var end := Global.global_to_tile(global_rect.end)+Vector2i.ONE

        for x :int in range(begin.x,end.x):
            for y :int in range(begin.y,end.y):

                var rect := RectangleShape2D.new()
                rect.size = Global.map_loader._tile_set.tile_size

                var t := Transform2D(0.0,Vector2(x,y)*Vector2(Global.map_loader._tile_set.tile_size)+(Vector2(Global.map_loader._tile_set.tile_size)/2.0))
                if shape.collide(get_global_transform(),rect,t):
                    _tiles.append(Vector2i(x,y))

    # 模式是Coords
    elif _mode == 1:
        
        var global_coords := Global.global_to_tile(global_position)
        for coords :Vector2i in coordinates:
            _tiles.append(coords+global_coords)

    _update_all()

func _process(_delta: float) -> void:

    if Engine.is_editor_hint():
        return

    if _update:
        _update = false

        for global_tile_coords: Vector2i in _tiles:

            if _tile_type_update:

                if tile_type == MapLoader.TileType.IGNORE:
                    Global.map_loader.unregister_tile_type(get_instance_id(),global_tile_coords)
                else :
                    Global.map_loader.register_tile_type(get_instance_id(),global_tile_coords,tile_type)

            if _weight_update:

                if register_weight:
                    Global.map_loader.register_astar_weight(get_instance_id(),global_tile_coords,weight)
                else :
                    Global.map_loader.unregister_astar_weight(get_instance_id(),global_tile_coords)

            if _move_speed_scale_update:

                if register_move_speed_scale:
                    Global.map_loader.register_move_speed_scale(get_instance_id(),global_tile_coords,move_speed_scale)
                else :
                    Global.map_loader.unregister_move_speed_scale(get_instance_id(),global_tile_coords)

            if _obstacle_update:

                if register_obstacle:
                    Global.map_loader.register_astar_obstacle(get_instance_id(),global_tile_coords,obstacle)
                else :
                    Global.map_loader.unregister_astar_obstacle(get_instance_id(),global_tile_coords)

        _tile_type_update = false
        _weight_update = false
        _move_speed_scale_update = false
        _obstacle_update = false


func _exit_tree() -> void:

    if Engine.is_editor_hint():
        return

    # 退出时记得注销
    tile_type = MapLoader.TileType.IGNORE
    register_weight = false
    register_move_speed_scale = false
    register_obstacle = false

    _update_all()

func _update_all() -> void:

    for global_tile_coords: Vector2i in _tiles:

        if tile_type == MapLoader.TileType.IGNORE:
            Global.map_loader.unregister_tile_type(get_instance_id(),global_tile_coords)
        else :
            Global.map_loader.register_tile_type(get_instance_id(),global_tile_coords,tile_type)

        if register_weight:
            Global.map_loader.register_astar_weight(get_instance_id(),global_tile_coords,weight)
        else :
            Global.map_loader.unregister_astar_weight(get_instance_id(),global_tile_coords)

        if register_move_speed_scale:
            Global.map_loader.register_move_speed_scale(get_instance_id(),global_tile_coords,move_speed_scale)
        else :
            Global.map_loader.unregister_move_speed_scale(get_instance_id(),global_tile_coords)

        if register_obstacle:
            Global.map_loader.register_astar_obstacle(get_instance_id(),global_tile_coords,obstacle)
        else :
            Global.map_loader.unregister_astar_obstacle(get_instance_id(),global_tile_coords)

func _draw() -> void:

    # 在编辑器内运行时绘制形状
    if Engine.is_editor_hint() and _mode == 0 and is_instance_valid(shape):
        shape.draw(get_canvas_item(),Color(1,0,0,0.5))

func _get_property_list() -> Array[Dictionary]:

    if not Engine.is_editor_hint():
        return []

    if _mode == 0:
        return [
            {
                "name":"shape",
                "type":TYPE_OBJECT,
                "hint":PROPERTY_HINT_RESOURCE_TYPE,
                "hint_string":"Shape2D"
            }
        ]
    elif _mode == 1:
        return [
            {
                "name":"coordinates",
                "type":TYPE_ARRAY
            }
        ]

    return []

func _get(property: StringName) -> Variant:

    if property == "shape":
        return shape

    if property == "coordinates":
        return coordinates

    return null

func _set(property: StringName, value: Variant) -> bool:

    if property == "shape":
        shape = value
        return true

    if property == "coordinates":
        coordinates = value
        return true

    return false
