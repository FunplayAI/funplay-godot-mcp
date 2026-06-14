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

这个插件既可用于标准 Godot `4.2+` 项目，也可以运行在 **Godot .NET** 项目中。当前实现主体仍然是 GDScript，脚本类工具会按项目语言自动暴露：GDScript 项目显示 GDScript 工作流，.NET 项目显示 C#/.NET 工作流，混合项目按需同时开放。

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

- 从最新 GitHub Release 下载 `Funplay.GodotMcp.vX.Y.Z.zip`，并解压到你的 Godot 项目根目录
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
本地 MCP POST 请求默认需要 `user://funplay_mcp_settings.cfg` 中保存的项目 auth token；Dock 生成客户端配置时会自动写入这个 token。
Dock 里也会显示当前插件版本，并提供 **Check Updates** 按钮；当 GitHub Release 有新版本时，可以直接打开发布页。

### 3. 配置 AI 客户端

优先使用 `Funplay MCP` Dock 里的 **一键 MCP 配置**。

选择目标客户端后点击 **Configure**，插件会直接帮你写入推荐的 MCP 配置项。
如果还想同时生成项目级 AI 使用说明，点击 **Configure + Skills**，插件会在 `res://.funplay/skills/` 下生成项目 Skill 文件，并维护一个 `AGENTS.md` 桥接说明。

如果 Godot 自动切到了其他端口，请以 Dock 里显示的 endpoint 为准。
如果你更想手动编辑配置文件，再参考下面这些示例：

<details>
<summary>Claude Code / Claude Desktop</summary>

```json
{
  "mcpServers": {
    "funplay": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "funplay-godot-mcp@0.9.2"],
      "env": {
        "FUNPLAY_GODOT_MCP_URL": "http://127.0.0.1:8765/",
        "FUNPLAY_GODOT_MCP_TOKEN": "<Funplay MCP Dock 中显示/写入的 token>"
      }
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
      "command": "npx",
      "args": ["-y", "funplay-godot-mcp@0.9.2"],
      "env": {
        "FUNPLAY_GODOT_MCP_URL": "http://127.0.0.1:8765/",
        "FUNPLAY_GODOT_MCP_TOKEN": "<Funplay MCP Dock 中显示/写入的 token>"
      }
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
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "funplay-godot-mcp@0.9.2"],
      "env": {
        "FUNPLAY_GODOT_MCP_URL": "http://127.0.0.1:8765/",
        "FUNPLAY_GODOT_MCP_TOKEN": "<Funplay MCP Dock 中显示/写入的 token>"
      }
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

### 可选 stdio wrapper

大多数客户端可以直接通过 HTTP 连接 Godot 插件。如果你使用的客户端或发布渠道更偏好 stdio 包，本仓库也提供了 `stdio-wrapper/` 下的 npm wrapper。

```bash
cd stdio-wrapper
npm link
FUNPLAY_GODOT_MCP_URL=http://127.0.0.1:8765/ funplay-godot-mcp
```

等 wrapper 发布到 npm 后，可以把 `npm link` 换成 `npm install -g funplay-godot-mcp`。

MCP 客户端配置示例：

```json
{
  "mcpServers": {
    "funplay": {
      "command": "funplay-godot-mcp",
      "env": {
        "FUNPLAY_GODOT_MCP_URL": "http://127.0.0.1:8765/"
      }
    }
  }
}
```

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
- MCP Server 默认从 `http://127.0.0.1:8765/` 启动；如果同一项目已经占用该端口，Dock 会直接附着到现有服务，否则会自动切换到其他可用本地端口。
- 本地 MCP Server 配置保存在 `user://funplay_mcp_settings.cfg`。
- 插件默认使用 `core` MCP 工具暴露配置，减少 AI 客户端的工具噪音；如果你需要完整工具面，可在 Dock 中切换到 `full`。
- Dock 里提供 Tool Exposure 面板，可以在当前 profile 内逐个开关工具，也可以打开 MCP 调试日志输出和 `execute_code` 安全检查。
- `execute_code` 默认会拦截常见的进程、文件系统和项目设置写入风险；确认过的调用可以传入 `safety_checks=false` 覆盖。
- Dock 可以检查 GitHub Releases 中是否有新版本。
- 聚焦型 MCP 工具会直接执行，不再提供额外 approval 开关。
- Dock 内置 Codex、Claude Code、Cursor、VS Code 的配置复制和直接写入能力。

## 为什么做这个项目

