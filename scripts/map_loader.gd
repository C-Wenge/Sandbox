
# ================================================
# -
# -                MAP LOADER
# -
# -          负责对地图进行加载和卸载，
# -     用户只需要提供区块大小瓷砖集等信息即可
# -
# ================================================

class_name MapLoader
extends Node2D

## 绘制的瓷砖发生改变是发出，提供绘制的层和瓷砖名称
signal draw_change(layer: int, tile_name: String)

## 初始的区块加载完成时发出，可作为加载页面关闭的信号
signal initial_finished()

## 区块加载完成时发出，提供加载完成的区块坐标
signal block_load_finished(block_coords: Vector2i)

## 区块卸载完成时发出，提供卸载完成的区块坐标
signal block_unload_finished(block_coords: Vector2i)

## 当瓷砖发生改变时发出，比如擦除瓷砖或者绘制瓷砖，提供全局的瓷砖坐标
signal tile_change(global_tile_coords: Vector2i)

## 瓷砖类型，按照你的游戏进行设计
enum TileType{

	## 不被考虑，应该被忽略的瓷砖
	IGNORE = 0,
	## 水
	WATER = 1,
	## 浅水
	SHALLOW_WATER = 2,
	## 地面
	GROUND = 3,
	## 草地
	GRASS = 4
}

## 对应瓷砖的权重（不包括忽略的瓷砖类型），这个值越大移动到这个瓷砖的代价就越大，按照你的游戏进行设计
const ASTAR_WEIGHT := [
	2.5,
	1.8,
	1.0,
	1.2
]

## 对应瓷砖的移动速度规格（不包括忽略的瓷砖类型），权重越大这个值应该越小，按照你的游戏进行设置
const MOVE_SPEED_SCALE := [
	1.0/2.5,
	1.0/1.8,
	1.0,
	1.0/1.2
]

# 自动瓷砖的匹配节点
var _auto_tile :AutoTile

# 生物会被添加到这个节点下面
@export var _world :Node2D

# 区块的父节点，区块节点会被添加到这个节点下面
@export var _block_parent :Node2D

# 提供的瓷砖集
@export var _tile_set :TileSet

# 区块大小，10*10表示10个瓷砖宽和10个瓷砖高组成一个区块，
# 过大会导致区块加载过慢，过小会导致区块节点过多
@export var _block_size := Vector2i(10,10)

# 区块加载的范围，1表示加载目标周围一圈的区块，0表示只加载目标位置一个区块
@export var _load_range := 1

# 用来确定瓷砖类型的噪声
@export var _type_noise :FastNoiseLite

# 用来确定草地类型的噪声
@export var _grass_noise :FastNoiseLite

# 用来确定树的数量的噪声
@export var _tree_noise :FastNoiseLite

# 瓷砖层的数量
@export var _layer_count :int

# 需要进行y排序的层
@export var _sort_layers :Array[int]

# 敌人的场景
@export var _enemy_packed :PackedScene

# 当前的区块坐标
var _block_coords := Vector2i.ZERO
# 区块是否是第一次加载
var _initialize := true
# 已经加载的区块坐标
var _blocks := []
# 初始的区块坐标
var _initial_blocks := []
# 已经加载的区块节点，键是区块坐标，值是区块节点
var _block_nodes := {}

# 线程
var _thread := Thread.new()
# 线程是否退出
var _thread_exit := false
# 信号量，用来休眠或唤醒线程
var _semaphore := Semaphore.new()
# 区块数据，键是区块坐标，值是区块数据
var _blocks_data := {}
# 区块数据互拆锁
var _data_mutex := Mutex.new()

# 更新队列
var _update_queue := []
# 更新队列互拆锁
var _mutex := Mutex.new()

## 目标位置，使用这个位置进行区块加载
var target_position := Vector2.ZERO

# Godot内置的A*寻路算法
var _astar := AStar2D.new()
# 注册的瓷砖类型
var _tile_types := {}
# 注册的瓷砖权重
var _astar_weights := {}
# 注册的移动速度规格
var _move_speed_scales := {}
# 注册的障碍物
var _astar_obstacles := {}

# --- 用来演示建造的变量，在你的游戏中不需要添加 --- >>>

