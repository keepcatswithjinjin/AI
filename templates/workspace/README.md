# Col 开发工作区

本目录是个人多项目开发工作区，用于管理项目、需求方案和并行 worktree。

## 目录职责

| 路径 | 职责 |
|------|------|
| `CLAUDE.md` / `AGENTS.md` | Agent 入口与操作路由 |
| `STRUCTURE.md` | 全局结构地图和维护检查清单 |
| `scripts/git-dashboard.cmd` / `scripts/git-dashboard.ps1` | Git/worktree 状态仪表盘入口 |
| `scripts/db-analysis.cmd` / `scripts/db-analysis.ps1` | MySQL 数据库结构查询和分析入口，转调全局 `db-analysis` skill |
| `scripts/db-targets.json` | 本地数据库目标配置 |
| `scripts/open-workspace.cmd` / `scripts/open-workspace.ps1` | 按本地状态一键恢复 agent 工作台 |
| `scripts/register-workspace.cmd` / `scripts/register-workspace.ps1` | 将当前 worktree 登记到工作台状态 |
| `scripts/workspace-state.json` | 本地 agent 工作台状态，手工维护 |
| `scripts/INDEX.md` | scripts 目录索引，说明脚本和状态文件职责 |
| `rules/` | 公共流程规则，避免根入口膨胀 |
| `governance/agent-guard/` | Codex 跨项目 Hook 与受保护路径、SQL 治理策略 |
| `governance/agent-guard/` | Codex 跨项目 Hook 与受保护路径、SQL 治理策略 |
| `scripts/` | 自动化脚本和本地工作台状态 |
| `briefs/` | 复杂需求的设计方案、接口契约、前后端计划 |
| `worktrees/` | 新 worktree 的统一根目录 |
| `<项目>/` | 主项目仓库，只保留稳定主工作区 |

## 日常入口

| 场景 | 入口 |
|------|------|
| 检查整体结构 | `STRUCTURE.md` |
| 检查脚本目录 | `scripts/INDEX.md` |
| 查看 Git/worktree 状态 | `scripts\git-dashboard.cmd -Board` |
| 查询数据库结构 | `scripts\db-analysis.cmd -ListTargets` |
| 恢复 agent 工作台 | `scripts\open-workspace.cmd` |
| 注册当前工作台 | `scripts\register-workspace.cmd -Tool codex|claude` |
| 引入新项目 | `vibe-coding-新项目初始化指南.md` |
| 查看规则维护点 | `rules/INDEX.md` |
| 查看或人工调整 Codex 治理策略 | `governance/agent-guard/README.md` |
| 查看或人工调整 Codex 治理策略 | `governance/agent-guard/README.md` |
| 开始新需求 | `rules/task-lifecycle.md` |
| 创建或删除 worktree | `rules/worktree.md` |
| 写设计方案 | `rules/design.md` |
| 交接执行上下文 | `rules/handoff.md` |

## 核心约定

- `__WORKSPACE_ROOT__` 是工作区容器，不作为 Git 仓库管理；Git 操作仅在登记项目及其 worktree 内执行。
- 根目录 session 只做设计和调度，不写业务代码。
- 根目录允许运行只读 Git 仪表盘，用于查看项目、worktree、测试分支占用；看板查询不需要额外总结。
- `scripts/workspace-state.json` 是个人本地工作台状态，不进入项目仓库。
- 新需求默认使用 `worktrees/<原项目目录名>-worktree/<需求名>`。
- 复杂需求的 `需求名 = brief 文件夹名 = worktree 目录名`。
- 简单需求可直接创建 worktree 执行，不进入 `briefs/INDEX.md`。

## 工作台恢复

手工维护 `scripts/workspace-state.json`，恢复时始终以其中登记的 `sessionName` 为准。

如需注册工作台，显式提供后续用于 resume 的 `sessionName`；不要求它等于分支名。

预览全部配置：

```powershell
.\scripts\open-workspace.cmd -WhatIf -All
```

打开 `enabled=true` 的 session：

```powershell
.\scripts\open-workspace.cmd
```

脚本会优先使用 Windows Terminal；未安装 `wt` 时回退到 PowerShell 窗口。

登记当前 worktree 到工作台：

```powershell
.\scripts\register-workspace.cmd -Tool codex -SessionName "my-session"
.\scripts\register-workspace.cmd -Tool claude -SessionName "my-session"
```
