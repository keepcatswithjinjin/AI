# 多项目工作区结构维护清单

> 本文件是当前多项目工作区的全局结构地图。检查或调整工作区结构时，先读本文件。

---

## 一、目录地图

| 路径 | 类型 | 职责 | 维护方式 |
|------|------|------|----------|
| `README.md` | 人工入口 | 说明工作区用途和日常入口 | 手工维护 |
| `CLAUDE.md` | Agent 入口 | Claude 在根目录的操作路由 | 手工维护 |
| `AGENTS.md` | Agent 入口 | Codex/通用 Agent 在根目录的操作路由 | 手工维护 |
| `scripts/git-dashboard.cmd` / `scripts/git-dashboard.ps1` | 工具入口 | Windows 下查看 Git/worktree 状态 | 随脚本维护 |
| `scripts/new-worktree.cmd` / `scripts/new-worktree.ps1` | 工具入口 | Windows 下受控新增 worktree，并按需写入 Serena 配置 | 随脚本维护 |
| `scripts/db-analysis.cmd` / `scripts/db-analysis.ps1` | 可选工具入口 | Windows 下查询 MySQL 数据库结构和分析 SQL | 启用数据库能力时随脚本维护 |
| `scripts/db-targets.json` | 可选本地状态 | 记录常用数据库连接目标 | 手工维护，不提交 |
| `.codex/mcp/yunxiao-mcp.cmd` | 可选工具入口 | 启动工作站本地云效 MCP | 启用云效能力时随模板维护 |
| `.codex/secrets/yunxiao.env.cmd` | 可选本地状态 | 记录云效 token 环境变量 | 手工维护，不提交 |
| `.codex/secrets/yunxiao.personal.json` | 可选本地状态 | 记录个人云效组织、项目、别名和可选流水线白名单 | 手工维护，不提交 |
| `scripts/remove-worktree.cmd` / `scripts/remove-worktree.ps1` | 工具入口 | 受控删除 worktree，并清理可归属 Serena 索引 | 随脚本维护 |
| `scripts/publish-to-branch.cmd` / `scripts/publish-to-branch.ps1` | 工具入口 | 受控提交功能分支指定文件、合入指定分支并恢复功能分支 | 随脚本维护 |
| `scripts/INDEX.md` | 脚本索引 | 说明 scripts 内脚本和状态文件职责 | 手工维护 |
| `vibe-coding-新项目初始化指南.md` | 流程指南 | 新项目接入当前工作区 | 手工维护 |
| `.codex/config.toml` | 工作站本地配置 | Codex 在本工作站的 Hook 注册入口，不承载用户级默认配置 | 由 `governance/agent-guard/sync-hooks.ps1` 维护 |
| `.claude/settings.local.json` | 工作站本地配置 | Claude Code 在本工作站的 Hook 注册入口，不写入用户级配置 | 手工维护，仅人工修改受保护文件 |
| `rules/` | 规则目录 | 设计、需求、worktree、交接规则 | 手工维护 |
| `governance/agent-guard/` | 跨 Agent 全局治理 | Codex / Claude Hook、跨项目受保护路径/SQL 策略，以及人工签发的临时维护审批 | 手工维护，仅人工修改受保护文件 |
| `rules/INDEX.md` | 规则索引 | rules 内部文件职责和同步触发 | 手工维护 |
| `rules/backend-role-guide.md` | 角色规则 | cross 需求中同一 Agent 的后端角色职责 | 手工维护 |
| `rules/backend-coding-style.md` | 编码规则 | 通用后端编码习惯、分层、查询、事务和对象构造规则 | 手工维护 |
| `rules/frontend-role-guide.md` | 角色规则 | cross 需求中同一 Agent 的前端角色职责 | 手工维护 |
| `scripts/` | 脚本目录 | 工作区自动化脚本 | 按工具维护 |
| `briefs/` | 需求简报目录 | 复杂需求方案、接口契约、执行计划 | 按需求维护 |
| `briefs/INDEX.md` | 需求简报索引 | 已产出方案文档的需求列表 | 按复杂需求维护 |
| `briefs/WORKTREE-INDEX.md` | 代码位置索引 | 记录需求 brief 对应的前端/后端代码位置和分支 | 创建、删除、迁移 worktree 时维护 |
| `artifacts/` | 文件产物目录 | 长期保存或跨项目复用的非源码文件产物 | 按产物维护 |
| `artifacts/README.md` | 产物目录说明 | 定义 artifacts 的存放边界和命名约束 | 手工维护 |
| `worktrees/` | Worktree 根目录 | 新 worktree 的统一父目录 | 按注册表维护 |
| `<项目>/` | 主项目仓库 | 稳定主工作区，执行阶段入口 | 项目自身维护 |

