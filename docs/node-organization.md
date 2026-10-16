# 节点分类与整理

## 一、2D 主场景节点

```text
主场景2D (Node2D)
├─ 世界 (Node2D)
│  ├─ 地面层 (TileMapLayer)
│  ├─ 墙 (TileMapLayer)
│  ├─ 超市木头障碍 (Sprite2D 容器)
│  │  └─ 木头1..木头10 (Sprite2D)
│  └─ 超市可破坏箱子 (Sprite2D 容器)
│     └─ 箱子1..箱子6 (Sprite2D)
├─ 玩家 (CharacterBody2D)
│  ├─ 玩家精灵图 (AnimatedSprite2D)
│  └─ 玩家碰撞体 (CollisionShape2D)
├─ 主相机 (Camera2D)
└─ 界面 (CanvasLayer)
   ├─ 生命条 (ProgressBar)
   ├─ 体力条 (ProgressBar)
   ├─ 交互提示 (Label)
   └─ 操作提示 (Label)
```

## 二、2D 运行时节点

`主场景2D.gd` 启动时创建：

- 地面、多边形道路、房屋和普通环境障碍。
- 超市木头/箱子的静态碰撞体。
- 超市角落道具和起始地图道具。
- 近战攻击的短暂 `Line2D` 指示线。
- 箱子破坏后生成的可交互掉落物。

## 三、碰撞节点分类

| 类型 | 碰撞层 | 用途 |
|---|---:|---|
| 玩家 | 1 | 角色移动和攻击起点 |
| 敌人 | 2 | 敌人移动与玩家交互 |
| 环境/障碍 | 4 | 房屋、木头、箱子碰撞 |
| `solid_obstacle` | 4 | 不可破坏障碍，阻挡移动和攻击 |
| `destructible_obstacle` | 4 | 可破坏箱子，可被近战射线命中 |

## 四、全局和界面节点

| 类型 | 节点或自动加载 | 说明 |
|---|---|---|
| 全局状态 | `GameState` | 由 `project.godot` 自动加载，保存任务、背包、生命、体力和位置 |
| 菜单界面 | `菜单` | 新游戏、继续、设置、音量和退出 |
| 开场界面 | `开场介绍` | 剧情文字和进入游戏按钮 |
| 2D 游戏界面 | `主场景2D/界面` | 生命条、体力条、交互提示和操作提示 |
| 游戏界面 | `主场景2D/界面` | 生命条、体力条、交互提示和操作提示 |

## 五、资源节点分类

- **地图节点**：`TileMapLayer`、`TileSet`、`地面层`、`墙`、`Ground`、`Props`。
- **角色节点**：`CharacterBody2D`、`AnimatedSprite2D`。
- **碰撞节点**：`CollisionShape2D`、`StaticBody2D`。
- **交互节点**：`Area2D`、`交互高亮`、`交互提示`。
- **相机节点**：`Camera2D`。