# 绘制索引
var _draw_index := 0
# 绘制的全局瓷砖坐标
var _draw_coords := Vector2i.ZERO
# 绘制模式，0表示不绘制，1表示绘制，2表示擦除
var _draw_mode := 0
# 绘制信息，使用绘制索引取出
var _draw_info := [
	{
		"name":"地板",
		"mode":1,
		"layer":4,
		"terrain_set":0,
		"terrain":4
	},
	{
		"name":"墙",
		"mode":1,
		"layer":5,
		"terrain_set":1,
		"terrain":1
	},
	{
		"name":"栅栏",
		"mode":1,
		"layer":5,
		"terrain_set":1,
		"terrain":0
	},
	{
		"name":"门",
		"mode":2,
		"layer":5,
		"scene_set":1,
		"scene":2
	},
	{
		"name":"地面",
		"mode":1,
		"layer":1,
		"terrain_set":0,
		"terrain":1
	}
]

func _enter_tree() -> void:

	# 将自己传递到全局
	Global.map_loader = self

func _ready() -> void:

	# 创建地图数据保存路径
	DirAccess.make_dir_recursive_absolute("user://map")

	# 打印地图数据全局路径
	print("--------------------------存档存储路径---------------------->>>")
	print(ProjectSettings.globalize_path("user://map"))
	print("---------------------------------------------------------->>>")

	# 将信息传递给全局类
	Global.tile_set = _tile_set
	Global.block_size = _block_size
	Global.astar = _astar

	# 构建自动瓷砖匹配节点，并把它添加成子节点
	_auto_tile = AutoTile.new()
	_auto_tile.build()
	add_child(_auto_tile)

	# 启动线程
	_thread.start(_thread_run)

func _exit_tree() -> void:

	# 当退出时将线程退出标记为是
	_thread_exit = true
	# 唤醒线程
	_semaphore.post()
	# 等待线程退出后释放线程
	_thread.wait_to_finish()

func _input(event: InputEvent) -> void:

	if event is InputEventMouseButton:

		# 按下左键时将绘制模式设置为1并记录鼠标的全局瓷砖坐标
		if event.button_index == MOUSE_BUTTON_LEFT:
			
			_draw_coords= Global.global_to_tile(get_global_mouse_position())

			if (_draw_mode == 0) and event.is_pressed():
				# 如果按下，绘制模式设置为1反之设置为0
				_draw_mode = 1 if event.is_pressed() else 0
				# 如果是第一次按下还需要调用一次绘制地图
				_draw_map()
				
			# 如果按下，绘制模式设置为1反之设置为0
			_draw_mode = 1 if event.is_pressed() else 0
			
		# 按下右键时将绘制模式设置为2并记录鼠标的全局瓷砖坐标
		if event.button_index == MOUSE_BUTTON_RIGHT:

			_draw_coords= Global.global_to_tile(get_global_mouse_position())

			if (_draw_mode == 0) and event.is_pressed():
				# 如果按下，绘制模式设置为2反之设置为0
				_draw_mode = 2 if event.is_pressed() else 0
				# 如果是第一次按下还需要调用一次绘制地图
				_draw_map()
			
			# 如果按下，绘制模式设置为2反之设置为0
			_draw_mode = 2 if event.is_pressed() else 0

func _process(_delta: float) -> void:

	# 当前鼠标的全局瓷砖坐标
	var cur_coords := Global.global_to_tile(get_global_mouse_position())

	# 如果鼠标当前的全局瓷砖坐标和上一次的绘制坐标不一样就更新
	if cur_coords != _draw_coords:
		_draw_coords = cur_coords

		# 绘制鼠标的全局瓷砖矩形框
		queue_redraw()

		# 如果绘制模式不是0就重新调用绘制地图
		if _draw_mode > 0:
			_draw_map()
		
	# 切换绘制的瓷砖类型
	if Input.is_action_just_pressed("draw_change"):
		_draw_index = wrapi(_draw_index+1,0,_draw_info.size()) 
		draw_change.emit(_draw_info[_draw_index]["layer"],_draw_info[_draw_index]["name"])

	# 将目标位置转为区块坐标
	var coords :Vector2i = Global.global_to_block(target_position)

	# 区块坐标发生变化或第一次加载为true那就更新区块，不要每一帧都更新坐标
	if coords != _block_coords or _initialize:
		_block_coords = coords
		_update_block()

