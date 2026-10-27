# 新需求生命周期规范

> 本文件定义新需求如何进入多项目开发结构。项目引入见 `vibe-coding-新项目初始化指南.md`，worktree 创建见 `rules/worktree.md`。

---

## 一、需求分级

### 单次授权的适用边界

- 单次授权只对本次任务中用户明确豁免的环节生效，不修改长期规则，也不延伸到后续任务。未明确豁免的命名、项目约束、编码、验证、提交和发布规则继续适用。
- 执行前用一句话说明本次跳过哪些环节、在哪里执行及使用什么分支；授权已清晰时直接执行，不重复索要确认。存在影响下一步的歧义时，只澄清该歧义，不扩大豁免范围。
- 例如“跳过 briefs + worktree，从最新 master 拉修复分支并修改代码”，只豁免 brief 与 worktree 流程；仍须读取目标项目规则和 `rules/worktree.md` 的分支命名要求，在目标项目中从最新 master 创建 `hotfix/<需求名>`。不得自行改成 `codex/fix-...`；用户明确指定完整分支名时按其指定执行。
- 跳过 worktree 不等于授权直接修改 master，跳过 briefs 不等于跳过需求范围与验收核对；也不自动授权丢弃现场、提交、合并或推送。仅因 worktree 流程被豁免而不适用的创建脚本和对应索引步骤一并跳过，其余约束保留。
- 单次授权根项目分支开发时，提交、合并、推送可使用标准 Git，不为适配发布脚本补建 brief。实施授权不包含发布授权；仓库、源/目标分支、提交文件或推送范围不明确时询问，明确授权不重复确认。保留无关改动；冲突、占用或远端拒绝时停止，不自动强推、丢弃现场或绕过 Hook。本例外不适用于常规 worktree 发布。

### 分级标准

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

1. 不创建独立需求目录，在当前会话明确改动范围、验收边界和不改项。
2. 读取 `rules/worktree.md`，按注册表选择根项目并创建 `worktrees/<原项目目录名>-worktree/<需求名>`。
3. 默认创建 worktree 后停止实施，由用户在对应 worktree 新开对话执行。用户明确要求当前对话直接完成时，当前 Agent 可在该 worktree 内继续；开始修改前读取目标项目适用的 `CLAUDE.md` / `AGENTS.md`。提交前以当前 diff、用户已确认的范围和项目规则完成核对。
4. 完成后使用 `scripts/remove-worktree.cmd` 删除 worktree。

---

## 四、复杂需求流程

1. 在工作区根 session 澄清业务目标。
2. 判断需求类型：`backend`、`frontend`、`cross`。
3. 在 `briefs/INDEX.md` 对应类型表登记名称与路径，再调用状态脚本的 `Register` 动作；不创建空目录或模板，不依赖自建客户端。
4. 按 `rules/design.md` 按需创建 `briefs/<类型>/<需求名>/` 并产出对应文档；需求 README 按 `rules/brief-readme-template.md` 生成并接入 `rules/execution-entry.md`；用户只需审核自包含的 `spec/design.md`。
5. 确认 `briefs/INDEX.md` 的对应记录存在且路径正确。
6. 用户明确确认方案后，设计 Agent 必须执行 `./scripts/sync-workstation-state.ps1 -Action DesignReady -RequirementKey <类型>:<需求名>`，将状态同步为“方案已制定，待开发”。该脚本会核验必需文档，重复调用不会重复推进状态；不得仅因首次写出文档就提前同步。
7. 审核通过后，按 `rules/worktree.md` 创建对应项目 worktree。
8. 默认在创建 worktree 后停止实施，由用户在对应 worktree 根目录新开执行对话；用户明确要求当前对话继续实施时，允许当前 Agent 在该 worktree 内继续，无需另开对话。两种方式均须读取目标项目规则与磁盘上的最新 briefs，不因同一对话已有设计记忆而跳过。
9. 在执行 session 中自动按需求名读取 `briefs/INDEX.md` 和方案文件。
10. 执行 Agent 开始实施前按需求 README 进入 `rules/execution-entry.md`，加载适用角色、编码风格、项目规则以及 `spec/design.md`、适用契约与计划；数据库等能力命中任务时再按路由读取。了解全局设计后按计划实现；计划不是限制其判断代码事实的边界。
11. 执行期间如果用户继续讨论、修改方案、补充交接或切换实现阶段，执行 Agent 必须重新读取相关文件；按第八节同步执行中确认的变化，不以会话记忆或旧摘要为准。

