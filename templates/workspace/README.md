# 多项目开发工作区

本目录是个人多项目开发工作区，用于管理项目、需求方案和并行 worktree。

## 目录职责

| 路径 | 职责 |
|------|------|
| `CLAUDE.md` / `AGENTS.md` | Agent 入口与操作路由 |
| `STRUCTURE.md` | 全局结构地图和维护检查清单 |
| `scripts/git-dashboard.cmd` / `scripts/git-dashboard.ps1` | Git/worktree 状态仪表盘入口 |
| `scripts/new-worktree.cmd` / `scripts/new-worktree.ps1` | 受控新增 worktree，并按需写入 Serena 配置 |
| `scripts/db-analysis.cmd` / `scripts/db-analysis.ps1` | 可选：MySQL 数据库结构查询和分析入口，转调全局 `db-analysis` skill |
| `scripts/db-targets.json` | 可选：本地数据库目标配置 |
| `.codex/mcp/yunxiao-mcp.cmd` | 可选：云效 MCP 本地启动入口 |
| `.codex/secrets/yunxiao.env.example.cmd` | 可选：云效 token 环境变量示例 |
| `.codex/secrets/yunxiao.personal.example.json` | 可选：云效个人组织/项目路由示例 |
| `scripts/remove-worktree.cmd` / `scripts/remove-worktree.ps1` | 受控删除 worktree，并清理可归属 Serena 索引 |
| `scripts/publish-to-branch.cmd` / `scripts/publish-to-branch.ps1` | 受控提交、合入指定分支；冲突时冻结输入、核验后恢复功能分支 |
| `scripts/INDEX.md` | scripts 目录索引，说明脚本和状态文件职责 |
| `.codex/config.toml` | Codex 工作站本地 Hook 注册入口 |
| `.claude/settings.local.json` | Claude Code 工作站本地 Hook 注册入口 |
| `rules/` | 公共流程规则，避免根入口膨胀 |
| `rules/backend-role-guide.md` / `rules/frontend-role-guide.md` | cross 需求中同一 Agent 的后端/前端角色职责 |
| `rules/backend-coding-style.md` | 通用后端编码习惯、分层、查询、事务和对象构造规则 |
| `rules/tester-note.md` | 给测试同事看的功能测试说明、测试入口和回归范围规范 |
| `rules/change-report.md` | 面向开发者/负责人的改动范围、影响范围和未改旧逻辑证明规范 |
| `rules/review-standard.md` / `rules/review-report.md` / `rules/review-role-guide.md` | 上线前 Review 标准、报告结构和独立 Review 角色边界 |
| `rules/merge-verification.md` | Git 合并冲突的冻结输入、分类核验、人工决策和编译边界 |
| `governance/agent-guard/` | Codex / Claude Code 共用 Hook 与受保护路径、SQL 治理策略 |
| `scripts/` | 自动化脚本和本地数据库目标配置 |
| `briefs/` | 最小 brief、复杂需求设计方案、接口契约、前后端计划 |
| `briefs/WORKTREE-INDEX.md` | 需求 brief 对应的代码位置与分支索引 |
| `artifacts/` | 需要长期保存或跨项目复用的文件产物，不承载需求状态 |
| `worktrees/` | 新 worktree 的统一根目录 |
| `<项目>/` | 主项目仓库，只保留稳定主工作区 |

## 日常入口

| 场景 | 入口 |
|------|------|
| 检查整体结构 | `STRUCTURE.md` |
| 检查脚本目录 | `scripts/INDEX.md` |
| 查看 Git/worktree 状态 | `scripts\git-dashboard.cmd -Board` |
| 新增 worktree | `scripts\new-worktree.cmd -ProjectKey <key> -Name <需求名> -Preview` |
| 查询数据库结构 | 可选安装后：`scripts\db-analysis.cmd -ListTargets` |
| 查询云效需求/任务 | 可选安装后：`.codex\skills\yunxiao-workstation\SKILL.md` |
| 保存或查找文件产物 | `artifacts\README.md` |
| 删除 worktree | `scripts\remove-worktree.cmd -WorktreePath <路径> -Preview` |
| 提交并合入指定测试/集成分支 | `scripts\publish-to-branch.cmd -TargetBranch <分支> -Files <逗号分隔文件> -CommitMessage <信息> -Preview` |
| 合并冲突后继续 | `rules\merge-verification.md` → `publish-to-branch.cmd ... -Mode VerifyConflict` |
| 查看需求对应代码位置和分支 | `briefs\WORKTREE-INDEX.md` |
| 执行 cross 前后端需求 | `rules\backend-role-guide.md` + `rules\frontend-role-guide.md` |
| 执行后端代码修改 | `rules\backend-role-guide.md` → `rules\backend-coding-style.md` + 项目级 `AGENTS.md` / `CLAUDE.md` |
| 生成给测试同事的测试说明 | `rules\tester-note.md` |
| 生成面向开发者的检查报告 | `rules\change-report.md` |
| 进行上线前代码 Review | `rules\review-role-guide.md` → `rules\review-standard.md` → `rules\review-report.md` |
| 引入新项目 | `vibe-coding-新项目初始化指南.md` |
| 查看规则维护点 | `rules/INDEX.md` |
| 查看或人工调整跨 Agent 治理策略 | `governance/agent-guard/README.md` |
| 开始新需求 | `rules/task-lifecycle.md` |
| 创建或删除 worktree | `rules/worktree.md` |
| 写设计方案 | `rules/design.md` |
| 交接执行上下文 | `rules/handoff.md` |

