# Multi-Project Workstation

一个可复用的 Windows 多项目工作站模板：集中管理项目注册、Git worktree、可选 Serena 代码理解、只读数据库分析、可选云效任务管理，以及 Codex / Claude Code 的统一治理。

本仓库管理的是**工作站框架**，不是业务项目的父仓库。安装后生成的工作区容器不纳入本仓库 Git；其中每个业务项目仍保留自己的独立 Git 仓库。

## 包含内容

- `templates/workspace/`：可实例化的最小工作区规则、脚本与 Agent 入口文件。
- `templates/options/`：可选能力模板；初始化时显式选择是否安装数据库分析和云效能力。
- `templates/workspace/.codex/` 与 `.claude/`：工作站本地 Hook 注册模板。
- `templates/workspace/governance/agent-guard/`：Codex 与 Claude Code 共用的治理守卫。
- `skills/db-analysis/`：不含凭据的 MySQL 只读分析 skill；可选安装。
- `skills/yunxiao-workstation/`：不含凭据的云效任务/需求管理 skill；可选安装，流水线结构保留但默认不启用自动化。
- `install.ps1`：把模板渲染到指定的工作区根目录。
- `USAGE.zh-CN.md`：安装、Hook 注册、本地数据库配置和维护说明。

## 边界

不要把业务项目、worktree、真实数据库配置、云效 token、个人组织/项目目录、个人 session 状态或 Agent 用户级配置提交到本仓库。详细说明见 [使用指南](USAGE.zh-CN.md)。

## 快速开始

```powershell
Set-Location D:\AI-Toolkit\multi-project-workstation
.\install.ps1 -WorkspaceRoot D:\Workspace
```

按需启用可选能力：

```powershell
.\install.ps1 -WorkspaceRoot D:\Workspace -IncludeDbAnalysis -IncludeYunxiao
```

安装后从 `D:\Workspace` 根目录打开 Codex / Claude Code；工作站本地 `.codex` 与 `.claude` 会把 Hook 指向 `D:\Workspace\governance\agent-guard`。如工具提示需要信任本地 Hook，人工确认后生效。
