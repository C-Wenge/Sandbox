
# ================================================
# -
# -                AUTO TILE
# -
# -         自动瓷砖匹配节点（地形匹配）
# -     它会将瓷砖数据（TileData）以id的形式进行存储，
# -           方便后续快速找到这个数据
# - 
# -  目前这个节点支持3*3（带边和角）和四方向（只有边）的地形
# -
# ================================================

class_name AutoTile
extends Node

## 方向向量和对应的名称
const DIRECTIONS := {
	Vector2i.LEFT:"left",
	Vector2i.LEFT+Vector2i.DOWN:"bottom_left",
	Vector2i.DOWN:"bottom",
	Vector2i.RIGHT+Vector2i.DOWN:"bottom_right",
	Vector2i.RIGHT:"right",
	Vector2i.RIGHT+Vector2i.UP:"top_right",
	Vector2i.UP:"top",
	Vector2i.LEFT+Vector2i.UP:"top_left"
}

# 瓷砖数据，键为id，值为TileData
var _tiles := {}

## 构建这个节点
func build() -> void:

	# 循环出所有的瓷砖
	for i :int in Global.tile_set.get_source_count():

		var source_id := Global.tile_set.get_source_id(i)
		var ts :TileSetSource = Global.tile_set.get_source(source_id)

		# 只有图集瓷砖支持地形
		if ts is TileSetAtlasSource:

			var source :TileSetAtlasSource = ts

			for j :int in source.get_tiles_count():
				var atlas_coords := source.get_tile_id(j)
				for n :int in source.get_alternative_tiles_count(atlas_coords):
					var alternative := source.get_alternative_tile_id(atlas_coords,n)

					var tile_data := source.get_tile_data(atlas_coords,alternative)
					var id := _get_tile_data_id(tile_data)

					if id >= 0:

						# 将绘制信息以元数据的形式存在TileData中
						tile_data.set_meta("source_id",source_id)
						tile_data.set_meta("atlas_coords",atlas_coords)
						tile_data.set_meta("alternative",alternative)
						_tiles[id] = tile_data

# 获取瓷砖数据的id
func _get_tile_data_id(tile_data: TileData) -> int:

	if tile_data.terrain_set == -1 or tile_data.terrain == -1:
		return -1

	# 如果是3*3地形，需要获取完整八个方向的连接情况
	if Global.tile_set.get_terrain_set_mode(tile_data.terrain_set) == TileSet.TERRAIN_MODE_MATCH_CORNERS_AND_SIDES:
		return get_tile_id(tile_data.terrain_set,tile_data.terrain,
			tile_data.get_terrain_peering_bit(TileSet.CELL_NEIGHBOR_LEFT_SIDE) == tile_data.terrain,
			tile_data.get_terrain_peering_bit(TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER) == tile_data.terrain,
			tile_data.get_terrain_peering_bit(TileSet.CELL_NEIGHBOR_BOTTOM_SIDE) == tile_data.terrain,
			tile_data.get_terrain_peering_bit(TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER) == tile_data.terrain,
			tile_data.get_terrain_peering_bit(TileSet.CELL_NEIGHBOR_RIGHT_SIDE) == tile_data.terrain,
			tile_data.get_terrain_peering_bit(TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER) == tile_data.terrain,
			tile_data.get_terrain_peering_bit(TileSet.CELL_NEIGHBOR_TOP_SIDE) == tile_data.terrain,
			tile_data.get_terrain_peering_bit(TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER) == tile_data.terrain
		)

	# 四方向地形，只需要获取上下左右的连接，四个角保持未连接状态
	if Global.tile_set.get_terrain_set_mode(tile_data.terrain_set) == TileSet.TERRAIN_MODE_MATCH_SIDES:
		return get_tile_id(tile_data.terrain_set,tile_data.terrain,
			tile_data.get_terrain_peering_bit(TileSet.CELL_NEIGHBOR_LEFT_SIDE) == tile_data.terrain,false,
			tile_data.get_terrain_peering_bit(TileSet.CELL_NEIGHBOR_BOTTOM_SIDE) == tile_data.terrain,false,
			tile_data.get_terrain_peering_bit(TileSet.CELL_NEIGHBOR_RIGHT_SIDE) == tile_data.terrain,false,
			tile_data.get_terrain_peering_bit(TileSet.CELL_NEIGHBOR_TOP_SIDE) == tile_data.terrain,false
		)

	return -1

