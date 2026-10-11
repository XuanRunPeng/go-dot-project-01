@tool
extends Node2D
## 末世废土城市 2D 俯视角地图（程序化生成）
## 地图已烘焙进 Map.tscn（Ground / Props 两个 TileMapLayer 的 tile_map_data）
## 及外部 TileSet 资源 MapTiles.tres，编辑器内直接可见，运行时零开销。
## 需要重新生成时：调整参数后在检查器点击「重新生成地图」按钮，再 Ctrl+S 保存场景。
## 完整重建（含 TileSet）可运行 bake_map.gd：
##   godot --headless --path <项目根目录> --script res://Project/Script/bake_map.gd
## 注意：bake_map.gd 中 MAP_SCENE/TILESET_PATH 常量已指向当前路径，无需改动

const TILE_SIZE := 16
const MAP_SIZE := Vector2i(15000, 7500)
const COLS := 938
const ROWS := 469

## 路网参数：每 ROAD_PERIOD 格一条 ROAD_WIDTH 格宽的道路
const ROAD_PERIOD := 56
const ROAD_WIDTH := 4

# ---- 图集来源 id ----
const SRC_DUNGEON := 0   # dungeon_tiles.png：石块/沥青/木箱
const SRC_SANDSTONE := 1 # Tiles-SandstoneDungeons.png：泥地/苔藓/砖石地面
const SRC_OBJECT := 2    # Object.png：岩石/土堆/路灯

# ---- 瓦片调色板（坐标均经图集核对）----
const DIRT_TILES: Array[Vector2i] = [
	Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 2), Vector2i(5, 2),
	Vector2i(6, 2), Vector2i(7, 2), Vector2i(2, 3), Vector2i(3, 3),
	Vector2i(4, 3), Vector2i(5, 3), Vector2i(6, 3), Vector2i(7, 3),
]
const MOSS_TILES: Array[Vector2i] = [
	Vector2i(4, 0), Vector2i(5, 0), Vector2i(4, 1), Vector2i(5, 1),
]
const PLAZA_TILES: Array[Vector2i] = [
	Vector2i(2, 0), Vector2i(3, 0), Vector2i(2, 1), Vector2i(3, 1),
]
const DIAMOND_TILES: Array[Vector2i] = [
	Vector2i(6, 0), Vector2i(7, 0), Vector2i(6, 1), Vector2i(7, 1),
]
const ROAD_TILES: Array[Vector2i] = [
	Vector2i(3, 3), Vector2i(4, 3), Vector2i(3, 4), Vector2i(4, 4),
	Vector2i(2, 3), Vector2i(5, 3), Vector2i(2, 4), Vector2i(5, 4),
]
const ROAD_DARK_TILES: Array[Vector2i] = [
	Vector2i(12, 3), Vector2i(12, 4),
]
const WALL_TILES: Array[Vector2i] = [
	Vector2i(2, 12), Vector2i(3, 12), Vector2i(4, 12), Vector2i(6, 12),
	Vector2i(7, 12), Vector2i(2, 13), Vector2i(3, 13), Vector2i(6, 13),
	Vector2i(7, 13), Vector2i(2, 16), Vector2i(3, 16), Vector2i(4, 16),
	Vector2i(6, 16), Vector2i(7, 16), Vector2i(2, 18), Vector2i(3, 18),
	Vector2i(4, 18), Vector2i(6, 17), Vector2i(7, 17), Vector2i(6, 18),
	Vector2i(7, 18), Vector2i(2, 20), Vector2i(3, 20), Vector2i(4, 20),
]
const WALL_TRIM_TILES: Array[Vector2i] = [
	Vector2i(2, 15), Vector2i(3, 15), Vector2i(4, 15),
]

# ---- 道具瓦片 ----
const PROP_CRATE := Vector2i(9, 7)     # 木箱
const PROP_CRATE_TALL := Vector2i(10, 7) # 高木柜
const PROP_BARREL := Vector2i(12, 7)   # 木桶
const PROP_PLANKS := Vector2i(9, 9)    # 废木板
const ROCK_TILES: Array[Vector2i] = [
	Vector2i(10, 9), Vector2i(11, 9), Vector2i(12, 9),
]
const MOUND_TILES: Array[Vector2i] = [
	Vector2i(10, 10), Vector2i(11, 10),
]
const LAMP_ATLAS := Vector2i(9, 9)     # 路灯，占 1x3 格
const LAMP_SIZE := Vector2i(1, 3)

@export var seed_value: int = 20261011
## 默认关闭：地图数据已烘焙进场景，运行时不再生成
@export var generate_at_runtime := false

