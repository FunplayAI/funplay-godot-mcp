<p align="center">
  <h1 align="center">Funplay MCP for Godot</h1>
  <p align="center">
    <strong>The Most Advanced MCP Server for Godot Editor</strong>
  </p>
  <p align="center">
    <a href="#"><img src="https://img.shields.io/badge/Godot-4.2%2B-blue?logo=godotengine" alt="Godot 4.2+"></a>
    <a href="#"><img src="https://img.shields.io/badge/License-MIT-blue.svg" alt="License: MIT"></a>
    <a href="#"><img src="https://img.shields.io/badge/MCP-Compatible-green" alt="MCP Compatible"></a>
    <a href="#"><img src="https://img.shields.io/badge/Platform-Editor%20Only-orange" alt="Editor Only"></a>
  </p>
  <p align="center">
    中文 | <a href="./README.md">English</a>
  </p>
  <p align="center">
    <img src="./icon.svg" alt="Funplay MCP for Godot" width="128">
  </p>
</p>

> 💖 如果这个项目对你有帮助，欢迎顺手点一个 Star。它能帮助更多 Godot 开发者发现这个项目，也能支持后续持续维护。

---

Funplay MCP for Godot 是一个采用 MIT 协议的 Godot 编辑器 MCP 服务器，让 Claude Code、Cursor、Windsurf、Codex、VS Code Copilot 等 AI 助手直接操作正在运行的 Godot 项目。

一句话描述你的游戏或工具 —— AI 助手就能通过 Funplay MCP for Godot 的内置工具完成场景创建、脚本生成、UI 搭建、运行态验证、输入模拟、动画设置、相机控制、性能检查和编辑器自动化。

> *"做一个带血条、弹药显示、暂停菜单和受击闪屏的俯视角射击游戏 HUD"*
>
> AI 助手通过 Funplay MCP for Godot 全程处理：创建场景结构、生成脚本、搭建 Control 树、连接信号、配置动画并验证流程 —— 只需一句话。

## 快速开始

如果你只想尽快跑起来，先做这三步：

- 打开本项目，或者把 `addons/funplay_mcp` 拷贝到你自己的 Godot 项目里
- 启用插件并启动 MCP Server
- 使用内置的一键客户端配置

### 1. 安装插件

你可以：

- 直接 clone 本仓库并作为 Godot 项目打开，或者
- 把 `addons/funplay_mcp` 拷贝到你自己的 Godot `res://addons/` 目录

> 💡 在 clone 或安装之前，如果你愿意顺手点一个 ⭐，会非常感谢。

### 2. 启用并启动 MCP Server

在 Godot 中：

- 打开 **Project → Project Settings → Plugins**
- 启用 **Funplay MCP for Godot**
- 使用右侧的 **Funplay MCP** Dock

默认从 `http://127.0.0.1:8765/` 启动。
如果该端口已被占用，插件会自动选择另一个可用本地端口，并写回 `user://funplay_mcp_settings.cfg`。

### 3. 配置 AI 客户端

优先使用 `Funplay MCP` Dock 里的 **一键 MCP 配置**。

选择目标客户端后点击 **Configure**，插件会直接帮你写入推荐的 MCP 配置项。

如果 Godot 自动切到了其他端口，请以 Dock 里显示的 endpoint 为准。
如果你更想手动编辑配置文件，再参考下面这些示例：

<details>
<summary>Claude Code / Claude Desktop</summary>

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

</details>

<details>
<summary>Cursor</summary>

```json
{
  "mcpServers": {
    "funplay": {
      "url": "http://127.0.0.1:8765/"
    }
  }
}
```

</details>

<details>
<summary>VS Code</summary>

```json
{
  "servers": {
    "funplay": {
      "type": "http",
      "url": "http://127.0.0.1:8765/"
    }
  }
}
```

</details>

<details>
<summary>Codex</summary>

```toml
[mcp_servers.funplay]
url = "http://127.0.0.1:8765/"
```