- **`execute_code` 主工具优先** — 核心体验围绕一个高灵活度 GDScript 执行工具构建，适合复杂编辑器/运行态编排，并默认开启高风险片段安全检查
- **工具暴露可控** — 可以直接在 Godot Dock 中开关单个工具，不需要改插件代码
- **Project Skills** — 可生成项目级 AI 使用说明，记录当前 endpoint、工具 profile、项目上下文和推荐工作流
- **工具目录与帮助** — 可通过 MCP 查询分组工具目录、能力门禁、工作流覆盖矩阵和任务指引
- **项目地图与模板** — 检查场景、脚本、函数、信号、引用关系、可搜索浏览器图谱和脚本重构 dry-run 计划
- **Runtime Bridge** — 可选安装轻量 autoload，在 Play Mode 中持续写入运行态 heartbeat 和场景树快照，方便 AI 验证
- **Play Mode 自动化闭环** — 进入运行模式、模拟输入、查看日志、截图、验证行为都能在同一 MCP 会话里完成
- **内建项目上下文** — 直接提供项目状态、当前场景、选择对象、运行状态、脚本错误、日志和 MCP 交互记录资源
- **默认聚焦，必要时全量** — 默认 `core` 工具集更利于 AI 选工具，需要时可切到 `full`
- **单 Godot Addon 落地** — 不需要额外 approval UI，也不依赖单独的 Python 守护进程
- **可扩展** — 后续可以继续扩展更多 Godot 专用工具、资源和工作流 prompt

## 核心特性

- **124 个内置工具** — 覆盖场景编辑、PackedScene、语言感知脚本工具、项目地图、脚本重构规划、项目设置、资产导入计划、InputMap、autoload、Runtime Bridge、Undo/Redo、工作流指引、文件、Project Skills、运行态控制、UI 控件、动画、相机、性能、Resources、Prompts 与编辑器自动化
- **Resources 与 Prompts** — 暴露实时项目上下文、JSON/HTML 项目地图、发布 readiness、运行态场景树快照、场景/选择/错误资源、语言感知脚本诊断、适用时的 `.NET` 项目资源、模板资源，以及常见 Godot 工作流的可复用 MCP Prompt
- **结构化返回** — JSON 工具输出和工具错误都会同步到 MCP `structuredContent`，节点和资源摘要也包含当前会话可用的 `instance_id`
- **输入模拟 + 视图截图验证** — 在 Play Mode 中模拟 action / 键盘 / 鼠标 / 拖拽，再用编辑器视图截图验证结果
- **一键客户端配置** — 直接在 Godot Dock 中为 Codex、Claude Code、Cursor、VS Code 生成并写入 MCP 配置
- **发布与 Registry 就绪** — GitHub Release 产物会生成 manifest 和 SHA256 校验，已补 Godot Asset Library 打包说明，npm stdio wrapper 也通过 `server.json` 描述，并通过 MCP 暴露 release readiness
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
| 上下文能力 | 项目资源、脚本错误、运行状态、运行态场景树、日志、Prompts、交互历史 | 项目资源、编译错误、运行状态、日志、Prompts、交互历史 |
| UI 自动化 | 深度支持 Godot `Control` / `CanvasLayer` 工作流 | 深度支持 Unity Canvas / UI 工作流 |
| 定位 | 轻量、直接、MIT 协议的 Godot MCP 服务器 | 轻量、直接、MIT 协议的 Unity MCP 服务器 |

## MCP 能力结构

当前开源包有四层高价值能力：

- **Tools** — 共 124 个注册工具，覆盖场景、脚本、项目地图、项目配置、资产导入规划、输入映射、autoload、Runtime Bridge、Undo/Redo、工作流指引、文件、Project Skills、UI、动画、相机、诊断与自动化。脚本相关工具会按检测到的项目语言和 Dock 中的 Tool Exposure 设置过滤。
- **Primary execution** — `execute_code` 用于复杂编辑器/运行态编排，默认带安全检查，并可返回上下文辅助 API、日志和变更追踪 metadata
- **Prompts** — 包括 `scene_review`、`feature_plan`、`runtime_debug`、`script_patch`、`ui_layout_plan`、`architecture_advice`、`performance_advice`、`network_template`、`template_generate` 等工作流 Prompt
- **Resources** — 项目上下文、JSON/HTML 项目地图、场景摘要、选择状态、日志、脚本错误、运行状态、运行态场景树、发布 readiness、项目特性、MCP 交互记录、模板目录，以及文件模板资源

