
# ================================================
# -
# -                  GLOBAL
# -
# -        全局类，它会被添加到自动加载，
# -   方便和各种功能交互，同时对各种坐标进行转换
# - 
# -     区块坐标：每个区块的坐标，由区块大小决定，
# - 比如10*10的区块大小就表示10个瓷砖宽和10个瓷砖高组成一个区块
# -
# - 瓷砖坐标：其实就是网格坐标，局部坐标就是每个区块的坐标，
# -     比如区块大小为10*10，局部坐标就是0到10，
# - 全局瓷砖坐标，全局空间中的网格坐标，比如区块大小为10*10，
# - 区块坐标为1,1，局部瓷砖坐标为5,5，那么全局瓷砖坐标为15,15
# -
# ================================================

extends Node

## 玩家
var player :Player = null

## 地图加载器
var map_loader :MapLoader = null

## 瓷砖集
var tile_set :TileSet = null

## 瓷砖大小
var tile_size :Vector2i :
    get:
        return tile_set.tile_size

## A*寻路
var astar :AStar2D = null

## 区块大小
var block_size :Vector2i

## 全局瓷砖坐标转为区块坐标
func global_tile_to_block(global: Vector2i) -> Vector2i:

    var vec := Vector2(global) / Vector2(block_size)
    return Vector2i(vec.floor())

## 全局瓷砖坐标转为局部瓷砖坐标
func global_tile_to_local(global: Vector2i) -> Vector2i:
    return Vector2i(wrapi(global.x,0,block_size.x),wrapi(global.y,0,block_size.y))

## 全局像素坐标转为瓷砖坐标
func global_to_tile(global: Vector2) -> Vector2i:

    var vec := global / Vector2(tile_size)
    return Vector2i(vec.floor())

## 全局像素坐标转为区块坐标
func global_to_block(global: Vector2) -> Vector2i:

    var size := block_size * tile_set.tile_size
    return Vector2(global/Vector2(size)).floor()

## 区块坐标转为全局瓷砖坐标
func block_to_global_tile(block_coords: Vector2i) -> Vector2i:
    return block_coords * block_size

## 区块坐标转全局像素坐标
func block_to_global(block_coords: Vector2i) -> Vector2:
    return Vector2(block_coords)*Vector2(block_size)*Vector2(tile_size)

## 获取全局位置对应的A*id，如果closest为true，并且所在的id不存在或被禁用，那就返回一个最近的id
func get_target_astar_id(global: Vector2, closest:= true) -> int:
    
    var global_tile_coords := global_to_tile(global)
    var id := get_astar_id(global_tile_coords)

    if (not astar.has_point(id)) or astar.is_point_disabled(id) and closest:
        # 获取离global最近的点对应的id，后面的false表示不考虑禁用的点
        return astar.get_closest_point(global,false)

    return id

## 获取一条导航路径，需要提供起点和终点的全局像素位置
func get_astar_path(start: Vector2, end: Vector2) -> PackedVector2Array:
    
    var from_id := get_target_astar_id(start)
    var to_id := get_target_astar_id(end)
    # 返回从from_id到to_id的路线，是一个二维向量数组，数组的每一个元素为瓷砖的全局像素中心坐标，在我们添加A*点时候提供的
    # 后面的true为当没有从from_id到to_id的路线时，它会返回离到to_id最近的路线，如果为false，并且没有路线，它会返回空的数组
    return astar.get_point_path(from_id,to_id,true)

# -------------------------------------------------------------------------------------------------------->>>

## 使用全局瓷砖坐标获取A*的点id

## 每一个瓷砖都在A*中表示一个点，
## 将这些点连接就形成了路径，
## 在A*中每添加一个点就需要一个对应的id，
## 只有使用这个id才能获取或设置点的属性，
## 计算路线也需要提供起点和终点id，所以这个id非常重要，
## 注意这个id不能是一个负数，所以生成这个id的要求是，同一个坐标生成的id必须一样，
## 不同坐标生成的id必须不一样（在A*中id不能重复），id必须是大于或等于0的整数

## 在Godot中整数二维向量的x和y都各占用32位，而整数是占用64位，
## 我们可以使用整数的前32位存储x，后32位存储y，得到的新整数用作id，
## 但这样做的前提是这个x和y不能是负数，因为要进行位运算并且id本身不能是负数，
## 所以我们可以使用wrapi方法让x和y的值在一定的范围内循环，wrapi的使用方法为wrapi(值，最小值，最大值)，
## 值会在最小和最大之间循环（包括最小值，但不包括最大值）比如像下面这样
## wrapi(0,0,2)结果为0，wrapi(1,0,2)结果为1，wrapi(2,0,2)结果为0，wrapi(-1,0,2)结果为1，小于最小值就会从最大开始循环，相反大于等于最大值就会从最小值开始循环
## 像下面这样我们让它在0到100000之间循环，
## 聪明的你可能发现，这样0,0坐标和100000,100000坐标得到的id不是一样的吗？，因为100000,100000会被循环到0,0坐标，
## 是的，0,0坐标和100000,100000坐标得到的id是一样的，但是我们每次加载的瓷砖是有限的，换句话说，当我们加载100000,100000处的瓷砖时，0,0处的瓷砖早就被卸载了，
## 所以此时100000,100000坐标的id在A*中就是唯一的！

func get_astar_id(global_tile_coords: Vector2i) -> int:

    # 将x和y控制在0到100000之间
    var coords := Vector2i(wrapi(global_tile_coords.x,0,100000),wrapi(global_tile_coords.y,0,100000))

    # 将整数的前32位存储x，后32位存储y
    var id := 0 | coords.x
    id <<= 32
    id |= coords.y

    return id

# -------------------------------------------------------------------------------------------------------->>>
