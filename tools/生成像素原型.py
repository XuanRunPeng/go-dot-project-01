"""生成第一批 2D 像素原型图，使用纯色网格，便于在 Aseprite 中继续编辑。"""
from pathlib import Path
import struct
import zlib

OUT = Path(__file__).resolve().parents[1] / "art" / "pixel" / "正式PNG"
OUT.mkdir(parents=True, exist_ok=True)

def image(name: str, size: int, pixels: dict[tuple[int, int], str]) -> None:
    path = OUT / f"{name}.ppm"
    with path.open("w", encoding="ascii") as file:
        file.write(f"P3\n{size} {size}\n255\n")
        for y in range(size):
            row = []
            for x in range(size):
                color = pixels.get((x, y), "0 0 0")
                row.append(color)
            file.write(" ".join(row) + "\n")

def block(size: int, color: str, x0: int, y0: int, x1: int, y1: int, pixels: dict) -> None:
    for y in range(y0, min(size, y1)):
        for x in range(x0, min(size, x1)):
            pixels[(x, y)] = color

def make_player() -> None:
    p = {}
    block(64, "0 0 0", 20, 15, 44, 49, p)
    block(64, "80 112 124", 22, 17, 42, 45, p)
    block(64, "196 214 204", 27, 19, 37, 29, p)
    block(64, "48 72 78", 17, 29, 22, 47, p)
    block(64, "48 72 78", 42, 29, 47, 47, p)
    block(64, "228 196 93", 21, 47, 29, 53, p)
    block(64, "228 196 93", 35, 47, 43, 53, p)
    image("玩家_原型", 64, p)

def make_player_detailed() -> None:
    """绘制 64×64 的细化俯视角玩家，使用多级轮廓和衣物明暗。"""
    canvas = [(0, 0, 0, 0) for _ in range(64 * 64)]
    palette = {
        "outline": (20, 27, 30, 255), "shadow": (37, 53, 58, 255),
        "coat": (65, 105, 116, 255), "coat_light": (103, 148, 154, 255),
        "coat_high": (151, 183, 177, 255), "skin": (218, 177, 142, 255),
        "skin_shadow": (174, 121, 100, 255), "hair": (48, 45, 47, 255),
        "hair_light": (83, 70, 62, 255), "pants": (43, 67, 83, 255),
        "pants_light": (68, 91, 101, 255), "boot": (190, 151, 68, 255),
        "metal": (191, 194, 176, 255), "eye": (43, 37, 35, 255),
    }

    def rect(x0: int, y0: int, x1: int, y1: int, color: str) -> None:
        rgba = palette[color]
        for yy in range(y0, y1):
            for xx in range(x0, x1):
                if 0 <= xx < 64 and 0 <= yy < 64:
                    canvas[yy * 64 + xx] = rgba

    def pixel(x: int, y: int, color: str) -> None:
        if 0 <= x < 64 and 0 <= y < 64:
            canvas[y * 64 + x] = palette[color]

    # 轮廓采用阶梯形，头部朝画面下方，适配固定俯视角。
    rect(27, 5, 37, 7, "outline")
    rect(24, 7, 40, 10, "outline")
    rect(22, 10, 42, 21, "outline")
    rect(24, 20, 40, 26, "outline")
    rect(18, 24, 46, 43, "outline")
    rect(21, 42, 43, 49, "outline")
    rect(23, 48, 30, 58, "outline")
    rect(34, 48, 42, 58, "outline")
    rect(21, 56, 31, 61, "outline")
    rect(33, 56, 44, 61, "outline")

    # 头发与面部，保留清楚的朝向和少量五官像素。
    rect(26, 8, 38, 12, "hair")
    rect(24, 11, 28, 17, "hair")
    rect(36, 11, 40, 17, "hair")
    rect(28, 10, 35, 12, "hair_light")
    rect(27, 13, 37, 21, "skin")
    rect(27, 13, 37, 15, "skin_shadow")
    rect(29, 17, 31, 19, "eye")
    rect(34, 17, 36, 19, "eye")
    pixel(30, 17, "metal")
    pixel(35, 17, "metal")
    rect(31, 21, 34, 22, "skin_shadow")

    # 左侧背包、外套肩线和胸前装备带。
    rect(15, 28, 22, 41, "shadow")
    rect(16, 29, 20, 38, "pants")
    rect(16, 39, 21, 42, "coat_light")
    rect(21, 25, 26, 42, "coat_light")
    rect(38, 25, 43, 42, "coat_light")
    rect(25, 24, 39, 44, "coat")
    rect(27, 25, 37, 29, "coat_high")
    rect(30, 27, 33, 31, "skin")
    rect(30, 30, 34, 42, "shadow")
    rect(31, 31, 33, 36, "boot")
    rect(26, 33, 29, 40, "coat_high")
    rect(36, 33, 39, 40, "coat_high")
    rect(28, 38, 30, 42, "metal")
    rect(35, 38, 37, 42, "metal")

    # 手臂、手套和腰间小包形成外轮廓层次。
    rect(19, 28, 25, 39, "coat")
    rect(39, 28, 45, 39, "coat")
    rect(18, 37, 24, 42, "coat_light")
    rect(40, 37, 46, 42, "coat_light")
    rect(18, 41, 24, 45, "skin")
    rect(40, 41, 46, 45, "skin")
    rect(18, 42, 24, 45, "skin_shadow")
    rect(40, 42, 46, 45, "skin_shadow")
    rect(22, 43, 42, 47, "shadow")
    rect(24, 44, 40, 46, "boot")
    rect(20, 32, 23, 36, "metal")
    rect(41, 32, 44, 36, "metal")

    # 裤腿以分色区分左右，靴子使用暖色作为视觉识别点。
    rect(24, 47, 31, 55, "pants")
    rect(34, 47, 41, 55, "pants")
    rect(25, 48, 28, 54, "pants_light")
    rect(35, 48, 38, 54, "pants_light")
    rect(30, 48, 34, 55, "outline")
    rect(22, 55, 31, 60, "boot")
    rect(34, 55, 44, 60, "boot")
    rect(22, 58, 31, 60, "hair_light")
    rect(35, 58, 44, 60, "hair_light")

    write_rgba_png(OUT / "玩家_细化64.png", 64, 64, canvas)