</details>

### 4. 验证连接

先在 AI 客户端里试几个安全请求：

- “调用 `get_scene_info`，告诉我当前打开的是哪个场景。”
- “读取 `godot://project/context`，总结当前编辑器状态。”
- “调用 `execute_code`，返回当前激活场景名。”

如果这些都正常返回，说明 MCP server、resources 和主执行工具都已经连通。

### 5. 开始构建

打开你的 AI 客户端，试试：*"创建一个带血条、分数文本和暂停按钮的 2D HUD"*

## 开始前说明

- 这是一个 **仅限 Editor** 的插件，不会向最终导出游戏添加运行时代码。
- MCP Server 默认从 `http://127.0.0.1:8765/` 启动；如果端口被占用，会自动切换到其他可用本地端口。
- 本地 MCP Server 配置保存在 `user://funplay_mcp_settings.cfg`。
- 插件默认使用 `core` MCP 工具暴露配置，减少 AI 客户端的工具噪音；如果你需要完整工具面，可在 Dock 中切换到 `full`。
- 所有已暴露的 MCP 工具都会直接执行，不再提供额外 approval 开关。
- Dock 内置 Codex、Claude Code、Cursor、VS Code 的配置复制和直接写入能力。

## 为什么做这个项目

- **`execute_code` 主工具优先** — 核心体验围绕一个高灵活度 GDScript 执行工具构建，适合复杂编辑器/运行态编排
- **Play Mode 自动化闭环** — 进入运行模式、模拟输入、查看日志、截图、验证行为都能在同一 MCP 会话里完成
- **内建项目上下文** — 直接提供项目状态、当前场景、选择对象、运行状态、脚本错误、日志和 MCP 交互记录资源
- **默认聚焦，必要时全量** — 默认 `core` 工具集更利于 AI 选工具，需要时可切到 `full`
- **单 Godot Addon 落地** — 不需要额外 approval UI，也不依赖单独的 Python 守护进程
- **可扩展** — 后续可以继续扩展更多 Godot 专用工具、资源和工作流 prompt

## 核心特性

- **87 个内置工具** — 覆盖场景编辑、PackedScene、脚本、文件、运行态控制、输入模拟、UI 控件、动画、相机、性能、Resources、Prompts 与编辑器自动化
- **Resources 与 Prompts** — 暴露实时项目上下文、场景/选择/错误资源、资源模板，以及常见 Godot 工作流的可复用 MCP Prompt
- **输入模拟 + 视图截图验证** — 在 Play Mode 中模拟 action / 键盘 / 鼠标 / 拖拽，再用编辑器视图截图验证结果
- **一键客户端配置** — 直接在 Godot Dock 中为 Codex、Claude Code、Cursor、VS Code 生成并写入 MCP 配置
- **UI/Control 工具链** — 可直接构建 CanvasLayer / Control 树、设置布局、覆盖 Theme、连接信号并搭建 HUD
- **厂商无关** — 兼容任意支持 MCP 的 AI 客户端：Claude Code、Cursor、Windsurf、Codex、VS Code Copilot 等

## 与 Unity MCP 的对比

下表基于 `FunplayAI/funplay-unity-mcp` 的公开定位与结构做对比。

| 维度 | Funplay MCP for Godot | Funplay MCP for Unity |
|------|------------------------|-----------------------|
| 引擎侧架构 | Godot Addon 内置 HTTP MCP server | Unity 包内置 HTTP MCP server |
| 额外本地依赖 | `core` 工作流下只需要 Godot Addon 本身 | `core` 工作流下只需要 Unity 包本身 |
| 主要交互模型 | 以 `execute_code` 为主，再配合少量高频辅助工具 | 以 `execute_code` 为主，再配合少量高频辅助工具 |
| 默认工具暴露 | 默认 `core` 精简工具集，可切 `full` | 默认 `core` 精简工具集，可切 `full` |
| 上下文能力 | 项目资源、脚本错误、运行状态、日志、Prompts、交互历史 | 项目资源、编译错误、运行状态、日志、Prompts、交互历史 |
| UI 自动化 | 深度支持 Godot `Control` / `CanvasLayer` 工作流 | 深度支持 Unity Canvas / UI 工作流 |
| 定位 | 轻量、直接、MIT 协议的 Godot MCP 服务器 | 轻量、直接、MIT 协议的 Unity MCP 服务器 |