# 使用地形集和地形以及周围八个方向的连接情况获取id，顺序一定要正确否则获取到的id会不一样
func get_tile_id(terrain_set: int, terrain: int, 
	left: bool, bottom_left: bool, bottom: bool, bottom_right: bool, right: bool, top_right: bool, top: bool, top_left: bool) -> int:

	var id :int = 0 | terrain_set
	id <<= 40
	id |= terrain

	id <<= 1
	id |= int(left)

	id <<= 1
	id |= int(bottom_left)

	id <<= 1
	id |= int(bottom)

	id <<= 1
	id |= int(bottom_right)

	id <<= 1
	id |= int(right)

	id <<= 1
	id |= int(top_right)

	id <<= 1
	id |= int(top)

	id <<= 1
	id |= int(top_left)

	return id

# 标准化位，当角位为连接时，所对应的两条边也应该连接，否则这个角的连接是无效的
func _normal_bits(bits: Dictionary) -> void:

	if bits["bottom_left"]:
		bits["bottom_left"] = bits["bottom"] and bits["left"]

	if bits["bottom_right"]:
		bits["bottom_right"] = bits["bottom"] and bits["right"]

	if bits["top_right"]:
		bits["top_right"] = bits["top"] and bits["right"]

	if bits["top_left"]:
		bits["top_left"] = bits["top"] and bits["left"]

# 绘制地形，提供的参数分别是所有的区块数据，绘制的层，全局瓷砖坐标，地形集，地形，和是否把被绘制的区块数据标记被修改，同时你可以传入地形集和地形为-1来清除地形
func draw_terrain(blocks_data: Dictionary, layer: int, global_tile_coords: Vector2i, terrain_set: int, terrain: int, modifie:= false) -> void:

	# 清除地形
	if terrain_set == -1 and terrain == -1:

		# 绘制的区块坐标和局部瓷砖坐标
		var block_coords :Vector2i= Global.global_tile_to_block(global_tile_coords)
		var tile_coords :Vector2i = Global.global_tile_to_local(global_tile_coords)

		# 绘制的区块数据
		var data :BlockData = blocks_data[block_coords]
		# 使用-1来清除瓷砖
		data.set_tile(tile_coords,layer,-1,Vector2i(-1,-1),-1,modifie)

		# 更新周围的瓷砖
		for dir :Vector2i in DIRECTIONS.keys():

			var neighbor := global_tile_coords + dir

			block_coords = Global.global_tile_to_block(neighbor)
			tile_coords  = Global.global_tile_to_local(neighbor)

			if blocks_data.has(block_coords):

				var block_data :BlockData = blocks_data[block_coords]
				var terrain_data := block_data.get_terrain_data(tile_coords,layer)

				if terrain_data["terrain_set"] >= 0 and terrain_data["terrain"] >= 0:
					update(blocks_data,layer,neighbor,modifie)

		return

	# 最终绘制的瓷砖连接情况
	var bits := {
	"left":false,
	"bottom_left":false,
	"bottom":false,
	"bottom_right":false,
	"right":false,
	"top_right":false,
	"top":false,
	"top_left":false
	}

	# 需要更新的全局瓷砖坐标
	var update_array :Array[Vector2i] = []

	for dir :Vector2i in DIRECTIONS.keys():

		# 如果这是一个四方向地形，那么忽略四个角的检测
		if Global.tile_set.get_terrain_set_mode(terrain_set) == TileSet.TERRAIN_MODE_MATCH_SIDES and dir in [Vector2i(-1,-1),Vector2i(-1,1),Vector2i(1,-1),Vector2i(1,1)]:
			continue

		var neighbor := global_tile_coords + dir

		var block_coords :Vector2i= Global.global_tile_to_block(neighbor)
		var tile_coords :Vector2i = Global.global_tile_to_local(neighbor)

		if blocks_data.has(block_coords):

			var block_data :BlockData = blocks_data[block_coords]
			var terrain_data := block_data.get_terrain_data(tile_coords,layer)

			# 如果周围瓷砖的地形集和地形和我们绘制的一样，那就将这个方向连接情况设置为连接，并且这个瓷砖需要更新
			if terrain_data["terrain_set"] == terrain_set and terrain_data["terrain"] == terrain:
				bits[DIRECTIONS[dir]] = true
				update_array.append(neighbor)

	# 标准化
	_normal_bits(bits)

	# 获取这个瓷砖的id
	var id := get_tile_id(terrain_set,terrain,
		bits["left"],
		bits["bottom_left"],
		bits["bottom"],
		bits["bottom_right"],
		bits["right"],
		bits["top_right"],
		bits["top"],
		bits["top_left"])
		
	# 接下来取出这个瓷砖数据使用元数据进行设置瓷砖
	if _tiles.has(id):

		var tile_data :TileData = _tiles[id]

		var block_coords :Vector2i= Global.global_tile_to_block(global_tile_coords)
		var tile_coords :Vector2i = Global.global_tile_to_local(global_tile_coords)

		var data :BlockData = blocks_data[block_coords]

		data.set_tile(tile_coords,layer,tile_data.get_meta("source_id"),tile_data.get_meta("atlas_coords"),tile_data.get_meta("alternative"),modifie)

		# 设置完更新周围需要更新的瓷砖
		for coords :Vector2i in update_array:
			update(blocks_data,layer,coords,modifie)

	else :
		push_warning("找不到图块！%s" % bits)