---

## 五、文档清单

| 类型 | 必需文档 |
|------|----------|
| `backend` | `spec/design.md`、`spec/backend-plan.md` |
| `frontend` | `spec/design.md`、`spec/frontend-plan.md` |
| `cross` | `spec/design.md`、`spec/api-contract.md`、`spec/backend-plan.md`、`spec/frontend-plan.md` |

`spec/api-contract.md` 只在存在接口协作时创建，且必须作为前后端契约唯一真相源。

`spec/tester-note.md` 是按需生成的测试同事说明。已有 brief 的需求将其保存在同一需求目录，写法见 `rules/tester-note.md`；它不属于上述必需文档，也不作为方案确认或需求阶段同步的前置条件。简单需求不因生成测试说明而强制建立 brief。

### 5.0 cross 双角色执行模式

- cross 需求默认不拆分 Agent；即使前后端代码仓库分离、存在两个 worktree，也由同一个执行 Agent 承担后端角色与前端角色。
- 两端角色按 [执行入口](execution-entry.md)加载；计划只写需求特有的任务、约束、依赖和验证，不复制角色或接口契约。
- 当前需求对应的前端/后端代码位置和分支只从 `__WORKSPACE_ROOT__\briefs\WORKTREE-INDEX.md` 读取，不从 Agent 会话名或交接文档推断。
- 同一 Agent 按实际依赖切换角色，最后核对契约与联调结果；独立任务不强制后端先于前端。

### 5.1 Agent 阶段交接

- 统一标准文件名：`agent-guide.md`
- 每完成一个执行阶段，或暂停、阻塞、切换 Agent/客户端前，自动创建或更新当前交接，无需询问；触发边界和无 brief 任务处理以 `rules/handoff.md` 为准。
- 存放位置：`briefs/<类型>/<需求名>/runtime/agent-guide.md`
- 内容按 `rules/handoff.md` 维护停点、已完成/未完成、Git 现场、验证证据、决策链接和第一步接入动作。代码位置链接全局 WORKTREE-INDEX；允许记录带时间的当时分支与 HEAD 作为历史证据，不另行维护动态定位表；写完核验链接。

历史兼容：

- 已存在的 `需求-agent-guide.md`、`handoff-agent-guide.md` 暂不强制迁移
- 新增或更新时统一使用 `agent-guide.md`
- 执行 Agent 读取时，优先级为：`agent-guide.md` → `需求-agent-guide.md` → `handoff-agent-guide.md`

---

## 六、索引维护

- `briefs/INDEX.md` 登记所有进入复杂需求工作站流程的需求；它不维护开发状态，也不表示方案文档已齐全。
- 实际 worktree、分支和占用情况以 `briefs/WORKTREE-INDEX.md` 与各项目实时 Git 查询为准。
- 简单需求不登记，避免为短期修改维护无价值索引。

### 6.1 工作站状态机

- 工作站状态独立保存在 `briefs/WORKSTATION-STATE.json`；它不替代方案、worktree 或 Git 的事实来源。
- 登记复杂需求后调用 `Register`；用户授权的执行正式开始且有效 worktree 已就绪后调用 `Developing`。不因打开对话或读取资料推进状态。
- 设计 Agent 在用户明确确认方案且必需 brief 文档齐全后，同步为“方案已制定，待开发”。若长会话中漏做，可再次调用同一状态命令补做。
- 只有用户明确确认部署完成、且最后一个关联 worktree 已清理后，才调用 `Released`；单独删除 worktree 不代表上线，也不删除 Git 分支。
- 状态同步只允许向前推进：`待处理 → 方案已制定，待开发 → 开发中 → 已上线`。重复调用为幂等；第一版不提供受控回退。

---

## 七、执行期上下文边界