---

## 二、唯一真相源

| 信息 | 唯一维护位置 | 其他文件处理方式 |
|------|--------------|------------------|
| 根项目注册表 | `rules/worktree.md` | 只引用，不复制 |
| 新 worktree 路径规则 | `rules/worktree.md` | 只引用，不复制 |
| Git/worktree 状态扫描 | `scripts/git-dashboard.ps1` | 项目列表从 `rules/worktree.md` 自动读取 |
| Worktree 创建入口 | `scripts/new-worktree.ps1` | 从 `rules/worktree.md` 读取项目注册表并统一创建 worktree |
| 数据库目标配置 | `scripts/db-targets.json` | 只记录本地数据库连接目标，不复制到项目内 |
| 云效个人配置 | `.codex/secrets/yunxiao.personal.json` | 只记录个人组织/项目路由与可选流水线白名单，不复制到项目内 |
| 跨 Agent 治理策略 | `governance/agent-guard/policy.json` | 定义受保护路径、高风险路径和 SQL 防护策略 |
| Codex Hook 注册 | `.codex/config.toml` | 由 `governance/agent-guard/hook-registry.json` 生成，不在用户级 Codex 配置维护工作站治理 |
| Claude Hook 注册 | `.claude/settings.local.json` | 仅在当前工作站本地维护，不写入用户级 Claude 配置 |
| Brief 对应代码位置和分支 | `briefs/WORKTREE-INDEX.md` | 不在交接文档或会话状态中重复维护 |
| cross 双角色职责 | `rules/backend-role-guide.md`、`rules/frontend-role-guide.md` | `briefs/<类型>/<需求>/` 只写需求特有计划，不复制通用角色说明 |
| 通用后端编码习惯 | `rules/backend-coding-style.md` | 项目特有规则保留在项目级 `AGENTS.md` / `CLAUDE.md` |
| 保存型文件产物 | `artifacts/` | 不进入 `briefs/INDEX.md` 或 `briefs/WORKTREE-INDEX.md`，不用于推断需求状态 |
| Worktree 删除入口 | `scripts/remove-worktree.ps1` | 统一执行删除前检查和 Serena 可归属索引清理 |
| 功能分支发布入口 | `scripts/publish-to-branch.ps1` | 统一执行文件范围检查、源分支推送、目标分支合并与恢复源分支 |
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

当前项目父目录示例：

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
| 调整保存型文件产物目录 | `artifacts/README.md`、`README.md`、`STRUCTURE.md` |
| 调整跨 Agent 治理 Hook 或策略 | `governance/agent-guard/README.md`、`.codex/config.toml`、`.claude/settings.local.json`、`governance/agent-guard/policy.json` |
| 新增复杂需求 | `briefs/INDEX.md`、对应 `briefs/<类型>/<需求名>/` |
| 创建、删除或迁移需求 worktree | `briefs/WORKTREE-INDEX.md`、必要时 `briefs/INDEX.md` |
| 调整设计方案格式 | `rules/design.md`、`rules/task-lifecycle.md`、`STRUCTURE.md` |
| 调整后端编码习惯 | `rules/backend-coding-style.md`、`rules/backend-role-guide.md`、`README.md`、`STRUCTURE.md` |
| 调整新项目接入流程 | `vibe-coding-新项目初始化指南.md`、`STRUCTURE.md` |
| 调整交接要求 | `rules/handoff.md`、`CLAUDE.md`、`AGENTS.md`、`STRUCTURE.md` |

---

## 五、维护原则

- 每次结构或规则调整前，先读本文件。
- 每个事实只维护在一个唯一真相源。
- `STRUCTURE.md` 只做地图和检查清单，不复制详细规则。
- 简单需求不进入 `briefs/INDEX.md`。
- `artifacts/` 保存文件产物，不承载需求生命周期、代码位置或分支状态。
- 不维护 Agent 会话恢复状态；需求对应代码位置和分支只维护在 `briefs/WORKTREE-INDEX.md`。
- `__WORKSPACE_ROOT__` 根目录是工作区容器，不作为 Git 仓库管理；Git 操作仅在登记项目及其 worktree 内执行。
- Codex / Claude 工作站治理 Hook 只维护在工作站本地配置中；用户级配置不得绑定某个工作站的专属治理。