func _draw() -> void:

	# 绘制鼠标的全局瓷砖矩形框
	var pos := _draw_coords * _tile_set.tile_size
	var rect := Rect2(pos,_tile_set.tile_size)
	draw_rect(rect,Color(0,1,0,1),false)

## 绘制地图，用于演示，在你的游戏中不用添加
func _draw_map() -> void:

	# 取出绘制信息
	var info :Dictionary = _draw_info[_draw_index]
	var mode :int = info["mode"]

	# 用不同的绘制模式调用不同的绘制方法
	match mode:
		0:
			if _draw_mode == 1:
				draw_tile(info["layer"],_draw_coords,info["source_id"],info["atlas_coords"],info["alternative_tile"])
			else :
				erase_tile(info["layer"],_draw_coords)
		1:
			if _draw_mode == 1:
				draw_terrain(info["layer"],_draw_coords,info["terrain_set"],info["terrain"])
			else :
				erase_terrain(info["layer"],_draw_coords)
		2:
			if _draw_mode == 1:
				draw_scene(info["layer"],_draw_coords,info["scene_set"],info["scene"])
			else :
				erase_scene(info["layer"],_draw_coords)

## 目标位置是否在活动区域内
func is_in_active(target: Vector2) -> bool:

	var up_left_margin := Vector2(_block_size * _tile_set.tile_size) * _load_range
	var down_right_margin := Vector2(_block_size * _tile_set.tile_size) * (_load_range+1)
	var global :Vector2= Vector2(Global.block_to_global_tile(_block_coords)) * Vector2(_tile_set.tile_size)
	var rect := Rect2()
	rect.position = global - up_left_margin
	rect.end = global + down_right_margin
	return rect.has_point(target)

## 绘制地形，区块数据会被标记为被修改，在游戏中玩家手动建造可以调用这个方法
func draw_terrain(layer: int, global_tile_coords: Vector2i, terrain_set: int, terrain: int) -> void:

	_data_mutex.lock()

	_auto_tile.draw_terrain(_blocks_data,layer,global_tile_coords,terrain_set,terrain,true)

	_data_mutex.unlock()

## 擦除地形，区块数据会被标记为被修改，在游戏中玩家破坏瓷砖可以调用这个方法
func erase_terrain(layer: int, global_tile_coords: Vector2i) -> void:

	_data_mutex.lock()

	_auto_tile.draw_terrain(_blocks_data,layer,global_tile_coords,-1,-1,true)

	_data_mutex.unlock()

## 绘制瓷砖，区块数据会被标记为被修改
func draw_tile(layer: int, global_tile_coords: Vector2i, source_id: int, atlas_coords: Vector2i, alternative_tile: int) -> void:

	var block_coords :Vector2i = Global.global_tile_to_block(global_tile_coords)
	var tile_coords :Vector2i = Global.global_tile_to_local(global_tile_coords)

	_data_mutex.lock()

	if _blocks_data.has(block_coords):
		var data :BlockData = _blocks_data[block_coords]
		data.set_tile(tile_coords,layer,source_id,atlas_coords,alternative_tile,true)

	_data_mutex.unlock()

## 擦除瓷砖，区块数据会被标记为被修改
func erase_tile(layer: int, global_tile_coords: Vector2i) -> void:

	var block_coords :Vector2i = Global.global_tile_to_block(global_tile_coords)
	var tile_coords :Vector2i = Global.global_tile_to_local(global_tile_coords)

	_data_mutex.lock()

	if _blocks_data.has(block_coords):
		var data :BlockData = _blocks_data[block_coords]
		data.set_tile(tile_coords,layer,-1,Vector2i(-1,1),-1,true)
		
	_data_mutex.unlock()

## 绘制场景，区块数据会被标记为被修改
func draw_scene(layer: int, global_tile_coords: Vector2i, scene_set: int, scene: int) -> void:

	draw_tile(layer,global_tile_coords,scene_set,Vector2i.ZERO,scene)

## 擦除场景，区块数据会被标记为被修改
func erase_scene(layer: int, global_tile_coords: Vector2i) -> void:

	erase_tile(layer,global_tile_coords)