@export_tool_button("重新生成地图", "ArrowClockwise")
var regenerate_action: Callable = generate_map

var rng := RandomNumberGenerator.new()
var wall_cells := {}  # Vector2i -> true，记录墙体格，避免路灯等道具重叠

@onready var ground: TileMapLayer = $Ground
@onready var props: TileMapLayer = $Props

func _ready() -> void:
	# 编辑器内永不自动生成（地图已烘焙），仅游戏运行且显式开启时才生成
	if generate_at_runtime and not Engine.is_editor_hint():
		generate_map()

## 生成地图：优先复用场景中已有的 TileSet（MapTiles.tres）
func generate_map() -> void:
	rng.seed = seed_value
	wall_cells.clear()
	ground.clear()
	props.clear()
	var ts: TileSet = ground.tile_set
	if ts == null:
		ts = _build_tile_set()
		ground.tile_set = ts
		props.tile_set = ts
	_generate()

# ------------------------------------------------------------------
# TileSet 构建（仅首次烘焙时使用）
# ------------------------------------------------------------------

func _build_tile_set() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
	_add_atlas(ts, SRC_DUNGEON, "res://Project/Tile/dungeon_tiles.png", {})
	_add_atlas(ts, SRC_SANDSTONE, "res://Project/Tile/Tiles-SandstoneDungeons.png", {})
	# Object.png 中路灯占 1x3 格，先排除其遮住的格子再整块创建
	_add_atlas(ts, SRC_OBJECT, "res://Project/Tile/Object.png", {
		Vector2i(9, 9): true, Vector2i(9, 10): true, Vector2i(9, 11): true,
	})
	var obj_src: TileSetAtlasSource = ts.get_source(SRC_OBJECT)
	obj_src.create_tile(LAMP_ATLAS, LAMP_SIZE)
	return ts

func _add_atlas(ts: TileSet, id: int, path: String, exclude: Dictionary) -> void:
	var tex: Texture2D = load(path)
	var src := TileSetAtlasSource.new()
	src.texture = tex
	src.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	var img := tex.get_image()
	if img.is_compressed():
		img.decompress()
	var cw := int(img.get_width() / float(TILE_SIZE))
	var ch := int(img.get_height() / float(TILE_SIZE))
	for y in ch:
		for x in cw:
			var c := Vector2i(x, y)
			if exclude.has(c):
				continue
			if _cell_has_pixels(img, x, y):
				src.create_tile(c)
	ts.add_source(src, id)

func _cell_has_pixels(img: Image, cx: int, cy: int) -> bool:
	for y in range(0, TILE_SIZE, 2):
		for x in range(0, TILE_SIZE, 2):
			if img.get_pixel(cx * TILE_SIZE + x, cy * TILE_SIZE + y).a > 0.0:
				return true
	return false

# ------------------------------------------------------------------
# 地图生成
# ------------------------------------------------------------------

func _generate() -> void:
	_paint_ground()
	_paint_border_ruins()
	_paint_city_blocks()
	_place_street_lamps()

func _in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < COLS and c.y < ROWS

func _is_road(c: Vector2i) -> bool:
	return (c.x % ROAD_PERIOD) < ROAD_WIDTH or (c.y % ROAD_PERIOD) < ROAD_WIDTH

func _is_sidewalk(c: Vector2i) -> bool:
	if _is_road(c):
		return false
	for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN,
			Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]:
		if _is_road(c + d):
			return true
	return false

func _pick(tiles: Array[Vector2i]) -> Vector2i:
	return tiles[rng.randi() % tiles.size()]

## 地面：荒地泥土 + 沥青路网 + 人行道，再随机铺苔藓/广场砖斑块
func _paint_ground() -> void:
	for y in ROWS:
		for x in COLS:
			var c := Vector2i(x, y)
			if _is_road(c):
				if rng.randf() < 0.06:
					ground.set_cell(c, SRC_DUNGEON, _pick(ROAD_DARK_TILES))
				else:
					ground.set_cell(c, SRC_DUNGEON, _pick(ROAD_TILES))
				# 路面散落废弃物
				if rng.randf() < 0.004:
					_place_road_debris(c)
			elif _is_sidewalk(c):
				ground.set_cell(c, SRC_SANDSTONE, _pick(PLAZA_TILES))
			else:
				ground.set_cell(c, SRC_SANDSTONE, _pick(DIRT_TILES))
	_paint_ground_blobs()

