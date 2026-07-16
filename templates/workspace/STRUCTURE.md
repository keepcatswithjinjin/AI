# Col 结构维护清单

> 本文件是 多项目工作区的全局结构地图。检查或调整工作区结构时，先读本文件。

---

## 一、目录地图

| 路径 | 类型 | 职责 | 维护方式 |
|------|------|------|----------|
| `README.md` | 人工入口 | 说明 多项目工作区用途和日常入口 | 手工维护 |
| `CLAUDE.md` | Agent 入口 | Claude 在根目录的操作路由 | 手工维护 |
| `AGENTS.md` | Agent 入口 | Codex/通用 Agent 在根目录的操作路由 | 手工维护 |
| `scripts/git-dashboard.cmd` / `scripts/git-dashboard.ps1` | 工具入口 | Windows 下查看 Git/worktree 状态 | 随脚本维护 |
| `scripts/db-analysis.cmd` / `scripts/db-analysis.ps1` | 工具入口 | Windows 下查询 MySQL 数据库结构和分析 SQL | 随脚本维护 |
| `scripts/db-targets.json` | 本地状态 | 记录常用数据库连接目标 | 手工维护 |
| `scripts/open-workspace.cmd` / `scripts/open-workspace.ps1` | 工具入口 | 按 `scripts/workspace-state.json` 恢复 agent 工作台 | 随脚本维护 |
| `scripts/workspace-state.json` | 本地状态 | 记录需要一键恢复的 agent session | 手工维护 |
| `scripts/INDEX.md` | 脚本索引 | 说明 scripts 内脚本和状态文件职责 | 手工维护 |
| `vibe-coding-新项目初始化指南.md` | 流程指南 | 新项目接入 多项目工作区 | 手工维护 |
| `rules/` | 规则目录 | 设计、需求、worktree、交接规则 | 手工维护 |
| `governance/agent-guard/` | Codex 全局治理 | Hook 脚本与跨项目受保护路径/SQL 策略 | 手工维护，仅人工修改受保护文件 |
| `governance/agent-guard/` | Codex 全局治理 | Hook 脚本与跨项目受保护路径/SQL 策略 | 手工维护，仅人工修改受保护文件 |
| `rules/INDEX.md` | 规则索引 | rules 内部文件职责和同步触发 | 手工维护 |
| `scripts/` | 脚本目录 | 工作区自动化脚本 | 按工具维护 |
| `briefs/` | 需求简报目录 | 复杂需求方案、接口契约、执行计划 | 按需求维护 |
| `briefs/INDEX.md` | 需求简报索引 | 已产出方案文档的需求列表 | 按复杂需求维护 |
| `worktrees/` | Worktree 根目录 | 新 worktree 的统一父目录 | 按注册表维护 |
| `<项目>/` | 主项目仓库 | 稳定主工作区，执行阶段入口 | 项目自身维护 |

---

## 二、唯一真相源

| 信息 | 唯一维护位置 | 其他文件处理方式 |
|------|--------------|------------------|
| 根项目注册表 | `rules/worktree.md` | 只引用，不复制 |
| 新 worktree 路径规则 | `rules/worktree.md` | 只引用，不复制 |
| Git/worktree 状态扫描 | `scripts/git-dashboard.ps1` | 项目列表从 `rules/worktree.md` 自动读取 |
| 数据库目标配置 | `scripts/db-targets.json` | 只记录本地数据库连接目标，不复制到项目内 |
| Codex 跨项目治理策略 | `governance/agent-guard/policy.json` | 定义受保护路径、高风险路径和 SQL 防护策略 |
| Codex 跨项目治理策略 | `governance/agent-guard/policy.json` | 定义受保护路径、高风险路径和 SQL 防护策略 |
| Agent 工作台恢复状态 | `scripts/workspace-state.json` | 只记录本地 enabled session，不复制到项目内 |
| 脚本目录路由 | `scripts/INDEX.md` | 只做脚本入口说明，不复制脚本实现 |
| 新需求生命周期 | `rules/task-lifecycle.md` | 只引用，不复制 |
| 设计方案格式 | `rules/design.md` | 只引用，不复制 |
| 执行交接要求 | `rules/handoff.md` | 只引用，不复制 |
| 已有复杂需求简报 | `briefs/INDEX.md` | 只登记有方案文档的需求 |
| 新项目接入流程 | `vibe-coding-新项目初始化指南.md` | 引用 rules，不复制详细规则 |

---

## 三、Worktree 新结构

新 worktree 统一放在：

```text
__WORKSPACE_ROOT__\worktrees\<原项目目录名>-worktree\<需求名>
```

当前项目父目录：

| 主项目 | 新 Worktree 父目录 |
|--------|--------------------|
| `project-api` | `__WORKSPACE_ROOT__\worktrees\project-api-worktree` |
| `project-web` | `__WORKSPACE_ROOT__\worktrees\project-web-worktree` |

历史 worktree 不迁移，完成后删除。

---

## 四、更新检查规则

| 如果修改了 | 必须检查/更新 |
|------------|---------------|
| 根项目注册表 | `rules/worktree.md`、`STRUCTURE.md`、对应 `worktrees/<项目>-worktree/README.md` |
| worktree 路径规则 | `rules/worktree.md`、`rules/task-lifecycle.md`、`README.md`、`CLAUDE.md`、`AGENTS.md`、`vibe-coding-新项目初始化指南.md`、`STRUCTURE.md` |
| 新增规则文件 | `rules/INDEX.md`、`README.md`、`CLAUDE.md`、`AGENTS.md`、`STRUCTURE.md` |
| 新增或调整根工具入口 | `README.md`、`CLAUDE.md`、`AGENTS.md`、`STRUCTURE.md`、必要时 `rules/INDEX.md` |
| 调整脚本目录结构 | `scripts/INDEX.md`、`README.md`、`STRUCTURE.md` |
| 新增复杂需求 | `briefs/INDEX.md`、对应 `briefs/<类型>/<需求名>/` |
| 调整设计方案格式 | `rules/design.md`、`rules/task-lifecycle.md`、`STRUCTURE.md` |
| 调整新项目接入流程 | `vibe-coding-新项目初始化指南.md`、`STRUCTURE.md` |
| 调整交接要求 | `rules/handoff.md`、`CLAUDE.md`、`AGENTS.md`、`STRUCTURE.md` |

---

## 五、维护原则

- 每次结构或规则调整前，先读本文件。
- 每个事实只维护在一个唯一真相源。
- `STRUCTURE.md` 只做地图和检查清单，不复制详细规则。
- 简单需求不进入 `briefs/INDEX.md`。
- `__WORKSPACE_ROOT__` 根目录是工作区容器，不作为 Git 仓库管理；Git 操作仅在登记项目及其 worktree 内执行。