# 更新区块，不要每一帧都调用这个方法，相反你应该在所在区块坐标发生改变时调用
func _update_block() -> void:

	# 按照当前所在区块坐标计算出的所有区块坐标
	var all_blocks :Array[Vector2i] = []
	# 需要加载的区块坐标
	var load_arr :Array[Vector2i] = []
	# 需要被卸载的区块坐标
	var unload_arr :Array[Vector2i] = []

	# 按照区块坐标和加载范围计算出左上和右下的区块坐标
	var start := _block_coords - Vector2i(_load_range,_load_range)
	var end := _block_coords + Vector2i(_load_range,_load_range) + Vector2i.ONE

	# 按照左上和右下区块坐标计算出所有的区块坐标
	for x :int in range(start.x,end.x):
		for y :int in range(start.y,end.y):

			var coords := Vector2i(x,y)
			all_blocks.append(coords)

			# 如果已加载的坐标中没有这个坐标，那这个坐标是需要加载的坐标
			if not _blocks.has(coords):
				load_arr.append(coords)

	# 需要卸载的坐标
	for coords :Vector2i in _blocks:
		if not all_blocks.has(coords):
			unload_arr.append(coords)

	# 将需要加载的坐标添加到已加载的坐标中
	for coords: Vector2i in load_arr:
		_blocks.append(coords)

	# 移除要卸载的坐标
	for coords: Vector2i in unload_arr:
		_blocks.erase(coords)

	var dict := {
		"load":load_arr,
		"unload":unload_arr
	}

	# 如果是第一次加载，那就把需要加载的区块坐标保存到初始坐标中，并将第一次加载标记为否
	if _initialize:
		_initial_blocks = load_arr.duplicate()
		_initialize = false

	# 将更新信息添加到更新队列中，这个队列会同时被主线程和子线程修改，需要互拆锁
	_mutex.lock()
	_update_queue.append(dict)
	_mutex.unlock()

	# 需要更新，唤醒线程
	_semaphore.post()

# 加载区块节点
func _block_loaded(block_data: BlockData) -> void:

	# 如果初始区块不为空，并且初始区块中存在当前区块坐标，那就移除它
	if not _initial_blocks.is_empty():

		if _initial_blocks.has(block_data.block_coords):
			_initial_blocks.erase(block_data.block_coords)

		# 如果移除后变成空的，那就发射初始完成信号
		if _initial_blocks.is_empty():
			initial_finished.emit()

	# 使用区块数据创建区块节点
	var node := BlockNode.new()
	node.block_data = block_data
	node.sort_layers = _sort_layers

	# 添加区块节点
	_block_parent.add_child(node)
	_block_nodes[block_data.block_coords] = node

	# 加载A*寻路的区块
	_load_astar_block(block_data.block_coords)

	# 通知区块加载完成
	block_load_finished.emit(block_data.block_coords)

	# 区块加载完成后生成一定数量的敌人，按照你的游戏设计
	var size := Vector2(_block_size) * Vector2(_tile_set.tile_size)
	var global := Global.block_to_global_tile(block_data.block_coords) * _tile_set.tile_size

	if randf() > 0.1:
		return

	for i :int in randi_range(0,3):

		var target :Vector2 = Vector2(global) + Vector2(randf_range(0,size.x),randf_range(0,size.y))
		var id := _astar.get_closest_point(target)

		var enemy :Enemy= _enemy_packed.instantiate()
		enemy.global_position = _astar.get_point_position(id)

		_world.add_child(enemy)

# 卸载区块节点
func _block_unloaded(block_coords: Vector2i) -> void:

	if not _block_nodes.has(block_coords):
		return
	
	# 卸载区块节点
	var node :BlockNode = _block_nodes[block_coords]
	node.queue_free()
	_block_nodes.erase(block_coords)

	# 卸载A*区块
	_unload_astar_block(block_coords)

	# 通知区块卸载完成
	block_unload_finished.emit(block_coords)

# 使用区块坐标获取区块文件名称
func _get_block_file_name(block_coords: Vector2i) -> String:
	return "block_data_%s_%s.res" % [block_coords.x,block_coords.y]

