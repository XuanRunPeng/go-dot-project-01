# 项目文档

本项目已统一为 2D 生存玩法线，3D 场景和脚本已经移除。所有文档均使用中文说明，并按系统、节点和资源分类记录。

## 文档索引

- [项目状态](project-status.md)：已完成、进行中和待办事项。
- [节点整理](node-organization.md)：场景节点树、运行时节点和碰撞层。
- [代码索引](code-index.md)：脚本职责、入口和主要调用关系。
- [资源分类](asset-catalog.md)：图片、音频、TileSet 和角色资源。

## 当前入口

项目入口由 `project.godot` 的 `run/main_scene` 指向菜单场景。2D 游戏流程为：菜单 -> 开场介绍 -> `Project/主场景2D.tscn`。

## 维护约定

1. 新增 2D 玩法放在 `Project/` 下，并使用中文文件名时同步更新本文档。
2. 场景中的静态节点放在对应父节点下，运行时生成节点由场景脚本集中创建。
3. 碰撞体通过 `obstacle_type` 元数据分类：`solid_obstacle` 或 `destructible_obstacle`。
4. 修改资源导入设置后必须 Reimport，并在提交前确认 `.import` 文件状态。
