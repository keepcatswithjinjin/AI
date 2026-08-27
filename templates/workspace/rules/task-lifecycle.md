# 新需求生命周期规范

> 本文件定义新需求如何进入多项目开发结构。项目引入见 `vibe-coding-新项目初始化指南.md`，worktree 创建见 `rules/worktree.md`。

---

## 一、需求分级

| 类型 | 判断标准 | brief 要求 |
|------|----------|------------------|
| 简单需求 | 单项目、低风险、无接口契约、无跨端协作 | 推荐最小 brief；用户明确暂不创建时可跳过 |
| 后端复杂需求 | 涉及数据模型、接口、任务、MQ、支付、权限、多个模块 | 是，`briefs/backend/<需求名>/` |
| 前端复杂需求 | 涉及新页面、复杂状态、路由、跨页面交互 | 是，`briefs/frontend/<需求名>/` |
| 跨端需求 | 前后端或多个后端项目需要共享契约 | 是，`briefs/cross/<需求名>/` |

---

## 二、命名约定

- 需求名使用 kebab-case，例如 `resub-report`。
- 复杂需求必须满足：`需求名 = brief 文件夹名 = worktree 目录名`。
- 同一需求涉及多个项目时，各项目 worktree 使用同一个需求名。

示例：

```text
briefs/cross/resub-report/
worktrees/OverSea-worktree/resub-report/
worktrees/oversea-web-platform-worktree/resub-report/
```

---

## 三、简单需求流程

1. 在首次确认需求后，提示用户：**“这是简单需求；是否先创建最小 brief，作为后续 Review 的范围与验收锚点？”**
2. 该提示是协作建议，不是强制门槛；用户明确说暂不创建时，在当前对话中注明“无 brief”后继续。
3. 用户确认时，创建 `briefs/<类型>/<需求名>/brief.md` 并登记 `briefs/INDEX.md`；不要求 `design.md`、计划或接口契约。
4. 读取 `rules/worktree.md`，按注册表选择根项目并创建 `worktrees/<原项目目录名>-worktree/<需求名>`。
5. 创建 worktree 时按 `rules/worktree.md` 询问是否启用 Serena；简单需求默认不启用。
6. 在 worktree 中按项目级 `CLAUDE.md` / `AGENTS.md` 执行。
7. 完成后用 `git worktree remove` 删除 worktree。

---

## 四、复杂需求流程

1. 在工作区根 session 澄清业务目标。
2. 判断需求类型：`backend`、`frontend`、`cross`。
3. 创建 `briefs/<类型>/<需求名>/`。
4. 按 `rules/design.md` 产出对应文档。
5. 同步更新 `briefs/INDEX.md`。
6. 审核通过后，按 `rules/worktree.md` 创建对应项目 worktree。
7. 创建 worktree 时询问是否启用 Serena；复杂需求推荐启用，并在 worktree 根目录写入项目级 `.codex/config.toml`。
8. 在 Codex 桌面端新开 task，目录选择对应 worktree 根目录；需要 Serena 时必须通过新 task 加载项目级配置。
9. 在执行 session 中自动按需求名读取 `briefs/INDEX.md` 和方案文件。
10. 执行期间如果用户继续讨论、修改方案、补充交接或切换实现阶段，执行 Agent 必须重新读取当前需求 brief 文件；以磁盘上的最新 `agent-guide.md`、`design.md`、`api-contract.md`、`backend-plan.md`、`frontend-plan.md` 为准，不以会话记忆或旧摘要为准。

---

## 五、文档清单

| 类型 | 必需文档 |
|------|----------|
| `backend` | `design.md`、`backend-plan.md` |
| `frontend` | `design.md`、`frontend-plan.md` |
| `cross` | `design.md`、`api-contract.md`、`backend-plan.md`、`frontend-plan.md` |

`api-contract.md` 只在存在接口协作时创建，且必须作为前后端契约唯一真相源。

### 5.0 最小 brief

适用于简单需求，也可作为复杂需求创建完整方案前的起点。文件为 `briefs/<类型>/<需求名>/brief.md`，只包含：

```markdown
# <需求名>

## 目标

## 预期改动

## 明确不改的边界

## 验收与 Review 关注点
```

它不记录开发进度、会话状态或临时实现细节。后续需要时可扩展为 `design.md`、计划和契约；执行与 Review 均以磁盘上的最新 brief 为准。

### 5.1 cross 双角色执行模式

- cross 需求默认不拆分 Agent；即使前后端代码仓库分离、存在两个 worktree，也由同一个执行 Agent 承担后端角色与前端角色。
- 每个 cross brief 不重复书写通用角色定位；执行 Agent 必须固定读取：
  - `__WORKSPACE_ROOT__\rules\backend-role-guide.md`
  - `__WORKSPACE_ROOT__\rules\frontend-role-guide.md`
- `backend-plan.md` 和 `frontend-plan.md` 只写本需求特有的任务、路径、接口和验证点，不维护通用角色说明。
- 当前需求对应的前端/后端代码位置和分支只从 `__WORKSPACE_ROOT__\briefs\WORKTREE-INDEX.md` 读取，不从 Agent 会话名或交接文档推断。
- 同一 Agent 在执行时按阶段切换角色：先按后端角色完成接口/服务/测试，再按前端角色完成页面/调用/交互，最后以联调视角核对 `api-contract.md`。

### 5.2 Agent 交接文档命名

- 统一标准文件名：`agent-guide.md`
- 适用场景：需要给下一个执行 Agent 明确当前进度、关键决策、继续步骤时
- 存放位置：`briefs/<类型>/<需求名>/agent-guide.md`

历史兼容：

- 已存在的 `需求-agent-guide.md`、`handoff-agent-guide.md` 暂不强制迁移
- 新增或更新时统一使用 `agent-guide.md`
- 执行 Agent 读取时，优先级为：`agent-guide.md` → `需求-agent-guide.md` → `handoff-agent-guide.md`

---

## 六、索引维护

- `briefs/INDEX.md` 登记已创建的最小 brief 或完整方案，不维护开发状态。
- 实际 worktree、分支和占用情况以 `briefs/WORKTREE-INDEX.md` 与各项目实时 Git 查询为准。
- 用户明确跳过 brief 的简单需求不登记，避免为短期修改维护无价值索引。

---

## 七、执行期上下文边界

- 工作区需求简报唯一根目录是 `__WORKSPACE_ROOT__\briefs`。
- brief 是可被讨论持续更新的执行事实源；执行 Agent 每次开始实现、继续中断任务、切换前后端阶段或发现上下文冲突时，必须重新读取当前需求 brief 的最新文件。
- 项目或 worktree 内的 `tasks/` 不属于工作区需求生命周期，禁止作为需求方案入口。
- 项目内 `tasks/lessons.md` 只能作为项目经验教训参考，不能用于推断 `design.md`、`api-contract.md`、`backend-plan.md`、`frontend-plan.md` 的位置。
- `agent-guide.md` 是执行交接标准文件名；历史旧名只做兼容读取，不再作为新文档命名标准。

