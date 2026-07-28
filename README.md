# Multi-Project Workstation

一个可复用的 Windows 多项目工作站模板：集中管理项目注册、Git worktree、可选 Serena 代码理解、Agent 工作台恢复、只读数据库分析，以及 Codex / Claude Code 的统一治理。

本仓库管理的是**工作站框架**，不是业务项目的父仓库。安装后生成的工作区容器不纳入本仓库 Git；其中每个业务项目仍保留自己的独立 Git 仓库。

## 包含内容

- `templates/workspace/`：可实例化的工作区规则、脚本与 Agent 入口文件。
- `templates/workspace/governance/agent-guard/`：Codex 与 Claude Code 共用的 `PreToolUse` 治理守卫。
- `skills/db-analysis/`：不含凭据的 MySQL 只读分析 skill。
- `install.ps1`：把模板渲染到指定的工作区根目录。
- `USAGE.zh-CN.md`：安装、Hook 注册、本地数据库配置和维护说明。

## 边界

不要把业务项目、worktree、真实数据库配置、个人 session 状态或 Agent 用户配置提交到本仓库。详细说明见 [使用指南](USAGE.zh-CN.md)。

## 快速开始

```powershell
Set-Location D:\AI-Toolkit\multi-project-workstation
.\install.ps1 -WorkspaceRoot D:\Workspace
```

之后按使用指南将 Codex 和 Claude Code 的 Hook 指向 `D:\Workspace\governance\agent-guard\pre_tool_guard.py`。
