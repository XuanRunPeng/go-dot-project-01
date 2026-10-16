# 资源分类

## 目录

- `Project/Art/characters/`：角色 PNG 和对应导入文件。
- `Project/Tile/`：16 像素图块、木材、箱子、地面、门和物件图集。
- `Project/Audio/`：脚步、拾取、攻击、环境和界面音效。
- `Project/Scence/`：地图场景和外部 TileSet。
- `Project/Scenes/`：菜单、开场介绍和 2D 主场景。

## 2D 关键资源

- `Art/characters/player_engineer_idle_down_00.png`：当前主角待机朝下素材。
- `Tile/木材.png`：超市木头障碍。
- `Tile/木箱32x32top.png`：超市可破坏箱子。
- `Tile/dungeon_tiles.png`、`Tiles-SandstoneDungeons.png`、`Tiles-Door-packs.png`：TileMap 图集。

## 资源注意事项

像素素材应使用 Nearest 过滤、关闭 Mipmap，并使用无损压缩。新增素材放入对应分类目录，不要把运行时生成的临时节点保存为独立资源。
