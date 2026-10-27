# 规则索引与维护清单

> 本文件只记录规则文件职责和更新触发条件，不复制具体规则内容。

---

## 规则文件职责

| 文件 | 职责 | 何时读取 |
|------|------|----------|
| `README.md` | 工作区人工入口 | 不熟悉目录结构时 |
| `STRUCTURE.md` | 全局结构地图和维护清单 | 检查或调整工作区结构时 |
| `AGENTS.md` / `CLAUDE.md` | 公共 Agent 入口；CLAUDE 仅导入 AGENTS，不重复维护 | Agent 接入；继承到项目时按当前请求确定职责 |
| `scripts/git-dashboard.cmd` / `scripts/git-dashboard.ps1` | Git/worktree 状态仪表盘 | 查看当前项目、分支、测试分支占用 |
| `scripts/new-worktree.cmd` / `scripts/new-worktree.ps1` | Worktree 创建入口 | 新增需求 worktree、创建分支 |
| `scripts/db-analysis.cmd` / `scripts/db-analysis.ps1` | 可选数据库结构查询与只读分析 | 查看 MySQL 库、表、字段和建表语句；能力范围以已安装 Skill 和本地策略为准 |
| `scripts/remove-worktree.cmd` / `scripts/remove-worktree.ps1` | Worktree 删除入口 | 删除 worktree、清理残留 |
| `scripts/publish-to-branch.cmd` / `scripts/publish-to-branch.ps1` | 功能分支发布入口 | 提交指定文件、合入指定测试/集成分支、成功后恢复源分支 |
| `governance/agent-guard/README.md` | 跨 Agent 治理说明 | 查看 Codex / Claude 工作站本地 Hook、防护路径和 SQL 策略 |
| `rules/INDEX.md` | 规则文件索引与维护清单 | 修改任一规则文件前后 |
| `rules/worktree.md` | 根项目注册表、worktree 创建/删除规则 | 创建、删除、迁移 worktree |
| `rules/worktree-locations.md` | 一需求多代码位置与旧索引兼容 | 多位置创建、清理与状态核验 |
| `rules/task-lifecycle.md` | 单次授权边界、新需求初始化、spec/runtime 资料归属、执行中决策变化、旧版本保留决定和提交前对齐 | 单次豁免流程、开始新需求、执行中调整、批量改写 brief、提交前对齐 |
| `rules/design.md` | 用户审核用方案、执行计划和接口契约职责 | 产出方案文档、同步已确认设计变化 |
| `rules/brief-readme-template.md` | 需求 README 生成模板与链接检查 | 实际产出 brief 或维护需求 README |
| `rules/execution-entry.md` | 跨客户端执行接入、角色必需上下文和按需能力路由 | 从需求 README 或项目入口接手执行 |
| `rules/backend-role-guide.md` | 单后端及 cross 后端实施职责 | 执行后端需求、维护后端开发习惯 |
| `rules/backend-coding-style.md` | 通用后端编码习惯、分层、查询、事务和对象构造规则 | 执行后端代码修改、维护个人后端开发习惯 |
| `rules/frontend-role-guide.md` | 单前端及 cross 前端实施职责 | 执行前端需求、维护前端开发习惯 |
| `rules/verification.md` | 后端测试类、Maven reactor 构建与测试通过证据 | 运行后端测试、Maven 构建、重要或复杂后端改动收尾 |
| `rules/tester-note.md` | 给测试同事看的功能测试说明、测试入口和回归范围规范 | 生成测试文档、测试要点、提测说明、回归测试范围 |
| `rules/change-report.md` | 面向开发者/负责人的改动范围、影响范围和未改旧逻辑证明规范 | 生成检查报告、改动范围报告、影响范围说明、前端 vibe 改动说明 |
| `rules/first-pass-code-review.md` | 提交前首版人工代码核对的调用链导航与流程图规范 | 用户明确要求生成首版代码 Review 导航图 |
| `rules/review-standard.md` | 上线前后端代码 Review 的优先级、增量/新增功能判定和证据要求 | 上线前代码 Review、影响评估、上线安全检查 |
| `rules/review-report.md` | 分离的后端 Review、前端 Review 和最终上线建议报告结构 | 输出上线前 Review 报告、前端详细代码解释 |
| `rules/review-role-guide.md` | 独立 Review 角色的必读路由、diff 边界和只读职责 | 用户指定 Review 职责、上线前代码 Review |
| `rules/merge-verification.md` | Git 合并冲突的三方输入冻结、分类核验、人工决策与编译边界 | `publish-to-branch` 发生冲突后 |
| `rules/handoff.md` | 阶段交接自动维护、Git 现场与验证证据、跨客户端接续要求 | 阶段完成、暂停、阻塞或切换/接手 Agent |
| `briefs/INDEX.md` | 已进入工作站流程的复杂需求简报索引 | 新增、扩展或清理 brief |
| `briefs/WORKTREE-INDEX.md` | Brief 对应代码位置与分支索引 | 创建、删除、迁移 worktree 或调整执行分支 |
| `vibe-coding-新项目初始化指南.md` | 新项目接入当前工作区的流程 | 引入新项目 |

---

## 更新触发条件

