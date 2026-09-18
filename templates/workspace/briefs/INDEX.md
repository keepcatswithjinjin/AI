# 需求简报索引

> **规则**：仅维护已创建完整方案的复杂需求；简单需求不进入本索引。
>
> **命名约定**：worktree 名 = brief 文件夹名。
>
> **交接文档约定**：新交接文档统一命名为 `agent-guide.md`；历史旧名继续兼容读取。
>
> **代码位置索引**：需求 brief 对应的前端/后端代码位置和分支统一维护在 `briefs/WORKTREE-INDEX.md`。本文件不维护 Agent 会话状态。
>
> **最新 brief 优先**：执行 Agent 运行期间，用户或其他 Agent 可能继续修改 `briefs/<类型>/<需求名>/` 下的方案、计划或交接文档；每次开始实现、切换阶段、继续中断任务或发现上下文冲突时，必须重新读取对应 brief 文件，以磁盘上的最新内容为准。
>
> **文档职责**：复杂需求由 `design.md` 承载供用户审核的目标、边界、关键方案和验收；`api-contract.md` 是字段级接口真相源，`*-plan.md` 是 Agent 实施与验证指引；不维护独立需求文档。简单需求以当前明确范围与 diff 作为执行和 Review 边界。执行中确认的变化按 `rules/task-lifecycle.md` 第八节同步，`agent-guide.md` 只记录状态与证据。
>
> **cross 执行模式**：cross 需求默认由同一个 Agent 承担前端+后端两个角色。角色职责固定读取 `rules/backend-role-guide.md` 与 `rules/frontend-role-guide.md`，不要在每个需求 brief 中重复维护角色说明。
>
> 最后更新：安装后按实际项目更新

---

## cross（前后端协作）

| 需求 | brief 路径 |
|------|-----------|
| `example-feature` | `briefs/cross/example-feature/` |

## backend（纯后端）

| 需求 | brief 路径 |
|------|-----------|
| — | — |

## frontend（纯前端）

| 需求 | brief 路径 |
|------|-----------|
| — | — |
