# Brief ↔ Worktree / 分支索引

> 本文件只维护“需求 brief 对应的代码位置与分支名称”。
> 不维护开发状态、Agent 会话、负责人、最后进度等会漂移的信息。
>
> 最终执行 Git 操作前，仍必须实时执行 `git status` / `git worktree list` / `scripts\git-dashboard.cmd -Board` 校验。
>
> 最后核验：安装后按实际项目更新

---

## 维护规则

- `需求名 = brief 文件夹名 = worktree 目录名`。
- 跨端需求分别记录后端和前端代码位置；单端需求只记录一个代码位置。
- 分支名称记录为创建时约定分支；如果目录不存在或不是 Git worktree，必须明确标注。
- 不记录“开发中 / 已完成 / 当前 Agent / 会话名”之类运行状态。
- 创建、删除或迁移 worktree 时，同步更新本文件中的对应代码位置；不要维护额外状态文件。

---

## cross

| 需求 | Brief | 后端代码位置 | 后端分支 | 前端代码位置 | 前端分支 | 备注 |
|------|-------|--------------|----------|--------------|----------|------|
| `example-feature` | `briefs/cross/example-feature/` | `__WORKSPACE_ROOT__\worktrees\project-api-worktree\example-feature` | `feature/example-feature` | `__WORKSPACE_ROOT__\worktrees\project-web-worktree\example-feature` | `feature/example-feature` | 示例，安装后替换 |

---

## backend

| 需求 | Brief | 后端代码位置 | 后端分支 | 备注 |
|------|-------|--------------|----------|------|
| — | — | — | — | 暂无 |

---

## frontend

| 需求 | Brief | 前端代码位置 | 前端分支 | 备注 |
|------|-------|--------------|----------|------|
| — | — | — | — | 暂无 |

---

## 待补 brief 或待归档目录

这些目录当前能在 Git worktree 查询中看到，或本地存在，但不满足 `briefs/INDEX.md` 的完整复杂需求登记规则。不要把它们当成标准入口；需要继续维护时，先补 brief 或归档清理。

| 目录 | 分支 | 说明 |
|------|------|------|
| — | — | 暂无 |