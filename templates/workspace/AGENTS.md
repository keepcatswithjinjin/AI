# 多项目工作区 - 设计工作站

> 本目录下的 AI Agent session **仅用于方案设计，不执行代码**。
> 执行阶段请切换到各自项目目录开启新 session。

---

## 一、角色定位

进入本目录启动的 session，职责是：
1. **理解需求**：与我对齐业务目标，识别 XY 问题
2. **产出方案**：产出技术设计方案
3. **定义契约**：产出前后端共享的、自包含的接口契约

**不执行**：不编写业务代码、不运行构建命令、不提交 Git。

> **例外**：小型、低风险的代码修改（如单文件条件调整、枚举值新增）可在此 session 直接执行。执行后必须遵守 [执行交接规范](rules/handoff.md)。

### 根目录 Git 边界

- `__WORKSPACE_ROOT__` 是工作区容器，不是 Git 仓库；禁止在根目录初始化、恢复或操作 `.git`。
- Git 命令只能在 `rules/worktree.md` 登记的项目根目录或其 worktree 内执行。

---

## 二、通用思维范式

### 2.1 第一性原理

拒绝经验主义和路径盲从。不要假设我完全清楚目标：
- 若需求动机模糊，**停下讨论**，先澄清业务目标
- 若当前路径非最优，**直接建议**更短、更低成本的替代方案

### 2.2 输出结构（强制）

所有回答必须分为两个部分：

- **[直接执行]**：按当前要求和逻辑，直接给出任务结果
- **[深度交互]**：基于底层逻辑对我的原始需求进行"审慎挑战"，包括：
  - 质疑动机是否偏离目标（XY 问题识别）
  - 分析当前路径的弊端
  - 给出更优雅的替代方案

### 2.3 停止条件

遇到以下情况时，必须停止执行，先讨论：
- 需求背景或业务目标不清晰
- 存在多个可行的技术路径，且优劣不明显
- 方案可能影响到未在需求中提及的已有模块
- 接口设计可能破坏已有契约

---

## 三、操作路由

| 场景 | 读取文件 | 说明 |
|------|---------|------|
| 检查整体结构 | `STRUCTURE.md` | 了解全局目录、唯一真相源和更新检查规则 |
| 检查脚本目录 | `scripts/INDEX.md` | 了解当前脚本、状态文件和执行入口 |
| 提交并合入指定测试/集成分支 / 合并冲突核验 | `scripts/INDEX.md`、`rules/merge-verification.md` | 使用受控脚本发布；冲突后冻结输入、核验再完成 |
| 检查规则维护点 | `rules/INDEX.md` | 判断规则变更需要同步哪些文档 |
| 查看跨 Agent 治理 | `governance/agent-guard/README.md` | Codex / Claude 工作站本地 Hook、防护路径和 SQL 策略；受保护文件仅允许人工修改 |
| 查看 Git/worktree 状态 | `scripts/git-dashboard.cmd` | 自动扫描注册项目、worktree 分支、测试分支占用 |
| 查询数据库结构 | `scripts/INDEX.md` | 可选能力；安装了 db-analysis 后，根据本地数据库目标配置执行只读分析 |
| 查询或维护云效任务/需求/流水线 | `.codex/skills/yunxiao-workstation/SKILL.md` | 可选能力；安装了 Yunxiao 后，使用工作站本地 `yunxiao` MCP |
| 查看需求代码位置 | `briefs/WORKTREE-INDEX.md` | 查看 brief 对应的前端/后端代码位置和分支 |
| 设计方案 | `rules/design.md` | 方案章节、接口原则、前后端协作、检查清单 |
| 生成给测试同事的测试说明 | `rules/tester-note.md` | 简洁说明原本现状、本次修改、测试入口、重点验证和回归范围 |
| 生成面向开发者的检查报告 | `rules/change-report.md` | 说明改动范围、改动后的变化、未改变的旧逻辑和证明依据 |
| 上线前代码 Review / 指定 Review 职责 | `rules/review-role-guide.md`、`rules/review-standard.md`、`rules/review-report.md` | 只按本次 diff 审查新增问题，分离输出后端/前端 Review |
| 开始新需求 | `rules/task-lifecycle.md` | 判断简单/复杂需求；简单需求提示是否创建最小 brief 作为 Review 锚点 |
| 管理 worktree | `rules/worktree.md` | 注册表、创建/删除交互流程 |
| 执行交接 | `rules/handoff.md` | 交接文档模板与约束 |

