# 新需求生命周期规范

> 本文件定义新需求如何进入多项目工作站。项目引入见 `vibe-coding-新项目初始化指南.md`，worktree 创建见 `rules/worktree.md`。

---

## 一、需求分级

| 类型 | 判断标准 | 是否进入 `briefs/` |
|------|----------|------------------|
| 简单需求 | 单项目、低风险、无接口契约、无跨端协作 | 否 |
| 后端复杂需求 | 涉及数据模型、接口、任务、MQ、支付、权限、多个模块 | 是，`briefs/backend/<需求名>/` |
| 前端复杂需求 | 涉及新页面、复杂状态、路由、跨页面交互 | 是，`briefs/frontend/<需求名>/` |
| 跨端需求 | 前后端或多个后端项目需要共享契约 | 是，`briefs/cross/<需求名>/` |

---

## 二、命名约定

- 需求名使用 kebab-case，例如 `order-export`。
- 复杂需求必须满足：`需求名 = brief 文件夹名 = worktree 目录名`。
- 同一需求涉及多个项目时，各项目 worktree 使用同一个需求名。

示例：

```text
briefs/cross/order-export/
worktrees/project-api-worktree/order-export/
worktrees/project-web-worktree/order-export/
```

---

## 三、简单需求流程

1. 读取 `rules/worktree.md`。
2. 按注册表选择根项目。
3. 创建 `worktrees/<原项目目录名>-worktree/<需求名>`。
4. 在 worktree 中按项目级 `CLAUDE.md` / `AGENTS.md` 执行。
5. 完成后用 `git worktree remove` 删除 worktree。

简单需求不写入 `briefs/INDEX.md`。

---

## 四、复杂需求流程

1. 在 `__WORKSPACE_ROOT__` 根 session 澄清业务目标。
2. 判断需求类型：`backend`、`frontend`、`cross`。
3. 创建 `briefs/<类型>/<需求名>/`。
4. 按 `rules/design.md` 产出对应文档。
5. 同步更新 `briefs/INDEX.md`。
6. 审核通过后，按 `rules/worktree.md` 创建对应项目 worktree。
7. 在执行 session 中自动按需求名读取 `briefs/INDEX.md` 和方案文件。
8. 执行期间如果用户继续讨论、修改方案、补充交接或切换实现阶段，执行 Agent 必须重新读取当前需求 brief 文件；以磁盘上的最新 `agent-guide.md`、`design.md`、`api-contract.md`、`backend-plan.md`、`frontend-plan.md` 为准，不以会话记忆或旧摘要为准。

---

## 五、文档清单

| 类型 | 必需文档 |
|------|----------|
| `backend` | `design.md`、`backend-plan.md` |
| `frontend` | `design.md`、`frontend-plan.md` |
| `cross` | `design.md`、`api-contract.md`、`backend-plan.md`、`frontend-plan.md` |

`api-contract.md` 只在存在接口协作时创建，且必须作为前后端契约唯一真相源。

### 5.1 cross 双角色执行模式

cross 需求默认由同一个 Agent 承担后端+前端两个角色，避免在桌面端多目录切换时拆散上下文。

- 通用后端角色职责固定读取：`__WORKSPACE_ROOT__\rules\backend-role-guide.md`
- 通用前端角色职责固定读取：`__WORKSPACE_ROOT__\rules\frontend-role-guide.md`
- 需求特有执行计划仍写在当前 brief 的 `backend-plan.md` / `frontend-plan.md`
- 代码位置与分支只读取 `__WORKSPACE_ROOT__\briefs\WORKTREE-INDEX.md`

不要在每个 `briefs/cross/<需求名>/` 中复制角色定位；只写本需求特有的接口、页面、数据和验证计划。

### 5.2 Agent 交接文档命名

- 统一标准文件名：`agent-guide.md`
- 适用场景：需要给下一个执行 Agent 明确当前进度、关键决策、继续步骤时
- 存放位置：`briefs/<类型>/<需求名>/agent-guide.md`

历史兼容：

- 已存在的 `需求-agent-guide.md`、`handoff-agent-guide.md` 暂不强制迁移
- 新增或更新时统一使用 `agent-guide.md`
- 执行 Agent 读取时，优先级为：`agent-guide.md` → `需求-agent-guide.md` → `handoff-agent-guide.md`

---

## 六、状态维护

- `briefs/INDEX.md` 只登记已产出方案文档的任务。
- `briefs/INDEX.md` 的状态用于管理视图，实际 worktree 以各主项目 `git worktree list` 为准。
- 没有方案文档的简单需求不登记到 `briefs/INDEX.md`，避免索引膨胀。

---

## 七、执行期上下文边界

- 多项目工作站的需求简报唯一根目录是 `__WORKSPACE_ROOT__\briefs`。
- brief 是可被讨论持续更新的执行事实源；执行 Agent 每次开始实现、继续中断任务、切换前后端阶段或发现上下文冲突时，必须重新读取当前需求 brief 的最新文件。
- 项目或 worktree 内的自定义文档目录不属于多项目工作站需求生命周期，禁止作为需求方案入口。
- `agent-guide.md` 是执行交接标准文件名；历史旧名只做兼容读取，不再作为新文档命名标准。

