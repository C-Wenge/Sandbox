
# ================================================
# -
# -                 MAIN SCENE
# -
# -  主场景，会显示加载的界面，加载完成后会关闭这个界面
# -
# ================================================
 
extends Node2D

@onready var _background :ColorRect = $CanvasLayer/Background
@onready var _map_loader :MapLoader = $MapLoader
@onready var _tile_type :Label = $CanvasLayer/VBoxContainer/TileType
@onready var _layer :Label = $CanvasLayer/VBoxContainer/Layer	

func _ready() -> void:

    _background.visible = true

    # 初始区块加载完成后关闭加载界面
    _map_loader.initial_finished.connect(
        func () -> void:
            _background.visible = false
    )

    # 更新绘制的类型和层，测试用
    _map_loader.draw_change.connect(
        func (layer: int, tile_name: String) -> void:
            _tile_type.text = "当前绘制的类型：%s" % tile_name
            _layer.text = "当前绘制的层：%s" % layer
    )