# 程序化生成区块数据
func _generate_block_data(block_coords: Vector2i, block_data: BlockData) -> void:

	# 使用噪声生成瓷砖

	_data_mutex.lock()

	_blocks_data[block_coords] = block_data

	var tiles :Array[Vector2i] = []

	for x :int in range(0,_block_size.x):
		for y :int in range(0,_block_size.y):

			var tile_coords := Vector2i(x,y)
			var global_tile_coords :Vector2i = (block_coords * _block_size) + tile_coords

			var type_value := (_type_noise.get_noise_2dv(global_tile_coords)+1.0) / 2.0
			var grass_value := (_grass_noise.get_noise_2dv(global_tile_coords)+1.0) / 2.0

			if type_value < 0.4:
				block_data.set_tile(tile_coords,0,0,Vector2i.ZERO,0)
			elif type_value >= 0.4 and type_value < 0.5:
				_auto_tile.draw_terrain(_blocks_data,0,global_tile_coords,0,0)
			if type_value >= 0.45:
				_auto_tile.draw_terrain(_blocks_data,1,global_tile_coords,0,1)

			if type_value > 0.48:

				var gen := true

				if (grass_value >= 0.1 and grass_value < 0.2) or \
					(grass_value >= 0.24 and grass_value < 0.26) or \
					(grass_value >= 0.66 and grass_value < 0.7):
						gen = false

				if gen:
					if tile_coords.x != 0 and tile_coords.y != 0 and tile_coords.x != _block_size.x-1 and tile_coords.y != _block_size.y-1:
						if tile_coords.x % 2 == 0 and tile_coords.y % 2 == 0:
							tiles.append(tile_coords)

				if grass_value < 0.55 and gen:
					_auto_tile.draw_terrain(_blocks_data,2,global_tile_coords,0,2)

					if randf() < 0.01:
						block_data.set_tile(tile_coords,5,0,Vector2i(0,8),0)

					if randf() < 0.01:
						block_data.set_scene(tile_coords,5,1,1)

					if randf() < 0.3:
						if randf() < 0.7:
							block_data.set_tile(tile_coords,5,0,Vector2i(0,6),0)
						else :
							block_data.set_tile(tile_coords,5,0,Vector2i(0,7),0)

				if grass_value >= 0.45 and gen:
					_auto_tile.draw_terrain(_blocks_data,3,global_tile_coords,0,3)

					if randf() < 0.01:
						block_data.set_tile(tile_coords,5,0,Vector2i(0,8),0)

					if randf() < 0.01:
						block_data.set_scene(tile_coords,5,1,1)

					if randf() < 0.3:
						if randf() < 0.7:
							block_data.set_tile(tile_coords,5,0,Vector2i(12,6),0)
						else :
							block_data.set_tile(tile_coords,5,0,Vector2i(12,7),0)

	_data_mutex.unlock()

	var center := Global.block_to_global_tile(block_coords) + Vector2i(_block_size/2.0)
	var value := (_tree_noise.get_noise_2dv(center)+1.0)/2.0
	var count := randi_range(0,int(6.0*value))

	var index := 0
	while index < count and not tiles.is_empty():
		
		var i := randi() % tiles.size()
		var tile_coords := Global.global_tile_to_local(tiles[i])
		tiles.remove_at(i)

		var global_tile_coords := Global.block_to_global_tile(block_coords)+tile_coords
		var type_value := (_type_noise.get_noise_2dv(global_tile_coords)+1.0) / 2.0

		if type_value >= 0.5:
			if randf() < 0.5:
				block_data.set_tile(tile_coords,5,3,Vector2i.ZERO,0)
			else :
				block_data.set_tile(tile_coords,5,3,Vector2i.ZERO,1)

		index += 1

