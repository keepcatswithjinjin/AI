# 需求简报索引

> **规则**：只维护已产出方案文档（`briefs/`）的复杂需求。仅有 `agent-guide.md` 而无方案文档的需求，不进入本索引。
>
> **命名约定**：worktree 名 = brief 文件夹名。
>
> **交接文档约定**：新交接文档统一命名为 `agent-guide.md`；历史旧名继续兼容读取。
>
> **代码位置索引**：需求 brief 对应的前端/后端代码位置和分支统一维护在 `briefs/WORKTREE-INDEX.md`。本文件不维护 Agent 会话状态。
>
> **最新 brief 优先**：执行 Agent 运行期间，用户或其他 Agent 可能继续修改 `briefs/<类型>/<需求名>/` 下的方案、计划或交接文档；每次开始实现、切换阶段、继续中断任务或发现上下文冲突时，必须重新读取对应 brief 文件，以磁盘上的最新内容为准。
>
> **cross 执行模式**：cross 需求默认由同一个 Agent 承担前端+后端两个角色。角色职责固定读取 `rules/backend-role-guide.md` 与 `rules/frontend-role-guide.md`，不要在每个需求 brief 中重复维护角色说明。
>
> 最后更新：安装后按实际项目更新

---

## 状态说明

| 状态 | 含义 |
|------|------|
| 未开始 | 方案文档已建，worktree 未创建 |
| 敲定方案 | design.md 已完成，等待创建 worktree 进入开发 |
| 开发中 | worktree 存在，正在编码 |
| 开发完成 | worktree 已删除，代码已合并 |

---

## cross（前后端协作）

| 需求 | 方案路径 | 后端 worktree | 前端 worktree | 状态 |
|------|---------|-------------|--------------|------|
| `example-feature` | `briefs/cross/example-feature/` | `worktrees/project-api-worktree/example-feature` | `worktrees/project-web-worktree/example-feature` | 示例 |

## backend（纯后端）

| 需求 | 方案路径 | worktree | 状态 |
|------|---------|---------|------|
| — | — | — | 暂无 |

## frontend（纯前端）

| 需求 | 方案路径 | worktree | 状态 |
|------|---------|---------|------|
| — | — | — | 暂无 |
