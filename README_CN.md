# Funplay MCP for Godot

这是一个运行在 Godot 编辑器内的 MCP 插件，整体设计直接借鉴了 `funplay-unity-mcp`：

- MCP Server 内嵌在编辑器里
- 以高杠杆的 `execute_code` 为核心工具
- 通过 resources 暴露项目上下文
- 通过 `core` / `full` 两档工具面控制噪音

## 当前版本能力

这一版现在已经包含：

- 运行在 `127.0.0.1` 的内嵌 HTTP MCP Server
- Godot 编辑器右侧 Dock 面板
- `core` 与 `full` 两种工具配置
- 内置工具能力覆盖：
  - 脚本 / 代码执行
  - 场景打开 / 保存 / 新建 / 实例化
  - PackedScene 导出与检查
  - 节点查询 / 选择 / 查找 / 创建 / 复制 / 重挂载 / 删除
  - 节点属性 / 信号 / 方法反射
  - 节点属性与 Transform 修改
  - 文件读取 / 写入 / 搜索 / 复制 / 移动 / 删除
  - Script 创建 / 编辑 / 打开 / Patch
  - Script reload / error 诊断
  - Play 模式控制
  - Action / 键盘 / 鼠标输入模拟
  - 鼠标拖拽与输入序列模拟
  - 时间缩放控制
  - 最近日志读取
  - 性能快照
  - 场景复杂度分析
  - 编辑器视图截图
  - Material 创建与绑定
  - 更深入的 Godot UI / Control 构建
  - AnimationPlayer 动画片段 / 轨道工具
  - Camera2D / Camera3D 专用工具
  - addon/plugin 清单与启停
- MCP Resources：
  - `godot://project/context`
  - `godot://scene/current`
  - `godot://selection/current`
  - `godot://interaction/history`
  - `godot://logs/recent`
  - `godot://scripts/errors`
  - `godot://project/features`
  - `godot://play/state`
  - `godot://performance/snapshot`
  - `godot://scenes/list`
  - `godot://file/{path}`
- MCP Prompts：
  - `scene_review`
  - `feature_plan`
  - `runtime_debug`
  - `script_patch`
  - `ui_layout_plan`

## 快速开始

### 1. 用 Godot 4.2+ 打开仓库

仓库里已经带了最小可用的 `project.godot`，可以直接当成 Godot 项目打开。

### 2. 启用插件

进入 `Project > Project Settings > Plugins`，启用 `Funplay MCP for Godot`。

启用后，右侧会出现 `Funplay MCP` 面板。

### 3. 启动 MCP Server

在 `Funplay MCP` 面板中：

- 勾选 `Enable MCP Server`
- 使用默认 `8765` 端口，或者改成你想要的端口
- 选择 `core` 或 `full`

插件会监听 `http://127.0.0.1:<port>/`。

如果端口被占用，会自动尝试附近端口，并把最终端口保存到 `user://funplay_mcp_settings.cfg`。

### 4. 配置 AI 客户端

你可以直接用面板里的 snippet 拷贝功能，也可以点 `Configure` 直接写入配置文件。

当前已经支持一键写入：

- Codex
- Claude Code
- Cursor
- VS Code

**Codex**

```toml
[mcp_servers.funplay]
url = "http://127.0.0.1:8765/"
```

**Claude Code**

```json
{
  "mcpServers": {
    "funplay": {
      "type": "http",
      "url": "http://127.0.0.1:8765/"
    }
  }
}
```

**Cursor**

```json
{
  "mcpServers": {
    "funplay": {
      "url": "http://127.0.0.1:8765/"
    }
  }
}
```

### 5. 验证连接

建议先试这些：

- `get_project_info`
- `get_scene_tree`
- 读取 `godot://project/context`
- 调用 `execute_code`：

```gdscript
return {
	"scene_root": ctx["scene_root"].name if ctx["scene_root"] != null else "",
	"selection_count": ctx["selection"].size()
}
```

## 工具档位

### `core`

默认推荐，但已经足够覆盖高频工作流：

- `execute_code`
- 场景查看 / 打开 / 保存
- 文件读写 / 搜索
- Script 创建 / 编辑 / 打开 / Patch
- Play 状态 / 输入模拟 / 拖拽与序列输入 / 时间缩放控制
- 最近日志读取
- 性能 / 复杂度分析
- 编辑器截图
- 节点选择与查找

### `full`

在 `core` 基础上额外暴露更直接的编辑能力：

- 新建场景与实例化子场景
- 将节点子树保存成 PackedScene，并检查 PackedScene 文件
- 创建 / 复制 / 重命名 / 重挂载 / 删除节点
- 查看节点属性 / 信号 / 方法，降低误改概率
- 创建 CanvasLayer / Control / Label / Button / Panel / TextureRect / Container UI 树
- 设置控件布局、尺寸策略、文本、贴图和 Theme Override
- 连接 UI 节点信号和脚本方法
- 设置节点属性与 Transform
- 给节点绑定 Script
- 创建 / 绑定 Material
- 创建 AnimationPlayer、动画片段、动画轨道，并播放动画
- 配置 Camera2D / Camera3D 属性
- 列出和启停 addons/plugins
- 删除 / 移动 / 复制文件

## 说明

- 这是一个仅编辑器侧插件，不会进入游戏运行时。
- 当前 HTTP 传输层是本地简化版 request/response 实现。
- 代码结构和体验设计明显参考了 Unity 版本，目前已经覆盖大多数 Godot 日常编辑工作流，但还不是与 Unity 版一一完全对齐。
- `execute_code` 权限很高，只建议暴露给你信任的本地 MCP 客户端。

## 目录结构

- `addons/funplay_mcp/plugin.gd` — 插件入口
- `addons/funplay_mcp/core/funplay_mcp_server.gd` — 服务生命周期
- `addons/funplay_mcp/core/funplay_mcp_request_handler.gd` — MCP 协议请求分发
- `addons/funplay_mcp/core/funplay_tool_registry.gd` — 工具定义与 profile
- `addons/funplay_mcp/core/funplay_core_tools.gd` — Godot 编辑器工具实现
- `addons/funplay_mcp/ui/funplay_mcp_dock.gd` — 编辑器 UI

## 后续可以继续补的点

和 Unity 版本相比，目前最主要还可以继续补的是：

- 比文件日志更深入的编辑器 Console / Error 集成
- 更多 MCP 客户端的一键配置写入