# 子线程的运行方法
func _thread_run() -> void:

	# 死循环
	while true:

		# 休眠线程
		_semaphore.wait()

		# 如果退出线程被标记为true
		if _thread_exit:

			# 将已被修改的区块数据保存
			_data_mutex.lock()

			for block_coords :Vector2i in _blocks_data.keys():
				var data :BlockData = _blocks_data[block_coords]
				if data.modifie_data:
					ResourceSaver.save(data,"user://map/%s"%_get_block_file_name(block_coords))

			_data_mutex.unlock()

			# 退出循环
			break

		# 取出更新信息
		_mutex.lock()
		var dict :Dictionary = _update_queue[0]
		_update_queue.remove_at(0)
		_mutex.unlock()

		# 需要加载和卸载的区块坐标
		var load_blocks :Array[Vector2i] = dict["load"]
		var unload_blocks :Array[Vector2i] = dict["unload"]

		# 加载区块
		for block_coords :Vector2i in load_blocks:

			# 区块数据
			var block_data :BlockData

			# 如果这个区块数据文件存在，那就加载
			if ResourceLoader.exists("user://map/%s"%_get_block_file_name(block_coords)):

				block_data = load("user://map/%s"%_get_block_file_name(block_coords))
				_data_mutex.lock()
				_blocks_data[block_coords] = block_data
				_data_mutex.unlock()

				# 更新这个区块数据周围的区块数据，让它们与这个区块数据相连
				for x :int in range(-1,_block_size.x+1):
					for y :int in [-1,_block_size.y]:

						var global_tile_coords :Vector2i = block_coords * _block_size + Vector2i(x,y)
						for layer :int in _layer_count:
							_auto_tile.update(_blocks_data,layer,global_tile_coords,false)

				# 更新这个区块数据周围的区块数据，让它们与这个区块数据相连
				for x :int in [-1,_block_size.x]:
					for y :int in range(-1,_block_size.y+1):

						var global_tile_coords :Vector2i = block_coords * _block_size + Vector2i(x,y)
						for layer :int in _layer_count:
							_auto_tile.update(_blocks_data,layer,global_tile_coords,false)
			else :

				# 如果文件不存在，那就程序化生成区块数据
				block_data = BlockData.new()
				block_data.block_coords = block_coords
				block_data.block_size = _block_size
				block_data.build(_layer_count)

				_generate_block_data(block_coords,block_data)

			# 将区块数据标记为需要更新
			block_data.need_update = true
			# 由主线程调用_block_loaded，并将区块数据传递出去生成区块节点
			call_deferred("_block_loaded",block_data)

		# 卸载区块
		for block_coords :Vector2i in unload_blocks:

			var data :BlockData = _blocks_data[block_coords]

			# 如果区块数据被标记为被修改，那就保存区块数据
			if data.modifie_data:
				ResourceSaver.save(data,"user://map/%s"%_get_block_file_name(block_coords))

			_blocks_data.erase(block_coords)
			# 由主线程调用_block_unloaded，将区块坐标传递出去卸载区块节点
			call_deferred("_block_unloaded",block_coords)

## 注册A*权重信息，查看astar_agent.gd了解使用方法
func register_astar_weight(id: int, global_tile_coords: Vector2i, weight: float) -> void:

	if not _astar_weights.has(global_tile_coords):
		_astar_weights[global_tile_coords] = {id:weight}
	else :
		_astar_weights[global_tile_coords][id] = weight

	# 更新A*
	update_astar(global_tile_coords)

## 注销A*权重信息，查看astar_agent.gd了解使用方法
func unregister_astar_weight(id: int, global_tile_coords: Vector2i) -> void:

	if _astar_weights.has(global_tile_coords):
		_astar_weights[global_tile_coords].erase(id)

		if _astar_weights[global_tile_coords].is_empty():
			_astar_weights.erase(global_tile_coords)

		# 更新A*
		update_astar(global_tile_coords)

## 注册A*障碍物，查看astar_agent.gd了解使用方法
func register_astar_obstacle(id: int, global_tile_coords: Vector2i, obstacle: bool) -> void:

	if not _astar_obstacles.has(global_tile_coords):
		_astar_obstacles[global_tile_coords] = {id:obstacle}
	else :
		_astar_obstacles[global_tile_coords][id]=obstacle

	# 更新A*
	update_astar(global_tile_coords)

## 注销A*障碍物，查看astar_agent.gd了解使用方法
func unregister_astar_obstacle(id: int, global_tile_coords: Vector2i) -> void:

	if _astar_obstacles.has(global_tile_coords):
		_astar_obstacles[global_tile_coords].erase(id)

		if _astar_obstacles[global_tile_coords].is_empty():
			_astar_obstacles.erase(global_tile_coords)

		# 更新A*
		update_astar(global_tile_coords)