def write_rgba_png(path: Path, width: int, height: int, pixels: list[tuple[int, int, int, int]]) -> None:
    """使用标准库写出透明 RGBA PNG，保持像素边缘和透明背景。"""
    raw = bytearray()
    for y in range(height):
        raw.append(0)
        for x in range(width):
            raw.extend(pixels[y * width + x])
    def chunk(kind: bytes, data: bytes) -> bytes:
        payload = kind + data
        return struct.pack(">I", len(data)) + payload + struct.pack(">I", zlib.crc32(payload) & 0xFFFFFFFF)
    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">2I5B", width, height, 8, 6, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(bytes(raw), 9))
    png += chunk(b"IEND", b"")
    path.write_bytes(png)

def make_enemy() -> None:
    p = {}
    block(48, "0 0 0", 12, 12, 36, 36, p)
    block(48, "23 26 27", 15, 15, 33, 34, p)
    block(48, "214 90 69", 18, 20, 22, 24, p)
    block(48, "214 90 69", 26, 20, 30, 24, p)
    image("敌人_原型", 48, p)

def make_item(name: str, color: str, accent: str) -> None:
    p = {}
    block(32, "0 0 0", 7, 7, 25, 25, p)
    block(32, color, 9, 9, 23, 23, p)
    block(32, accent, 12, 12, 20, 20, p)
    image(name, 32, p)

def make_tile(name: str, base: str, detail: str) -> None:
    p = {}
    block(16, base, 0, 0, 16, 16, p)
    for x, y in [(2, 3), (11, 5), (6, 12), (13, 14)]:
        p[(x, y)] = detail
    image(name, 16, p)

def make_tileset() -> None:
    """生成可直接导入 Godot TileSet 的 8 格 16×16 基础图集。"""
    width, height = 128, 16
    palette = [
        ((86, 100, 87), (112, 126, 93)),   # 0 草地
        ((102, 88, 70), (130, 110, 83)),   # 1 泥土
        ((61, 61, 59), (91, 86, 73)),      # 2 道路
        ((115, 118, 118), (72, 76, 75)),   # 3 墙体
        ((91, 78, 66), (126, 103, 76)),    # 4 木地板
        ((42, 73, 78), (70, 111, 112)),    # 5 水面
        ((67, 67, 62), (126, 83, 63)),     # 6 废墟
        ((119, 108, 78), (151, 132, 91)),  # 7 沙地
    ]
    canvas = [(0, 0, 0, 255) for _ in range(width * height)]
    for tile_index, (base, detail) in enumerate(palette):
        x_offset = tile_index * 16
        for y in range(16):
            for x in range(16):
                color = base
                if (x + y * 3 + tile_index) % 17 == 0:
                    color = detail
                canvas[y * width + x_offset + x] = (*color, 255)
    write_rgba_png(Path(__file__).resolve().parents[1] / "art" / "tilesets" / "末日基础图集_16x16.png", width, height, canvas)

make_player()
make_player_detailed()
make_enemy()
make_item("棒球棍", "146 91 57", "228 196 93")
make_item("撬棍", "113 119 124", "196 214 204")
make_item("电池", "60 150 91", "196 214 204")
make_item("地图", "188 158 91", "80 112 124")
make_tile("地面草地", "86 100 87", "112 126 93")
make_tile("道路泥土", "102 88 70", "130 110 83")
make_tile("废墟墙体", "115 118 118", "72 76 75")
make_tile("交互高亮", "228 196 93", "255 235 145")
make_tileset()
