
# ================================================
# -
# -                TILE DETECTOR
# -
# -        对所在的瓷砖进行检测，只有需要时才会更新
# -           他不会每一帧更新，大大提高性能
# - 可以将此节点添加到需要获取所在瓷砖信息的节点下，并连接信号
# -
# ================================================

class_name TileDetector
extends Node2D

## 此节点所在的瓷砖坐标发生变化或需要更新时发出
signal tile_change(global_tile_coords: Vector2i, tile_info: Dictionary)

var _current_coords := Vector2i.ZERO
var _current_block_coords := Vector2i.ZERO
var _initialize := true

func _enter_tree() -> void:

    # 此节点所在的区块可能还没有加载，当加载时需要更新
    Global.map_loader.block_load_finished.connect(
        func (block_coords: Vector2i) -> void:
            if block_coords == _current_block_coords:
                _update()
    )
    
    # 瓷砖被修改时也需要更新
    Global.map_loader.tile_change.connect(
        func (global_tile_coords: Vector2i) -> void:
            if global_tile_coords == _current_coords:
                _update()
    )

func _process(_delta: float) -> void:

    var coords := Global.global_to_tile(global_position)
    var block_coords := Global.global_tile_to_block(coords)

    # 第一次或坐标发生变化时需要更新
    if coords != _current_coords or block_coords != _current_block_coords or _initialize:

        _initialize = false
        _current_block_coords = block_coords
        _current_coords = coords
        _update()

func _update() -> void:

    tile_change.emit(_current_coords,Global.map_loader.get_tile_info(_current_coords))