## MCP 能力结构

当前开源包有四层高价值能力：

- **Tools** — 共 87 个工具，覆盖场景、脚本、文件、UI、动画、相机、诊断与自动化
- **Primary execution** — `execute_code` 用于复杂编辑器/运行态编排
- **Prompts** — 包括 `scene_review`、`feature_plan`、`runtime_debug`、`script_patch`、`ui_layout_plan` 等工作流 Prompt
- **Resources** — 项目上下文、场景摘要、选择状态、日志、脚本错误、运行状态、项目特性、MCP 交互记录，以及文件模板资源

## 内置工具

Funplay MCP for Godot 当前提供 **87 个工具函数**，覆盖这些工作流分组：

| 分类 | 工具 |
|------|------|
| **场景** | `get_scene_info`, `get_scene_tree`, `list_scenes`, `open_scene`, `save_scene`, `save_scene_as`, `create_new_scene`, `instantiate_scene`, `create_packed_scene_from_node`, `get_packed_scene_info` |
| **节点** | `get_node_info`, `find_nodes`, `select_node`, `create_node`, `duplicate_node`, `rename_node`, `reparent_node`, `remove_node`, `set_node_property`, `set_node_properties`, `set_transform_2d`, `set_transform_3d`, `set_node_script` |
| **节点反射** | `list_node_properties`, `list_node_signals`, `list_node_methods` |
| **脚本** | `create_script`, `edit_script`, `patch_script`, `open_script`, `validate_gdscript_file`, `get_script_errors`, `request_script_reload` |
| **文件** | `read_file`, `write_file`, `search_files`, `list_files`, `file_exists`, `delete_file`, `move_file`, `copy_file` |
| **运行 / 输入** | `get_play_state`, `enter_play_mode`, `play_main_scene`, `exit_play_mode`, `simulate_action`, `simulate_key_event`, `simulate_mouse_button`, `simulate_mouse_drag`, `simulate_input_sequence`, `get_time_scale`, `set_time_scale` |
| **性能 / 日志** | `get_performance_snapshot`, `analyze_scene_complexity`, `get_console_logs`, `log_message` |
| **动画** | `create_animation_player`, `create_animation_clip`, `add_animation_track`, `list_animations`, `play_animation` |
| **相机** | `get_camera_info`, `set_camera_2d`, `set_camera_3d` |
| **材质** | `create_material`, `assign_material` |
| **UI / Control** | `create_ui_root`, `create_control`, `create_label`, `create_button`, `create_panel`, `create_texture_rect`, `create_container`, `set_control_layout`, `set_control_size_flags`, `set_control_text`, `set_control_theme_override`, `set_control_texture`, `connect_node_signal` |
| **项目 / Addons** | `get_project_info`, `list_project_features`, `select_file`, `list_addons`, `set_addon_enabled` |
| **截图 / 执行** | `capture_editor_view`, `execute_code` |

## 仓库结构

- `addons/funplay_mcp/plugin.gd` — Godot 编辑器插件入口
- `addons/funplay_mcp/core/` — MCP server、tools、resources、prompts、settings、config writer
- `addons/funplay_mcp/ui/` — Godot Dock UI
- `CHANGELOG.md` — 面向用户的变更记录
- `CONTRIBUTING.md` — 贡献说明
- `RELEASE_CHECKLIST.md` — 发布清单

## 参与贡献

见 [CONTRIBUTING.md](./CONTRIBUTING.md)。

## License

本仓库采用 [MIT](./LICENSE) 协议。
