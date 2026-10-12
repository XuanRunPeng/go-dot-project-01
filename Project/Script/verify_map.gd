extends SceneTree
## 临时校验脚本：验证烘焙后的 Map.tscn 数据完整性

func _initialize() -> void:
	var ps: PackedScene = load("res://Project/Scence/Map.tscn")
	var map: Node2D = ps.instantiate()
	var ground: TileMapLayer = map.get_node("Ground")
	var props: TileMapLayer = map.get_node("Props")

	var rect := ground.get_used_rect()
	print("Ground 覆盖范围: ", rect, " 尺寸: ", rect.size, "（应约 938x469）")

	# 路网随机性校验：第 200 行路面起点列与间距（不应等距）
	var road_cols: Array[int] = []
	var prev := -10
	for x in 938:
		if ground.get_cell_source_id(Vector2i(x, 200)) == 0:
			if x > prev + 1:
				road_cols.append(x)
			prev = x
	var gaps: Array[int] = []
	for i in range(1, road_cols.size()):
		gaps.append(road_cols[i] - road_cols[i - 1])
	var all_same := true
	for g in gaps:
		if g != gaps[0]:
			all_same = false
			break
	print("第200行道路起点列数: ", road_cols.size(), " 间距: ", gaps, " 等距? ", all_same, "（应为 false）")
	print("边界 (0,200) source=", ground.get_cell_source_id(Vector2i(0, 200)), " atlas=", ground.get_cell_atlas_coords(Vector2i(0, 200)))

	# Props 层统计
	var lamps := 0
	var crates := 0
	var barrels := 0
	var rocks := 0
	var other := 0
	for c in props.get_used_cells():
		var src := props.get_cell_source_id(c)
		var at := props.get_cell_atlas_coords(c)
		if src == 2 and at == Vector2i(9, 9):
			lamps += 1
		elif src == 0 and at == Vector2i(9, 7):
			crates += 1
		elif src == 0 and at == Vector2i(12, 7):
			barrels += 1
		elif src == 2:
			rocks += 1
		else:
			other += 1
	print("Props: 路灯=", lamps, " 木箱=", crates, " 木桶=", barrels, " 岩石/土堆=", rocks, " 其他=", other)

	# TileSet 校验
	var ts: TileSet = ground.tile_set
	print("TileSet: tile_size=", ts.tile_size, " 源数量=", ts.get_source_count())
	var obj_src: TileSetAtlasSource = ts.get_source(2)
	print("路灯瓦片尺寸: ", obj_src.get_tile_size(Vector2i(9, 9)), "（应为 1x3）")
	quit(0)
