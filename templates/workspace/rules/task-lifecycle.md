# 新需求生命周期规范

> 本文件定义新需求如何进入多项目开发结构。项目引入见 `vibe-coding-新项目初始化指南.md`，worktree 创建见 `rules/worktree.md`。

---

## 一、需求分级

| 类型 | 判断标准 | brief 要求 |
|------|----------|------------------|
| 简单需求 | 单项目、低风险、无接口契约、无跨端协作 | 不创建独立 brief；直接执行并以当前 diff 作为 Review 范围 |
| 后端复杂需求 | 涉及数据模型、接口、任务、MQ、支付、权限、多个模块 | 是，`briefs/backend/<需求名>/` 下的设计与后端计划 |
| 前端复杂需求 | 涉及新页面、复杂状态、路由、跨页面交互 | 是，`briefs/frontend/<需求名>/` 下的设计与前端计划 |
| 跨端需求 | 前后端或多个后端项目需要共享契约 | 是，`briefs/cross/<需求名>/` 下的设计、契约与计划 |

---

## 二、命名约定

- 需求名使用 kebab-case，例如 `resub-report`。
- 复杂需求必须满足：`需求名 = brief 文件夹名 = worktree 目录名`。
- 同一需求涉及多个项目时，各项目 worktree 使用同一个需求名。

示例：

```text
briefs/cross/resub-report/
worktrees/project-api-worktree/resub-report/
worktrees/project-web-worktree/resub-report/
```

---

## 三、简单需求流程

1. 不创建独立需求目录，在当前会话明确改动范围、验收边界和不改项后直接执行。
2. 读取 `rules/worktree.md`，按注册表选择根项目并创建 `worktrees/<原项目目录名>-worktree/<需求名>`。
3. 在 worktree 中按项目级 `CLAUDE.md` / `AGENTS.md` 执行；提交前以当前 diff、用户已确认的范围和项目规则完成核对。
4. 完成后使用 `scripts/remove-worktree.cmd` 删除 worktree。

---

## 四、复杂需求流程

1. 在工作区根 session 澄清业务目标。
2. 判断需求类型：`backend`、`frontend`、`cross`。
3. 创建 `briefs/<类型>/<需求名>/`。
4. 按 `rules/design.md` 产出对应文档；用户只需审核自包含的 `design.md`。
5. 同步更新 `briefs/INDEX.md`。
6. 审核通过后，按 `rules/worktree.md` 创建对应项目 worktree。
7. 在 Codex 桌面端新开 task，目录选择对应 worktree 根目录。
8. 在执行 session 中自动按需求名读取 `briefs/INDEX.md` 和方案文件。
9. 执行 Agent 开始实施前必须读取 `design.md`、适用的契约与计划。了解全局设计后按计划实现；计划不是限制其判断代码事实的边界。
10. 执行期间如果用户继续讨论、修改方案、补充交接或切换实现阶段，执行 Agent 必须重新读取相关文件；按第八节同步执行中确认的变化，不以会话记忆或旧摘要为准。

---

## 五、文档清单

| 类型 | 必需文档 |
|------|----------|
| `backend` | `design.md`、`backend-plan.md` |
| `frontend` | `design.md`、`frontend-plan.md` |
| `cross` | `design.md`、`api-contract.md`、`backend-plan.md`、`frontend-plan.md` |

`api-contract.md` 只在存在接口协作时创建，且必须作为前后端契约唯一真相源。

### 5.0 cross 双角色执行模式

- cross 需求默认不拆分 Agent；即使前后端代码仓库分离、存在两个 worktree，也由同一个执行 Agent 承担后端角色与前端角色。
- 每个 cross brief 不重复书写通用角色定位；执行 Agent 必须固定读取：
  - `__WORKSPACE_ROOT__\rules\backend-role-guide.md`
  - `__WORKSPACE_ROOT__\rules\frontend-role-guide.md`
- `backend-plan.md` 和 `frontend-plan.md` 只写本需求特有的任务、路径、接口和验证点，不维护通用角色说明。
- 当前需求对应的前端/后端代码位置和分支只从 `__WORKSPACE_ROOT__\briefs\WORKTREE-INDEX.md` 读取，不从 Agent 会话名或交接文档推断。
- 同一 Agent 在执行时按阶段切换角色：先按后端角色完成接口/服务/测试，再按前端角色完成页面/调用/交互，最后以联调视角核对 `api-contract.md`。

### 5.1 Agent 交接文档命名

- 统一标准文件名：`agent-guide.md`
- 适用场景：需要给下一个执行 Agent 明确当前进度、已确认决策所在文档和继续步骤时
- 存放位置：`briefs/<类型>/<需求名>/agent-guide.md`

历史兼容：

- 已存在的 `需求-agent-guide.md`、`handoff-agent-guide.md` 暂不强制迁移
- 新增或更新时统一使用 `agent-guide.md`
- 执行 Agent 读取时，优先级为：`agent-guide.md` → `需求-agent-guide.md` → `handoff-agent-guide.md`

---

## 六、索引维护

- `briefs/INDEX.md` 仅登记已创建的完整方案，不维护开发状态。
- 实际 worktree、分支和占用情况以 `briefs/WORKTREE-INDEX.md` 与各项目实时 Git 查询为准。
- 简单需求不登记，避免为短期修改维护无价值索引。

---

## 七、执行期上下文边界

- 工作区需求简报唯一根目录是 `__WORKSPACE_ROOT__\briefs`。
- 需求目录中的设计、契约与计划可在执行期间更新；执行 Agent 每次开始实现、继续中断任务、切换前后端阶段或发现上下文冲突时，必须重新读取相关最新文件。
- 项目或 worktree 内的 `tasks/` 不属于工作区需求生命周期，禁止作为需求方案入口。
- 项目内 `tasks/lessons.md` 只能作为项目经验教训参考，不能用于推断 `design.md`、`api-contract.md`、`backend-plan.md`、`frontend-plan.md` 的位置。
- `agent-guide.md` 是执行交接标准文件名；历史旧名只做兼容读取，不再作为新文档命名标准。

## 八、执行中的决策变化与提交前对齐

- 执行 Agent 可依据当前代码事实和用户在执行会话中的明确决定调整实现，不需要重新开启设计会话。若变化涉及目标、验收、不改边界、关键方案、接口契约、默认值或旧数据行为，先向用户说明与已审核设计的差异及影响；需要用户选择的业务取舍由用户决定。
- 确认变化后，由执行 Agent 同步对应事实源：目标/边界/验收及方案取舍/风险/回滚改 `design.md`；接口字段/枚举/空值语义改 `api-contract.md`；代码入口/步骤/验证点改对应 `*-plan.md`。`agent-guide.md` 只记录执行状态、证据和未完成事项，并链接这些事实源。
- 更新 `design.md` 时，写明“原方案 → 当前决定”、原因及影响，使只读 `design.md` 的用户能审核最新方案；其中的行为、默认值和接口摘要须与契约一致。纯实现路径或测试命令变化只更新计划，不必重写设计。
- 用户要求提交或发布前对齐 briefs 时，执行 Agent 以当前 diff 和用户已确认的变化为依据，核对 `design.md`、契约、适用计划及交接文件；修正过期表述，列出尚未确认的偏离。不能为迁就代码而擅自改写未经用户确认的业务目标或验收标准。