- 工作区需求简报唯一根目录是 `__WORKSPACE_ROOT__\briefs`。
- 需求目录中的设计、契约与计划可在执行期间更新；执行 Agent 每次开始实现、继续中断任务、切换前后端阶段或发现上下文冲突时，必须重新读取相关最新文件。
- 项目或 worktree 内的 `tasks/` 不属于工作区需求生命周期，禁止作为需求方案入口。
- 项目内 `tasks/lessons.md` 只能作为项目经验教训参考，不能用于推断 `spec/design.md`、`spec/api-contract.md`、`spec/backend-plan.md`、`spec/frontend-plan.md` 的位置。
- `agent-guide.md` 是执行交接标准文件名；历史旧名只做兼容读取，不再作为新文档命名标准。

## 八、执行中的决策变化与提交前对齐

- 执行 Agent 可依据当前代码事实和用户在执行会话中的明确决定调整实现，不需要重新开启设计会话。若变化涉及目标、验收、不改边界、关键方案、接口契约、默认值或旧数据行为，先向用户说明与已审核设计的差异及影响；需要用户选择的业务取舍由用户决定。
- 确认变化后，同步对应事实源：目标/边界/方案决定、DDL、发布范围与顺序归 design；字段/枚举/空值语义归契约；实施步骤与验收验证归计划。交接只记录状态、证据、未完成项和事实源链接。
- 更新 `spec/design.md` 时，写明“原方案 → 当前决定”、原因及影响，使只读 `spec/design.md` 的用户能审核最新方案；其中的行为、默认值和接口摘要须与契约一致。纯实现路径或测试命令变化只更新计划，不必重写设计。
- 用户要求提交或发布前对齐 briefs 时，执行 Agent 以当前 diff 和用户已确认的变化为依据，核对 `spec/design.md`、契约、适用计划及交接文件；修正过期表述，列出尚未确认的偏离。不能为迁就代码而擅自改写未经用户确认的业务目标或验收标准。

## 九、文档改写与旧版本

- 不强制快照，默认不创建。大范围删除或重写前说明涉及文件与范围，由用户决定是否保留旧版本及存放位置。
- 禁止自行生成 `.bak`、`.bak2` 等备份；历史快照与备份保持原位，不自动删除、迁移或作为当前执行输入。
- 脚本化写入采用临时文件校验后原子替换，避免先截断原文件；临时写入文件不是长期备份。

## 十、需求资料目录与读取入口

- 需求根目录 `README.md` 只做导航，生成方式唯一维护在 `rules/brief-readme-template.md`。必须链接 `../../../rules/execution-entry.md`、`../../../rules/task-lifecycle.md` 与 `../../../rules/handoff.md`，供用户主动指定 brief 的对话发现执行身份及按需能力，不依赖项目入口自动发现 工作站。当前设计、契约、计划及维护中的测试说明放 `spec/`；执行交接放 `runtime/agent-guide.md`，兼容的历史交接文件也从 `runtime/` 读取。
- 复杂需求开始实施、切换阶段或继续中断任务时，读取 `spec/design.md`、适用的 `spec/api-contract.md` 与 `spec/*-plan.md`；接手或继续中断任务时还必须读取已有 `runtime/agent-guide.md`，核验实时 Git 和验证适用性。阶段结束按 `rules/handoff.md` 自动维护交接，不以对话记忆替代最新文件。
- `runtime/` 只保存当前需求相关且没有更合适既定位置的执行材料；已存在明确归属时按其职责存放，不重复复制。冲突核验材料放 `runtime/merge-verification/`；首版代码导航仅用户明确触发时放 `runtime/code-review/`。
- 项目源码仍在 worktree，共用知识仍在 `knowledge/`；依赖、浏览器 profile、缓存等临时环境进入 `tmp/`。不得把 `runtime/` 当任意收纳目录。
- `WORKTREE-INDEX.md` 保持全局唯一维护点，需求 README 链接该索引，不复制维护代码位置与分支。
- 简单需求不补齐复杂方案。若没有需求目录却需要保存运行材料，先申请建立对应类型的最小需求容器与 README/runtime；不自动登记为复杂需求或推进状态。
- 上述固定目录模式仅随已授权的对应任务创建，不预建空文件。其他新增目录依 `STRUCTURE.md` 先申请。

