# Multi-Project Workstation

一个可复用的 Windows 多项目工作站模板：集中管理项目注册、需求 README/spec/runtime、Git worktree、阶段交接，以及可选数据库/云效工具与既有治理。不依赖自建客户端，可在不同客户端与 CLI 间接续。

本仓库管理的是**工作站框架**，不是业务项目的父仓库。安装后生成的工作区容器不纳入本仓库 Git；其中每个业务项目仍保留自己的独立 Git 仓库。

## 包含内容

- `templates/workspace/`：可实例化的最小工作区规则、脚本与 Agent 入口文件。
- 通用结构包含 `projects/`、`worktrees/`、`briefs/`、`knowledge/`、`artifacts/`、`tmp/`、`plans/`；只有说明和空索引，不带入任何 Col 业务内容。
- `templates/options/`：可选能力模板；初始化时显式选择是否安装数据库分析和云效能力。
- `templates/workspace/.codex/` 与 `.claude/`：工作站本地 Hook 注册模板。
- `templates/workspace/governance/agent-guard/`：Codex 与 Claude Code 共用的治理守卫。
- `skills/db-analysis/`：不含凭据的 MySQL、PostgreSQL/Hologres 与测试 Redis 分析 skill；可选安装到工作区同名目录，由入口规则发现，无需用户级配置。
- `skills/yunxiao-workstation/`：不含凭据的云效任务/需求管理 skill；可选安装，流水线结构保留但默认不启用自动化。
- `install.ps1`：把模板渲染到指定的工作区根目录。
- `USAGE.zh-CN.md`：安装、Hook 注册、本地数据库配置和维护说明。

## 边界

不要把业务项目、worktree、真实数据库配置、云效 token、个人组织/项目目录、个人 session 状态或 Agent 用户级配置提交到本仓库。详细说明见 [使用指南](USAGE.zh-CN.md)。

## 快速开始

使用 PowerShell 7（pwsh），并安装 Git。安装不克隆项目、不初始化工作站 Git、不连接外部服务。可选数据库能力的客户端由使用者另行准备。

```powershell
Set-Location D:\AI-Toolkit\multi-project-workstation
.\install.ps1 -WorkspaceRoot D:\Workspace
```

按需启用可选能力：

```powershell
.\install.ps1 -WorkspaceRoot D:\Workspace -IncludeDbAnalysis -IncludeYunxiao
```

安装后从 `D:\Workspace` 根目录打开 Codex / Claude Code；工作站本地 `.codex` 与 `.claude` 会把 Hook 指向 `D:\Workspace\governance\agent-guard`。如工具提示需要信任本地 Hook，人工确认后生效。

2026-10-21 已按 Col 当前通用结构同步：精简公共入口、按需执行路由、spec/runtime 归属、自动交接、JSON worktree 结果、阶段同步和需求内冲突核验。未同步业务知识、真实注册表、凭据或个人配置；通用模板保留干净根仓库快进和人工治理批准边界。验证方法与同步差异见使用指南。