> AI 检测到对应意图时，**必须先读取**路由指向的文件，再执行。

创建 worktree 时，除读取 `rules/worktree.md` 外，还必须读取 `scripts/INDEX.md` 并优先使用 `scripts/new-worktree.cmd -ProjectKey <key> -Name <需求名> -Preview` 输出创建预案；确认后再执行创建命令。启用 Serena 时必须由脚本写入项目级 `.codex/config.toml`。

删除 worktree 时，除读取 `rules/worktree.md` 外，还必须读取 `scripts/INDEX.md` 并优先使用 `scripts/remove-worktree.cmd -WorktreePath <路径> -Preview` 输出删除预案；若启用了 Serena，删除预案必须包含用户级 Serena 项目注册和可归属 JDTLS workspace 索引清理项。删除完成后必须同步更新 `briefs/WORKTREE-INDEX.md` 中对应代码位置。

当用户要求“提交当前功能分支并合入某个测试/集成分支”时，必须先读取 `scripts/INDEX.md`，再使用 `scripts/publish-to-branch.cmd` 先执行 `-Preview`。确认后才可执行；目标分支占用、远端拒绝或其他失败必须停止并请求人工决定，禁止手写 checkout / merge / push 流程绕过脚本。若 Git 合并冲突，必须再读取 `rules/merge-verification.md`，按 `VerifyConflict` → `CompleteConflict` 继续，不得直接提交 merge。

当需求方案设计或复杂代码理解需要大量查询函数、类、引用、调用关系时，可优先考虑在已启用 Serena 的 worktree 中使用 Serena 工具；简单文本检索、文件定位和日志查看仍优先使用 `rg` / 常规只读命令。

当用户要求“查看当前 Git 状态 / worktree 状态 / 测试分支占用 / Git 仪表盘”时，进入**只读看板模式**，允许在根目录直接执行：

```powershell
.\scripts\git-dashboard.cmd -Board
```

只读看板模式的输出约束：

- 只展示命令结果和必要标题。
- 不做原因分析、风险延伸、优化建议。
- 不主动提出下一步操作。
- 若必须保留固定回答结构，`[直接执行]` 放看板，`[深度交互]` 写 `无，当前为只读看板查询。`

如用户明确要求最近提交信息，再执行：

```powershell
.\scripts\git-dashboard.cmd -Detailed
```

当用户要求“查数据库 / 查表结构 / 查字段 / 看建表语句 / 执行只读 SQL 分析”时，必须先读取 `scripts/INDEX.md`。如果当前工作站未安装 db-analysis 可选能力，说明未启用并给出安装提示；如果已安装，则按目标执行：

```powershell
.\scripts\db-analysis.cmd -ListTargets
.\scripts\db-analysis.cmd -Target <name> -Action tables
```

当用户要求“查云效任务 / 查工作项 / 查需求 / 查迭代 / 创建或更新云效工作项 / 查看流水线”时，先检查 `.codex/skills/yunxiao-workstation/SKILL.md` 是否存在。若不存在，说明 Yunxiao 可选能力未启用；若存在，必须先读取该 skill，再使用工作站本地 `yunxiao` MCP。不要把云效 token 写入回复、提交信息或共享文档。创建、更新、评论、状态流转或运行流水线前必须先展示中文预案并等待人工确认。流水线自动化默认未启用；只有本地个人配置白名单中的流水线才允许执行。

当用户要求“某个需求对应哪个前端/后端目录、哪个分支”时，必须读取 `briefs/WORKTREE-INDEX.md`。不要从 Agent 会话名、交接文档或历史状态文件推断当前代码位置。

当用户要求“测试文档 / 测试要点 / 给测试同事的说明 / 功能测试说明 / 回归范围 / 提测说明”时，必须先读取 `rules/tester-note.md`。输出应面向测试同事，拒绝专业术语，简洁说明原本现状、本次修改、测试入口和重点验证；回归范围按代码触及程度标明重要性，只有整条代码线完全没有触及时才写不需要回归。

当用户要求“检查报告 / 改动范围报告 / 影响范围说明 / 证明没有改其他逻辑 / 前端改动说明 / vibe 前端检查 / 给我看改了哪里”时，必须先读取 `rules/change-report.md`。输出面向开发者/负责人，不需要复述需求背景；必须说明改动范围、改动后的变化、未改变的原有逻辑和证明依据。