## 街区内随机斑块：苔藓丛生 / 碎石广场
func _paint_ground_blobs() -> void:
	var blob_count := int(COLS * ROWS / 2600.0)
	for i in blob_count:
		var center := Vector2i(rng.randi_range(4, COLS - 5), rng.randi_range(4, ROWS - 5))
		if _is_road(center):
			continue
		var radius := rng.randi_range(3, 9)
		var moss := rng.randf() < 0.55
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if dx * dx + dy * dy > radius * radius:
					continue
				var c := center + Vector2i(dx, dy)
				if not _in_bounds(c) or _is_road(c) or _is_sidewalk(c):
					continue
				if rng.randf() < 0.85:
					if moss:
						ground.set_cell(c, SRC_SANDSTONE, _pick(MOSS_TILES))
					else:
						var roll := rng.randf()
						if roll < 0.25:
							ground.set_cell(c, SRC_SANDSTONE, _pick(DIAMOND_TILES))
						else:
							ground.set_cell(c, SRC_SANDSTONE, _pick(PLAZA_TILES))
					# 斑块内偶有岩石瓦砾
					if rng.randf() < 0.02:
						props.set_cell(c, SRC_OBJECT, _pick(ROCK_TILES))

## 地图最外圈用残破石墙围挡（随机塌口）
func _paint_border_ruins() -> void:
	for x in COLS:
		for c in [Vector2i(x, 0), Vector2i(x, ROWS - 1)]:
			if rng.randf() > 0.15:
				_set_wall(c)
	for y in ROWS:
		for c in [Vector2i(0, y), Vector2i(COLS - 1, y)]:
			if rng.randf() > 0.15:
				_set_wall(c)

## 城市街区：以路网划分街区，按概率生成建筑群 / 瓦砾场 / 荒废空地
func _paint_city_blocks() -> void:
	var block_size := ROAD_PERIOD - ROAD_WIDTH
	var gy := ROAD_WIDTH
	while gy < ROWS - 2:
		var gx := ROAD_WIDTH
		while gx < COLS - 2:
			var bw := mini(block_size, COLS - 2 - gx)
			var bh := mini(block_size, ROWS - 2 - gy)
			if bw > 6 and bh > 6:
				match rng.randi_range(0, 9):
					0, 1, 2, 3, 4, 5:
						_paint_block_buildings(Rect2i(gx, gy, bw, bh))
					6, 7:
						_paint_rubble_lot(Rect2i(gx, gy, bw, bh))
					_:
						_paint_overgrown_lot(Rect2i(gx, gy, bw, bh))
			gx += ROAD_PERIOD
		gy += ROAD_PERIOD

func _paint_block_buildings(block: Rect2i) -> void:
	var placed: Array[Rect2i] = []
	var attempts := rng.randi_range(1, 2)
	for i in attempts:
		var bw := rng.randi_range(8, mini(26, block.size.x - 2))
		var bh := rng.randi_range(6, mini(16, block.size.y - 2))
		var bx := block.position.x + rng.randi_range(0, block.size.x - bw)
		var by := block.position.y + rng.randi_range(0, block.size.y - bh)
		var rect := Rect2i(bx, by, bw, bh)
		var overlaps := false
		for r in placed:
			if r.intersects(rect.grow(1)):
				overlaps = true
				break
		if overlaps:
			continue
		placed.append(rect)
		_paint_building(rect)

## 单栋废墟建筑：残缺围墙 + 随机塌口 + 门洞，内部荒废地板与杂物
func _paint_building(rect: Rect2i) -> void:
	# 门洞：随机一条边上开 2 格宽的门
	var door_side := rng.randi_range(0, 3)
	var door_pos := 0
	match door_side:
		0, 2:
			door_pos = rng.randi_range(rect.position.x + 1, rect.end.x - 3)
		1, 3:
			door_pos = rng.randi_range(rect.position.y + 1, rect.end.y - 3)
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var c := Vector2i(x, y)
			var on_edge := (x == rect.position.x or x == rect.end.x - 1
					or y == rect.position.y or y == rect.end.y - 1)
			if on_edge:
				if _is_door_cell(rect, c, door_side, door_pos):
					continue  # 门洞
				if rng.randf() < 0.10:
					continue  # 随机塌口
				_set_wall(c, y == rect.end.y - 1)
			else:
				# 建筑内部：荒废地板
				var roll := rng.randf()
				if roll < 0.10:
					ground.set_cell(c, SRC_SANDSTONE, _pick(PLAZA_TILES))
				else:
					ground.set_cell(c, SRC_SANDSTONE, _pick(DIRT_TILES))
				# 内部杂物
				var p := rng.randf()
				if p < 0.015:
					props.set_cell(c, SRC_DUNGEON, PROP_CRATE)
				elif p < 0.025:
					props.set_cell(c, SRC_DUNGEON, PROP_BARREL)
				elif p < 0.035:
					props.set_cell(c, SRC_DUNGEON, PROP_CRATE_TALL)
				elif p < 0.05:
					props.set_cell(c, SRC_DUNGEON, PROP_PLANKS)
				elif p < 0.06:
					props.set_cell(c, SRC_OBJECT, _pick(ROCK_TILES))