| 变更 | 必须检查/更新 |
|------|---------------|
| 精简或调整根 Agent 入口 | `AGENTS.md`、`CLAUDE.md` 导入、`README.md`、`STRUCTURE.md`、`rules/execution-entry.md`、本索引 |
| 调整单次授权边界 | `rules/task-lifecycle.md`、`rules/worktree.md`、`CLAUDE.md` / `AGENTS.md` |
| 新增根项目 | `rules/worktree.md`、`vibe-coding-新项目初始化指南.md` 如流程变化 |
| 调整 worktree 路径规则 | `STRUCTURE.md`、`rules/worktree.md`、`README.md`、`vibe-coding-新项目初始化指南.md`、各 worktree 父目录 README |
| 调整 worktree 创建流程 | `scripts/INDEX.md`、`rules/worktree.md`、`README.md`、`CLAUDE.md` / `AGENTS.md`、`STRUCTURE.md`、`vibe-coding-新项目初始化指南.md`、相关项目级 Agent 入口 |
| 调整 worktree 删除流程 | `scripts/INDEX.md`、`rules/worktree.md`、`README.md`、`CLAUDE.md` / `AGENTS.md`、`STRUCTURE.md` |
| 新增复杂需求方案 | `briefs/INDEX.md`、`briefs/WORKTREE-INDEX.md`、对应 `briefs/<类型>/<需求名>/` |
| 创建、删除或迁移需求 worktree | `briefs/WORKTREE-INDEX.md`、必要时 `briefs/INDEX.md` |
| 调整设计方案格式 | `rules/design.md`、`rules/task-lifecycle.md` 如入口变化 |
| 调整需求 README 或执行发现路由 | `rules/brief-readme-template.md`、`rules/execution-entry.md`、`rules/design.md`、`rules/task-lifecycle.md`、`rules/INDEX.md`、`README.md`、`STRUCTURE.md`、`CLAUDE.md` / `AGENTS.md`；新建或实际维护需求 README 时应用 |
| 调整后端编码习惯 | `rules/backend-coding-style.md`、`rules/backend-role-guide.md`、`README.md`、`STRUCTURE.md` |
| 调整后端测试或 Maven 构建规范 | `rules/verification.md`、`README.md`、`CLAUDE.md` / `AGENTS.md`、`STRUCTURE.md` |
| 调整测试同事说明规范 | `rules/tester-note.md`、`README.md`、`CLAUDE.md` / `AGENTS.md`、`STRUCTURE.md` |
| 调整改动检查报告规范 | `rules/change-report.md`、`README.md`、`CLAUDE.md` / `AGENTS.md`、`STRUCTURE.md` |
| 调整首版人工代码 Review 导航规范 | `rules/first-pass-code-review.md`、`artifacts/README.md`、`README.md`、`CLAUDE.md` / `AGENTS.md`、`STRUCTURE.md` |
| 调整上线前 Review 规范或 Review 角色 | `rules/review-standard.md`、`rules/review-report.md`、`rules/review-role-guide.md`、`README.md`、`CLAUDE.md` / `AGENTS.md`、`STRUCTURE.md` |
| 调整合并冲突核验规范 | `rules/merge-verification.md`、`scripts/publish-to-branch.ps1`、`scripts/INDEX.md`、`rules/worktree.md`、`README.md`、`CLAUDE.md` / `AGENTS.md`、`STRUCTURE.md` |
| 调整需求分级、最小 brief 或流程 | `rules/task-lifecycle.md`、`briefs/INDEX.md`、`README.md`、`CLAUDE.md` / `AGENTS.md`、`STRUCTURE.md` |
| 调整执行中决策同步或提交前 briefs 对齐 | `rules/task-lifecycle.md`、`rules/design.md`、`rules/handoff.md`、`rules/review-role-guide.md`、`briefs/INDEX.md`、`CLAUDE.md` / `AGENTS.md` |
| 调整 brief 快照规则 | `rules/task-lifecycle.md`、`rules/design.md`、`rules/handoff.md`、`README.md`、`STRUCTURE.md` |
| 调整交接要求 | `rules/handoff.md`、`rules/task-lifecycle.md`、`CLAUDE.md` / `AGENTS.md`、`README.md`、`STRUCTURE.md` |
| 新增规则文件 | `STRUCTURE.md`、`rules/INDEX.md`、`README.md`、`CLAUDE.md` / `AGENTS.md` 操作路由 |
| 新增根目录工具入口 | `STRUCTURE.md`、`README.md`、`CLAUDE.md` / `AGENTS.md`，必要时本文件 |
| 调整跨 Agent 治理 Hook 或策略 | `STRUCTURE.md`、`governance/agent-guard/README.md`、`.codex/config.toml`、`.claude/settings.local.json`、`governance/agent-guard/tests/test_post_tool_guard.py` |

---

## 防漂移原则

- 每个事实只维护在一个文件里。
- 用户只需审核 design：目标、边界、关键决定、适用 DDL 和发布范围/顺序须可见。字段级契约归契约，实施与验收验证归计划，进度归交接；简单需求不强建独立文档。
- 其他文件只引用，不复制详细规则。
- 公共入口只维护于 AGENTS.md，CLAUDE.md 只导入，README 只保留人工概览与导航；不自动导入整套规则。下表/维护清单要求“检查”不等于复制正文：CLAUDE 仅检查导入，详细流程变更优先更新唯一规则源，入口仍准确时无需扩写。
- 修改规则后，先检查本文件确认同步面。
- `briefs/INDEX.md` 只登记已进入工作站流程的复杂需求，不维护开发状态；生命周期只在 `briefs/WORKSTATION-STATE.json` 维护。
- 不维护 Agent 会话恢复状态；代码位置和分支只在 `briefs/WORKTREE-INDEX.md` 维护。
- 当前需求文档位于 `spec/`，执行交接与核验材料位于 `runtime/`；历史快照与备份不作为当前输入，默认不新增快照，禁止自行生成 `.bak` 等备份。
- Codex / Claude 的工作站治理 Hook 只维护在工作站 local 配置；用户级配置只放个人默认，不绑定具体工作站。