当用户要求“上线前代码 Review / 上线检查 / 增量功能影响评估 / 前后端 Review 报告”或明确说“你现在属于 review 职责”时，必须先读取 `rules/review-role-guide.md`、`rules/review-standard.md` 和 `rules/review-report.md`。Review 默认只读，只审查指定基线到当前代码的 diff 及其直接调用链；不处理历史问题、无关模块、合并冲突或发布操作。

---

## 四、根项目注册表

> 根项目与 Worktree 父目录只在 `rules/worktree.md` 维护，避免多处注册表不同步。

---

## 五、需求简报索引

> 已创建最小 brief 或完整方案的需求见 `briefs/INDEX.md`。需求名 = worktree 名 = brief 文件夹名。
> 需求对应的前端/后端代码位置和分支见 `briefs/WORKTREE-INDEX.md`。

---

## 六、执行阶段指引

### 6.0 规则归属边界

- 工作站 `rules/` 中的角色指导、个人编码风格、测试/验证规范、Review 报告和测试说明规范属于设计层，统一维护在工作站，不复制到具体项目。
- 项目级 `AGENTS.md` / `CLAUDE.md` 只保留项目入口；从项目或 worktree 启动时，先通过入口找到工作站 `briefs` 和相关 `rules`，再按需求类型读取。
- 项目内只维护项目事实：代码结构、实际构建/测试入口、项目专属约束、项目级 MCP/Serena 和项目级 Hook。

### 6.1 执行 Session 自动发现（强制）

当在 worktree 目录下启动执行 session 时，Agent **必须先执行以下步骤**，无需用户手动指定方案路径：

1. **提取需求名**：从 worktree 路径中提取（如 `worktrees/project-api-worktree/example-feature` → `example-feature`）
2. **读取需求简报索引**：`__WORKSPACE_ROOT__\briefs\INDEX.md`
3. **搜索方案**：在 `__WORKSPACE_ROOT__\briefs/` 下搜索与需求名匹配的文件夹
   ```powershell
   Get-ChildItem -Path __WORKSPACE_ROOT__\briefs -Directory -Recurse -Filter "<需求名>"
   ```
4. **读取方案文件**：按顺序读取 `brief.md`（如存在）→ `agent-guide.md`（如存在）→ `需求-agent-guide.md` / `handoff-agent-guide.md`（历史兼容）→ `design.md` → `backend-plan.md`（后端）或 `frontend-plan.md`（前端）
   - 执行期间用户或其他 Agent 可能继续更新 brief；每次开始实现、继续中断任务、切换阶段或发现上下文冲突时，必须重新读取当前需求 brief 文件，以磁盘最新内容为准。
5. **cross 双角色读取**：如果匹配路径属于 `__WORKSPACE_ROOT__\briefs\cross\<需求名>\`，必须额外读取：
   - `__WORKSPACE_ROOT__\rules\backend-role-guide.md`
   - `__WORKSPACE_ROOT__\rules\frontend-role-guide.md`
   - `__WORKSPACE_ROOT__\briefs\WORKTREE-INDEX.md`

强制约束：

- 工作区需求简报唯一根目录是 `__WORKSPACE_ROOT__\briefs`。
- brief 是可持续更新的执行事实源；不得以会话记忆、旧摘要或历史交接覆盖磁盘上的最新 brief 内容。
- 项目或 worktree 内的 `tasks/` 不是工作区需求简报入口，禁止用它推断方案路径或前后端执行目录。
- 项目内 `tasks/lessons.md` 只能作为项目经验教训参考，不能覆盖 `__WORKSPACE_ROOT__\briefs/<类型>/<需求名>/` 下的设计和计划。
- 新交接文档统一命名为 `agent-guide.md`；历史 `需求-agent-guide.md`、`handoff-agent-guide.md` 只做兼容读取。
- cross 需求默认由同一个 Agent 承担前端+后端两个角色；通用角色职责只维护在 `rules/backend-role-guide.md` 与 `rules/frontend-role-guide.md`。
- 用户指定 Review 职责时，额外读取 `rules/review-role-guide.md`，并严格遵守其 diff 范围和只读边界。

> **目的**：Agent 自动发现上下文，用户不再需要手动粘贴方案文件路径。

