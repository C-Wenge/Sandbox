
# ================================================
# -
# -                BLOCK DATA
# -
# -  区块数据，区块节点会使用这个类来生成TileMapLayer
# -
# ================================================

class_name BlockData
extends Resource

## TileMapLayer使用的数据，每一个代表一个层
@export var tile_data :Array[PackedByteArray] = []
## 区块大小
@export var block_size := Vector2i.ZERO
## 这个区块数据所在的区块坐标
@export var block_coords := Vector2i.ZERO

## 是否需要更新，一旦将区块数据传递给区块节点，之后对区块数据的修改区块节点都不会更新，
## 因为对整个数据的更新代价是很大的，所以只会更新一次，一旦程序化完成，就会将这个设置为true
@export var need_update := false

## 这个区块数据是否被修改，玩家的建造和破坏都会将它设置为true，MapLoader会使用这个变量来判断是否保存
@export var modifie_data := false

## 更新的数据，一旦将need_update设置为true，后续对数据的修改都会存储在这个里面，区块节点会使用它来更新，而不是更新所有的数据
var update_data :Array[Dictionary] = []
## 更新数据的互拆锁，因为他会被多个线程同时修改
var update_mutex := Mutex.new()

## 构建区块数据，提供层的数量
func build(layer_count: int) -> void:

    tile_data.clear()
    tile_data.resize(layer_count)

    for layer :int in layer_count:

        var data := PackedByteArray()
        # 每一个瓷砖将使用12个字节存储，还需要额外的2个字节来存储版本相关的数据
        data.resize(block_size.x*block_size.y*12+2)
        # 将它们填充为-1
        data.fill(-1)
        # 版本相关存储在开头的两个字节中，4.3中它被设置为0
        data.encode_s16(0,0)
        tile_data[layer] = data

## 使用局部瓷砖坐标设置瓷砖
func set_tile(coords: Vector2i, layer: int, source_id: int, atlas_coords: Vector2i, alternative_tile: int, modifie:= false) -> void:

    # 对局部坐标进行检测
    if not (coords.x >= 0 and coords.x < block_size.x and coords.y >= 0 and coords.y < block_size.y):
        push_warning("超出区块大小！")
        return

    # 偏移两个字节（它们被用来存储版本）
    var index := 2
    # 按照坐标计算数据开始位置
    index += (coords.y*block_size.x+coords.x) * 12

    # 使用层取出数据并设置瓷砖
    var data :PackedByteArray = tile_data[layer]
    data.encode_s16(index,coords.x)
    data.encode_s16(index+2,coords.y)

    data.encode_s16(index+4,source_id)

    data.encode_s16(index+6,atlas_coords.x)
    data.encode_s16(index+8,atlas_coords.y)

    data.encode_s16(index+10,alternative_tile)

    # 标记为被修改
    if modifie and not modifie_data:
        modifie_data = true

    # 如果需要更新
    if need_update:
        update_mutex.lock()
        update_data.append({
            "coords":coords,
            "layer":layer,
            "source_id":source_id,
            "atlas_coords":atlas_coords,
            "alternative_tile":alternative_tile
        })
        update_mutex.unlock()

## 使用局部瓷砖坐标获取瓷砖信息，以字典的形式返回
func get_tile(coords: Vector2i, layer: int) -> Dictionary:

    # 对局部坐标进行检测
    if not (coords.x >= 0 and coords.x < block_size.x and coords.y >= 0 and coords.y < block_size.y):
        push_warning("超出区块大小！")
        return {}

    # 偏移两个字节（它们被用来存储版本）
    var index := 2
     # 按照坐标计算数据开始位置
    index += (coords.y*block_size.x+coords.x) * 12

    # 使用层取出数据
    var data :PackedByteArray = tile_data[layer]

    # 返回信息
    return {
        "source_id":data.decode_s16(index+4),
        "atlas_coords":Vector2i(data.decode_s16(index+6),data.decode_s16(index+8)),
        "alternative_tile":data.decode_s16(index+10)
    }

## 使用局部瓷砖坐标设置场景
func set_scene(coords: Vector2i, layer: int, scene_set: int, scene: int, modifie:= false) -> void:

    # 对局部坐标进行检测
    if not (coords.x >= 0 and coords.x < block_size.x and coords.y >= 0 and coords.y < block_size.y):
        push_warning("超出区块大小！")
        return

    # 偏移两个字节（它们被用来存储版本）
    var index := 2
     # 按照坐标计算数据开始位置
    index += (coords.y*block_size.x+coords.x) * 12

    # 使用层取出数据并设置场景
    var data :PackedByteArray = tile_data[layer]
    data.encode_s16(index,coords.x)
    data.encode_s16(index+2,coords.y)
    data.encode_s16(index+4,scene_set)
    data.encode_s16(index+6,0)
    data.encode_s16(index+8,0)
    data.encode_s16(index+10,scene)

    # 标记为被修改
    if modifie and not modifie_data:
        modifie_data = true

    # 如果需要更新
    if need_update:
        update_mutex.lock()
        update_data.append({
            "coords":coords,
            "layer":layer,
            "source_id":scene_set,
            "atlas_coords":Vector2i.ZERO,
            "alternative_tile":scene
        })
        update_mutex.unlock()

## 使用局部瓷砖坐标获取地形信息
func get_terrain_data(coords: Vector2i, layer: int) -> Dictionary:

    # 对局部坐标进行检测
    if not (coords.x >= 0 and coords.x < block_size.x and coords.y >= 0 and coords.y < block_size.y):
        push_warning("超出区块大小！")
        return {
        "terrain_set":-1,
        "terrain":-1
    }

    # 获取瓷砖信息
    var dict := get_tile(coords,layer)

    # 使用瓷砖信息从TileSet中获取地形信息
    if Global.tile_set.has_source(dict["source_id"]) and Global.tile_set.get_source(dict["source_id"]) is TileSetAtlasSource:
        var source :TileSetAtlasSource = Global.tile_set.get_source(dict["source_id"])
        var tile_data_ :TileData = source.get_tile_data(dict["atlas_coords"],dict["alternative_tile"])
        return {
            "terrain_set":tile_data_.terrain_set,
            "terrain":tile_data_.terrain
        }
    else:
        return {
            "terrain_set":-1,
            "terrain":-1 
        }
