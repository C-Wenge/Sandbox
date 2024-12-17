
class_name TileDetector
extends Node2D

signal tile_change(global_tile_coords: Vector2i, tile_info: Dictionary)

var _current_coords := Vector2i.ZERO
var _current_block_coords := Vector2i.ZERO
var _initialize := true

func _enter_tree() -> void:

    Global.map_loader.block_load_finished.connect(
        func (block_coords: Vector2i) -> void:
            if block_coords == _current_block_coords:
                _update()
    )
    
    Global.map_loader.tile_change.connect(
        func (global_tile_coords: Vector2i) -> void:
            if global_tile_coords == _current_coords:
                _update()
    )

func _process(_delta: float) -> void:

    var coords := Global.global_to_tile(global_position)
    var block_coords := Global.global_tile_to_block(coords)

    if coords != _current_coords or block_coords != _current_block_coords or _initialize:

        _initialize = false
        _current_block_coords = block_coords
        _current_coords = coords
        _update()

func _update() -> void:

    tile_change.emit(_current_coords,Global.map_loader.get_tile_info(_current_coords))