## 核心约定

- `__WORKSPACE_ROOT__` 是工作区容器，不作为 Git 仓库管理；Git 操作仅在登记项目及其 worktree 内执行。
- 根目录 session 只做设计和调度，不写业务代码。
- 根目录允许运行只读 Git 仪表盘，用于查看项目、worktree、测试分支占用；看板查询不需要额外总结。
- Codex / Claude Code 的工作站治理 Hook 只注册在当前工作站 local 配置中，不写入用户级配置。
- 新需求默认使用 `worktrees/<原项目目录名>-worktree/<需求名>`。
- 新增 worktree 优先使用 `scripts\new-worktree.cmd`，不要手写底层 Git 创建命令。
- 复杂需求的 `需求名 = brief 文件夹名 = worktree 目录名`。
- cross 需求默认由同一个 Agent 承担后端+前端两个角色；通用角色职责维护在 `rules/backend-role-guide.md` 与 `rules/frontend-role-guide.md`，不写进每个 brief。
- 通用后端编码习惯维护在 `rules/backend-coding-style.md`；项目特殊规则仍以项目级 `AGENTS.md` / `CLAUDE.md` 和当前源码为准。
- 需求对应的前端/后端代码位置和分支只维护在 `briefs\WORKTREE-INDEX.md`；不维护 Agent 会话恢复状态。
- `artifacts/` 只保存需要沉淀的文件产物，不用来推断需求状态、代码位置或分支。
- 简单需求首次确认时会提示是否创建最小 brief；这是协作提示而非强制门槛。已创建最小 brief 或完整方案的需求登记到 `briefs/INDEX.md`，不维护开发状态。
- 新增 worktree 若启用 Serena，必须按 `rules/worktree.md` 写入项目级 `.codex/config.toml`，并使用已验证的 Serena 可执行文件绝对路径。
- 需求方案设计或复杂代码理解中，如需要大量查询函数、类、引用、调用关系，可优先考虑在启用 Serena 的 worktree 中使用 Serena；文本检索和简单定位仍可使用 `rg`。
- 删除 worktree 优先使用 `scripts\remove-worktree.cmd`；启用 Serena 的 worktree 会同步清理用户级项目注册和可归属 JDTLS workspace 索引，保留共享索引与日志。
- 功能分支提交并合入测试/集成分支优先使用 `scripts\publish-to-branch.cmd`；它先推送并修正当前分支 upstream。冲突时冻结输入，人工解决后必须 `VerifyConflict`，只有通过并显式 `CompleteConflict` 才会提交、推送和恢复源分支。
- Review 只审查本次 diff 引入的问题及直接调用链；历史问题、未触及模块与合并冲突过程不纳入 Review 问题清单。
- 数据库分析与云效任务管理是初始化脚本的可选能力；未安装时，Agent 应说明能力未启用，而不是猜测入口。
- 云效 token、个人组织/项目目录和流水线白名单只放 `.codex/secrets/` 的本地真实文件中，不提交。创建/更新云效工作项前必须先展示中文预案并等待确认。流水线自动化默认不启用，只有本地白名单显式开启的流水线才允许执行。

## Brief 与代码位置索引

最小 brief 与复杂需求的设计文档均放在 `briefs/<类型>/<需求名>/`。

需求对应的后端/前端代码位置和分支统一维护在：

```powershell
briefs\WORKTREE-INDEX.md
```

该索引不记录开发进度或 Agent 会话。最终合并、删除 worktree 或切换分支前，仍以实时 Git 查询为准。