## 注册的瓷砖类型，查看astar_agent.gd了解使用方法
func register_tile_type(id: int, global_tile_coords: Vector2i, tile_type: TileType) -> void:

	if not _tile_types.has(global_tile_coords):
		_tile_types[global_tile_coords] = {id:tile_type}
	else :
		_tile_types[global_tile_coords][id]=tile_type

	# 更新A*
	update_astar(global_tile_coords)

## 注销瓷砖类型，查看astar_agent.gd了解使用方法
func unregister_tile_type(id: int, global_tile_coords: Vector2i) -> void:

	if _tile_types.has(global_tile_coords):
		_tile_types[global_tile_coords].erase(id)

		if _tile_types[global_tile_coords].is_empty():
			_tile_types.erase(global_tile_coords)

		# 更新A*
		update_astar(global_tile_coords)

## 注册移动速度规格，查看astar_agent.gd了解使用方法
func register_move_speed_scale(id: int, global_tile_coords: Vector2i, move_speed_scale: float) -> void:

	if not _move_speed_scales.has(global_tile_coords):
		_move_speed_scales[global_tile_coords] = {id:move_speed_scale}
	else :
		_move_speed_scales[global_tile_coords][id] = move_speed_scale


	update_astar(global_tile_coords)

## 注销移动速度规格，查看astar_agent.gd了解使用方法
func unregister_move_speed_scale(id: int, global_tile_coords: Vector2i) -> void:

	if _move_speed_scales.has(global_tile_coords):
		_move_speed_scales[global_tile_coords].erase(id)

		if _move_speed_scales[global_tile_coords].is_empty():
			_move_speed_scales.erase(global_tile_coords)

		update_astar(global_tile_coords)

## 使用全局瓷砖坐标获取瓷砖信息
func get_tile_info(global_tile_coords: Vector2i) -> Dictionary:

	# 所在区块坐标
	var block_coords := Global.global_tile_to_block(global_tile_coords)
	# 所在的局部瓷砖坐标
	var tile_coords : = Global.global_tile_to_local(global_tile_coords)

	# 如果没有返回空
	if not _block_nodes.has(block_coords):
		return {}

	var info := {}

	# 如果有的话优先使用已注册的信息
	if _astar_weights.has(global_tile_coords):
		info["astar_weight"] = _astar_weights[global_tile_coords].values()[-1]

	if _astar_obstacles.has(global_tile_coords):
		info["obstacle"] = _astar_obstacles[global_tile_coords].values()[-1]

	if _tile_types.has(global_tile_coords):
		info["tile_type"] = _tile_types[global_tile_coords].values()[-1]

	if _move_speed_scales.has(global_tile_coords):
		info["move_speed_scale"] = _move_speed_scales[global_tile_coords].values()[-1]

	# 如果有瓷砖类型，但没有权重，那就使用瓷砖类型获取权重
	if (not info.has("astar_weight")) and info.has("tile_type"):
		info["astar_weight"] = ASTAR_WEIGHT[info["tile_type"]-1]

	# 如果有瓷砖类型，但没有移动速度规格，那就使用瓷砖类型获取移动速度规格
	if (not info.has("move_speed_scale")) and info.has("tile_type"):
		info["move_speed_scale"] = MOVE_SPEED_SCALE[info["tile_type"]-1]

	# 如果所有数据已获得直接返回
	if info.has("astar_weight") and info.has("obstacle") and info.has("tile_type") and info.has("move_speed_scale"):
		return info

	# 获取区块节点
	var block_node :BlockNode = _block_nodes[block_coords]

	# 从顶层往下获取
	for layer :int in range(_layer_count-1,-1,-1):

		# 瓷砖数据
		var tile_data :TileData = block_node.get_tile_data(layer,tile_coords)
		
		# 如果是空，那就直接进入下一个层
		if not is_instance_valid(tile_data):
			continue

		# 从瓷砖数据中获取瓷砖类型，详情请看TileSet的自定义数据
		var tile_type :TileType = tile_data.get_custom_data("tile_type")

		# 如果信息中没有障碍物信息（没有注册障碍物信息，如果注册了那就以注册信息为准）并且这个瓷砖被标记为是障碍物，那就添加障碍物为true
		if (not info.has("obstacle")) and tile_data.get_custom_data("obstacle"):
			info["obstacle"] = true

		# 如果瓷砖类型为忽略，那就直接进入下一层
		if tile_type == TileType.IGNORE:
			continue

		# 如果没有权重信息（没有注册权重信息，如果注册了那就以注册信息为准）使用瓷砖类型获取权重
		if not info.has("astar_weight"):
			info["astar_weight"] = ASTAR_WEIGHT[tile_type-1]

			# # 如果所有数据已获得直接返回
			# if info.has("astar_weight") and info.has("obstacle") and info.has("tile_type") and info.has("move_speed_scale"):
			# 	return info

		# 如果没有瓷砖类型信息那就设置
		if not info.has("tile_type"):
			info["tile_type"] = tile_type

		# 如果没有移动速度规格，那就使用瓷砖类型获取移动速度规格
		if not info.has("move_speed_scale"):
			info["move_speed_scale"] = MOVE_SPEED_SCALE[tile_type-1]

		# 所有其它信息已经准备好了，但还没有障碍物信息，那就设置为不是障碍物
		if not info.has("obstacle"):
			info["obstacle"]=false

		return info

	push_warning("没有找到图块！")

	return {}

