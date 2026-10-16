extends SceneTree
## 一次性烘焙脚本（无头模式运行）：
## 实例化 Map.tscn -> 调用 MapGenerator.generate_map() ->
## TileSet 存为 MapTiles.tres -> 瓦片数据烘焙进 Map.tscn
## 用法：
##   godot --headless --path <项目根目录> --script res://Project/Script/bake_map.gd

const MAP_SCENE := "res://Project/Scence/Map.tscn"
const TILESET_PATH := "res://Project/Scence/MapTiles.tres"

func _initialize() -> void:
	var packed_scene: PackedScene = load(MAP_SCENE)
	if packed_scene == null:
		push_error("无法加载 " + MAP_SCENE)
		quit(1)
		return
	var map: Node2D = packed_scene.instantiate()
	# 不进树时 @onready 不会触发，手动注入节点引用
	map.ground = map.get_node("Ground")
	map.props = map.get_node("Props")
	map.generate_map()

	# 保存 TileSet 为外部资源
	var ts: TileSet = map.ground.tile_set
	var err := ResourceSaver.save(ts, TILESET_PATH)
	if err != OK:
		push_error("TileSet 保存失败: %d" % err)
		quit(1)
		return

	# 两层改为引用已保存的 .tres，保证场景内是外部资源引用而非内嵌
	var saved_ts: TileSet = load(TILESET_PATH)
	map.ground.tile_set = saved_ts
	map.props.tile_set = saved_ts

	# 把节点打包并覆盖保存场景
	var out := PackedScene.new()
	var pack_err := out.pack(map)
	if pack_err != OK:
		push_error("场景打包失败: %d" % pack_err)
		quit(1)
		return
	var save_err := ResourceSaver.save(out, MAP_SCENE)
	if save_err != OK:
		push_error("场景保存失败: %d" % save_err)
		quit(1)
		return
	print("烘焙完成：", MAP_SCENE, " + ", TILESET_PATH)
	quit(0)