func _is_door_cell(rect: Rect2i, c: Vector2i, side: int, pos: int) -> bool:
	match side:
		0:
			return c.y == rect.position.y and c.x >= pos and c.x <= pos + 1
		2:
			return c.y == rect.end.y - 1 and c.x >= pos and c.x <= pos + 1
		1:
			return c.x == rect.end.x - 1 and c.y >= pos and c.y <= pos + 1
		_:
			return c.x == rect.position.x and c.y >= pos and c.y <= pos + 1

## 瓦砾场：碎石堆与废弃物
func _paint_rubble_lot(block: Rect2i) -> void:
	for y in range(block.position.y, block.end.y):
		for x in range(block.position.x, block.end.x):
			var c := Vector2i(x, y)
			var p := rng.randf()
			if p < 0.03:
				props.set_cell(c, SRC_OBJECT, _pick(ROCK_TILES))
			elif p < 0.05:
				props.set_cell(c, SRC_OBJECT, _pick(MOUND_TILES))
			elif p < 0.058:
				props.set_cell(c, SRC_DUNGEON, PROP_PLANKS)
			elif p < 0.064:
				props.set_cell(c, SRC_DUNGEON, PROP_CRATE)
			elif p < 0.068:
				props.set_cell(c, SRC_DUNGEON, PROP_BARREL)

## 荒废空地：零星杂物，基本保留苔藓/泥地
func _paint_overgrown_lot(block: Rect2i) -> void:
	for y in range(block.position.y, block.end.y):
		for x in range(block.position.x, block.end.x):
			var c := Vector2i(x, y)
			var p := rng.randf()
			if p < 0.012:
				props.set_cell(c, SRC_OBJECT, _pick(MOUND_TILES))
			elif p < 0.018:
				props.set_cell(c, SRC_OBJECT, _pick(ROCK_TILES))
			elif p < 0.021:
				props.set_cell(c, SRC_DUNGEON, PROP_PLANKS)

## 沿路网布置路灯（1x3 格道具）
func _place_street_lamps() -> void:
	var step := 14
	# 竖向道路两侧
	var rx := 0
	while rx < COLS:
		var ly := ROAD_WIDTH + 6
		while ly < ROWS - ROAD_WIDTH - 6:
			for lx in [rx + ROAD_WIDTH + 1, rx - 2]:
				var c := Vector2i(lx, ly)
				if _in_bounds(c) and not _is_road(c) and not wall_cells.has(c) \
						and rng.randf() < 0.8:
					props.set_cell(c, SRC_OBJECT, LAMP_ATLAS)
			ly += step
		rx += ROAD_PERIOD
	# 横向道路两侧
	var ry := 0
	while ry < ROWS:
		var lx := ROAD_WIDTH + 6
		while lx < COLS - ROAD_WIDTH - 6:
			for ly2 in [ry + ROAD_WIDTH + 1, ry - 2]:
				var c := Vector2i(lx, ly2)
				if _in_bounds(c) and not _is_road(c) and not wall_cells.has(c) \
						and rng.randf() < 0.8:
					props.set_cell(c, SRC_OBJECT, LAMP_ATLAS)
			lx += step
		ry += ROAD_PERIOD

## 在路面上散落废弃物
func _place_road_debris(c: Vector2i) -> void:
	var roll := rng.randi_range(0, 3)
	match roll:
		0:
			props.set_cell(c, SRC_DUNGEON, PROP_CRATE)
		1:
			props.set_cell(c, SRC_DUNGEON, PROP_BARREL)
		2:
			props.set_cell(c, SRC_DUNGEON, PROP_PLANKS)
		3:
			props.set_cell(c, SRC_OBJECT, _pick(ROCK_TILES))

## 在地面层放置一块墙体瓦片并登记
func _set_wall(c: Vector2i, use_trim := false) -> void:
	if not _in_bounds(c):
		return
	var atlas := _pick(WALL_TRIM_TILES) if use_trim and rng.randf() < 0.5 else _pick(WALL_TILES)
	ground.set_cell(c, SRC_DUNGEON, atlas)
	wall_cells[c] = true