## 更新指定全局瓷砖坐标的A*
func update_astar(global_tile_coords: Vector2i) -> void:

	var id := Global.get_astar_id(global_tile_coords)

	# 如果没有这个点，那就不需要更新
	if not _astar.has_point(id):
		return

	# 获取此处的瓷砖信息
	var info := get_tile_info(global_tile_coords)

	# 如果信息为空，那就不更新
	if info.is_empty():
		return

	# 更新权重信息
	_astar.set_point_weight_scale(id,info["astar_weight"])
	# 更新障碍物信息
	_astar.set_point_disabled(id,info["obstacle"])


# 加载A*区块	
func _load_astar_block(block_coords: Vector2i) -> void:

	# 循环出这个区块的局部瓷砖坐标
	for x :int in _block_size.x:
		for y :int in _block_size.y:

			# 转为全局瓷砖坐标
			var global_tile_coords := block_coords * _block_size + Vector2i(x,y)
			# 获取全局瓷砖信息
			var tile_info := get_tile_info(global_tile_coords)
			
			if tile_info.is_empty():
				continue

			# 获取这个全局瓷砖坐标对应的id
			var id := Global.get_astar_id(global_tile_coords)

			# 计算瓷砖的中心全局像素坐标，寻路是会将这些点连成路线，所以应该是中心位置
			var center_position := Vector2(global_tile_coords * _tile_set.tile_size) + (Vector2(_tile_set.tile_size)/2.0)

			# 添加点
			_astar.add_point(id,center_position,tile_info["astar_weight"])
			# 按照障碍物确定是否禁用点，被禁用的点不会参与寻路（换句话说就是不可行走）
			_astar.set_point_disabled(id,tile_info["obstacle"])

			# 与周围的四个邻居点建立连接，你可以与周围的八个点建立连接，但需要注意一些事项
			for dir :Vector2i in [Vector2i.LEFT,Vector2i.DOWN,Vector2i.RIGHT,Vector2i.UP]:

				var neighbor := global_tile_coords + dir
				var neighbor_id := Global.get_astar_id(neighbor)

				# 如果这个点存在并且没有连接，那就连接
				if _astar.has_point(neighbor_id) and not _astar.are_points_connected(id,neighbor_id):
					_astar.connect_points(id,neighbor_id)

# 卸载A*区块
func _unload_astar_block(block_coords: Vector2i) -> void:

	# 循环出这个区块的局部瓷砖坐标
	for x :int in _block_size.x:
		for y :int in _block_size.y:

			# 转为全局瓷砖坐标
			var global_tile_coords := block_coords * _block_size + Vector2i(x,y)
			# 获取这个全局瓷砖坐标对应的id
			var id := Global.get_astar_id(global_tile_coords)

			# 如果点存在那就移除点
			if _astar.has_point(id):
				_astar.remove_point(id)

## 更新指定全局瓷砖坐标的瓷砖瓷砖
func update_tile(global_tile_coords: Vector2i) -> void:

	update_astar(global_tile_coords)
	tile_change.emit(global_tile_coords)