# 更新瓷砖（和绘制一样，只不过不需要提供地形集和地形）
func update(blocks_data: Dictionary, layer:int, global_tile_coords: Vector2i, modifie:bool) -> void:
	
	# 所在的区块坐标和区块局部坐标
	var block_coords :Vector2i= Global.global_tile_to_block(global_tile_coords)
	var tile_coords :Vector2i = Global.global_tile_to_local(global_tile_coords)

	# 不存在不需要更新
	if not blocks_data.has(block_coords):
		return

	# 区块数据
	var block_data :BlockData = blocks_data[block_coords]

	# 取出它本身的地形集和地形
	var terrain_data := block_data.get_terrain_data(tile_coords,layer)
	var terrain_set :int = terrain_data["terrain_set"]
	var terrain :int = terrain_data["terrain"]

	if terrain_set == -1 or terrain == -1:
		return

	# 最终绘制的瓷砖连接情况
	var bits := {
	"left":false,
	"bottom_left":false,
	"bottom":false,
	"bottom_right":false,
	"right":false,
	"top_right":false,
	"top":false,
	"top_left":false
	}

	for dir :Vector2i in DIRECTIONS.keys():

		# 如果这是一个四方向地形，那么忽略四个角的检测
		if Global.tile_set.get_terrain_set_mode(terrain_set) == TileSet.TERRAIN_MODE_MATCH_SIDES and dir in [Vector2i(-1,-1),Vector2i(-1,1),Vector2i(1,-1),Vector2i(1,1)]:
			continue
		
		var neighbor := global_tile_coords + dir

		var block_coords_ :Vector2i= Global.global_tile_to_block(neighbor)
		var tile_coords_ :Vector2i = Global.global_tile_to_local(neighbor)

		if blocks_data.has(block_coords_):

			var block_data_ :BlockData = blocks_data[block_coords_]
			var terrain_data_ := block_data_.get_terrain_data(tile_coords_,layer)

			# 如果周围瓷砖的地形集和地形和当前一样，那就将这个方向连接情况设置为连接
			if terrain_set == terrain_data_["terrain_set"] and terrain == terrain_data_["terrain"]:
				bits[DIRECTIONS[dir]] = true

	# 标准化
	_normal_bits(bits)

	# 获取这个瓷砖的id
	var id := get_tile_id(terrain_set,terrain,
		bits["left"],
		bits["bottom_left"],
		bits["bottom"],
		bits["bottom_right"],
		bits["right"],
		bits["top_right"],
		bits["top"],
		bits["top_left"])
	
	# 接下来取出这个瓷砖数据使用元数据进行设置瓷砖
	if _tiles.has(id):

		var tile_data :TileData = _tiles[id]
		block_data.set_tile(tile_coords,layer,tile_data.get_meta("source_id"),tile_data.get_meta("atlas_coords"),tile_data.get_meta("alternative"),modifie)

	else :
		push_warning("找不到图块！%s" % bits)
