
# ================================================
# -
# -   	            BLOCK NODE
# -
# -     区块节点，使用区块数据生成TileMapLayer
# -
# ================================================

class_name BlockNode
extends Node2D

# 所有层的TileMapLayer
var _layers :Array[TileMapLayer] = []

## 区块数据
var block_data :BlockData
## 需要进行y排序的层
var sort_layers :Array[int]

func _ready() -> void:

	y_sort_enabled = true

	# 设置这个节点的全局位置
	global_position = Global.block_to_global(block_data.block_coords)

	_layers.resize(block_data.tile_data.size())

	# 使用区块数据生成TileMapLayer
	for layer :int in block_data.tile_data.size():

		var node := TileMapLayer.new()
		node.tile_set = Global.tile_set
		node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		node.tile_map_data = block_data.tile_data[layer]
		_layers[layer] = node

		# 禁用导航，我们不需要
		node.navigation_enabled = false

		# 如果需要y排序
		if layer in sort_layers:
			node.y_sort_enabled = true
		else :
			# 将不需要y排序的层显示在下面
			node.z_index = -1

		add_child(node)

func _process(_delta: float) -> void:

	# 更新数据
	var update_data :Array[Dictionary] = []

	# 尝试去拿区块数据的更新锁，不要强行拿，如果强行去拿，而此时锁被其它线程拿着，会造成卡顿
	if block_data.update_mutex.try_lock():

		# 不要一直占着锁，先将数据拿到，将区块数据中的更新数据置空，然后将锁丢掉在更新
		update_data = block_data.update_data
		block_data.update_data = []

		block_data.update_mutex.unlock()

	# 更新
	for dict :Dictionary in update_data:

		var tile_map :TileMapLayer = _layers[dict["layer"]]
		tile_map.set_cell(dict["coords"],dict["source_id"],dict["atlas_coords"],dict["alternative_tile"])

		# 我们还需要通知地图加载器更新瓷砖
		var global_tile_coords :Vector2i = Global.block_to_global_tile(block_data.block_coords)+dict["coords"]
		Global.map_loader.update_tile(global_tile_coords)

## 使用局部瓷砖坐标获取瓷砖数据
func get_tile_data(layer: int, coords: Vector2i) -> TileData:

	if not (coords.x >= 0 and coords.x < block_data.block_size.x and coords.y >= 0 and coords.y < block_data.block_size.y):
		push_warning("超出区块大小！")
		return null

	var tile_mpa :TileMapLayer = _layers[layer]
	return tile_mpa.get_cell_tile_data(coords)
