# 多项目工作站 - 设计工作站

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
| 检查规则维护点 | `rules/INDEX.md` | 判断规则变更需要同步哪些文档 |
| 查看 Codex 跨项目治理 | `governance/agent-guard/README.md` | Hook、防护路径和 SQL 策略；受保护文件仅允许人工修改 |
| 查看 Codex 跨项目治理 | `governance/agent-guard/README.md` | Hook、防护路径和 SQL 策略；受保护文件仅允许人工修改 |
| 查看 Git/worktree 状态 | `scripts/git-dashboard.cmd` | 自动扫描注册项目、worktree 分支、测试分支占用 |
| 查询数据库结构 | `scripts/INDEX.md` | 根据本地数据库目标配置执行只读分析 |
| 恢复工作台 | `scripts/INDEX.md` | 根据本地状态恢复已登记的 agent 工作目录 |
| 设计方案 | `rules/design.md` | 方案章节、接口原则、前后端协作、检查清单 |
| 开始新需求 | `rules/task-lifecycle.md` | 判断简单/复杂需求，创建 briefs 结构和执行入口 |
| 管理 worktree | `rules/worktree.md` | 注册表、创建/删除交互流程 |
| 执行交接 | `rules/handoff.md` | 交接文档模板与约束 |

> AI 检测到对应意图时，**必须先读取**路由指向的文件，再执行。

删除 worktree 时，除读取 `rules/worktree.md` 外，还必须同步读取 `scripts/workspace-state.json`，找到最匹配的 `sessionName` 并向用户确认是否同步清理工作台状态。

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

当用户要求“查数据库 / 查表结构 / 查字段 / 看建表语句 / 执行只读 SQL 分析”时，必须先读取 `scripts/INDEX.md`，然后按目标执行：

```powershell
.\scripts\db-analysis.cmd -ListTargets
.\scripts\db-analysis.cmd -Target <name> -Action tables
```

当用户要求“恢复工作台 / 恢复工作区 / 打开昨天的工作目录 / 恢复 agent 工作区”时，必须先读取 `scripts/INDEX.md`，然后执行：

```powershell
.\scripts\open-workspace.cmd
```

如用户先想确认会打开哪些目录，再执行：

```powershell
.\scripts\open-workspace.cmd -WhatIf -All
```

恢复约束：

- 通过 `workspace-state.json` 中登记的 `sessionName` 恢复。
- 若用户要求注册工作台，使用用户提供的可恢复 `sessionName` 登记；不要求它等于分支名。

---

## 四、根项目注册表

> 根项目与 Worktree 父目录只在 `rules/worktree.md` 维护，避免多处注册表不同步。

---

## 五、需求简报索引

> 所有需求简报见 `briefs/INDEX.md`。需求名 = worktree 名 = brief 文件夹名。

---

## 六、执行阶段指引

### 6.1 执行 Session 自动发现（强制）

当在 worktree 目录下启动执行 session 时，Agent **必须先执行以下步骤**，无需用户手动指定方案路径：

1. **提取需求名**：从 worktree 路径中提取（如 `worktrees/project-api-worktree/order-export` → `order-export`）
2. **读取需求简报索引**：`__WORKSPACE_ROOT__\briefs\INDEX.md`
3. **搜索方案**：在 `__WORKSPACE_ROOT__\briefs/` 下搜索与需求名匹配的文件夹
   ```powershell
   Get-ChildItem -Path __WORKSPACE_ROOT__\briefs -Directory -Recurse -Filter "<需求名>"
   ```
4. **读取方案文件**：按顺序读取 `agent-guide.md`（如存在）→ `需求-agent-guide.md` / `handoff-agent-guide.md`（历史兼容）→ `design.md` → `backend-plan.md`（后端）或 `frontend-plan.md`（前端）

强制约束：

- Col 需求简报唯一根目录是 `__WORKSPACE_ROOT__\briefs`。
- 项目或 worktree 内的自定义文档目录不是需求简报入口，禁止用它推断方案路径或前后端执行目录。
- 新交接文档统一命名为 `agent-guide.md`；历史 `需求-agent-guide.md`、`handoff-agent-guide.md` 只做兼容读取。

> **目的**：Agent 自动发现上下文，用户不再需要手动粘贴方案文件路径。