## 内置工具

Funplay MCP for Godot 当前提供 **124 个注册工具函数**，覆盖这些工作流分组。实际暴露给 AI 客户端的脚本工具会按检测到的项目语言和逐工具暴露设置过滤：

| 分类 | 工具 |
|------|------|
| **场景** | `get_scene_info`, `get_scene_tree`, `list_scenes`, `open_scene`, `save_scene`, `save_scene_as`, `create_new_scene`, `instantiate_scene`, `create_packed_scene_from_node`, `get_packed_scene_info` |
| **节点** | `get_node_info`, `find_nodes`, `select_node`, `create_node`, `duplicate_node`, `rename_node`, `reparent_node`, `remove_node`, `set_node_property`, `set_node_properties`, `set_transform_2d`, `set_transform_3d`, `set_node_script` |
| **节点反射** | `list_node_properties`, `list_node_signals`, `list_node_methods` |
| **脚本** | `create_script`, `list_scripts`, `edit_script`, `patch_script`, `open_script`, `validate_script`, `get_script_errors`, `request_script_reload`；`.NET` 项目额外暴露 `get_dotnet_project_info` |
| **项目地图** | `map_project`, `find_usages`, `plan_script_refactor`, `apply_script_refactor` |
| **项目设置 / 输入 / Autoload** | `list_project_settings`, `get_project_setting`, `set_project_setting`, `list_input_actions`, `get_input_action`, `add_input_action`, `remove_input_action`, `add_input_event_to_action`, `clear_input_events`, `list_autoloads`, `set_autoload`, `remove_autoload` |
| **指引 / 能力** | `funplay_help`, `list_tool_catalog`, `get_capability_status`, `get_editor_protocol_status`, `get_release_readiness`, `list_workflow_coverage` |
| **Runtime Bridge / Undo** | `install_runtime_bridge`, `remove_runtime_bridge`, `get_runtime_bridge_status`, `get_undo_redo_status`, `editor_undo`, `editor_redo` |
| **文件** | `read_file`, `write_file`, `search_files`, `list_files`, `file_exists`, `delete_file`, `move_file`, `copy_file` |
| **运行 / 输入** | `get_play_state`, `enter_play_mode`, `play_main_scene`, `exit_play_mode`, `simulate_action`, `simulate_key_event`, `simulate_mouse_button`, `simulate_mouse_drag`, `simulate_input_sequence`, `get_time_scale`, `set_time_scale` |
| **断言 / 诊断** | `assert_node_exists`, `assert_node_property`, `assert_signal_connected`, `wait_msec`, `get_performance_snapshot`, `analyze_scene_complexity`, `get_console_logs`, `log_message` |
| **动画** | `create_animation_player`, `create_animation_clip`, `add_animation_track`, `list_animations`, `play_animation` |
| **相机** | `get_camera_info`, `set_camera_2d`, `set_camera_3d` |
| **材质** | `create_material`, `assign_material` |
| **UI / Control** | `create_ui_root`, `create_control`, `create_label`, `create_button`, `create_panel`, `create_texture_rect`, `create_container`, `set_control_layout`, `set_control_size_flags`, `set_control_text`, `set_control_theme_override`, `set_control_texture`, `connect_node_signal` |
| **项目 / Addons** | `get_project_info`, `list_project_features`, `plan_asset_import`, `get_project_skills_status`, `generate_project_skills`, `select_file`, `list_addons`, `set_addon_enabled` |
| **截图 / 执行** | `capture_editor_view`, `execute_code` |

## 仓库结构

- `addons/funplay_mcp/plugin.gd` — Godot 编辑器插件入口
- `addons/funplay_mcp/core/` — MCP server、tools、resources、prompts、settings、config writer
- `addons/funplay_mcp/ui/` — Godot Dock UI
- `stdio-wrapper/` — 给无法直接连接 HTTP MCP 的客户端使用的 npm stdio bridge
- `server.json` — stdio wrapper 的 MCP Registry 元数据
- `scripts/package_release.py` — release 产物构建与包校验脚本
- `ASSET_LIBRARY.md` — Godot Asset Library 打包、提交和更新安全说明
- `CHANGELOG.md` — 面向用户的变更记录
- `CONTRIBUTING.md` — 贡献说明
- `RELEASE_CHECKLIST.md` — 发布清单

## 参与贡献

见 [CONTRIBUTING.md](./CONTRIBUTING.md)。

## License

本仓库采用 [MIT](./LICENSE) 协议。
