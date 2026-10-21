# Scripts Index

> 本文件是 `__WORKSPACE_ROOT__\scripts` 的入口索引。需要使用脚本或调整脚本结构时，先读本文件。

---

## 一、目录职责

`__WORKSPACE_ROOT__\scripts` 只存放：

- 可执行脚本入口（`.cmd` / `.ps1`）
- 可选本地数据库目标配置（启用 db-analysis 后的 `db-targets.json`）

不存放：

- 需求方案
- 项目级知识库
- 项目源码

---

## 二、当前文件说明

| 文件 | 用途 | 何时使用 |
|------|------|----------|
| `git-dashboard.cmd` | Windows 入口，查看多项目/worktree 看板 | 想快速查看分支状态、测试分支占用、脏 worktree |
| `git-dashboard.ps1` | Git 看板主脚本 | 调整看板逻辑、字段、过滤规则时 |
| `new-worktree.cmd` | Windows 入口，按注册表创建 worktree | 新增需求 worktree |
| `new-worktree.ps1` | Worktree 创建主脚本 | 调整创建流程或分支规则时 |
| `db-analysis.cmd` | 可选：Windows 入口，查询 MySQL、PostgreSQL/Hologres 或测试 Redis | 启用 db-analysis 后查询数据库或 Redis |
| `db-analysis.ps1` | 可选：工作区 wrapper，转调本地 `skills/db-analysis` 脚本 | 启用 db-analysis 后，调整默认配置路径时 |
| `db-targets.json` | 可选：本地数据库目标配置 | 启用 db-analysis 后，维护常用数据库连接目标 |
| `remove-worktree.cmd` | Windows 入口，受控删除 worktree | 删除需求 worktree |
| `remove-worktree.ps1` | Worktree 删除主脚本 | 调整删除前检查或残留清理逻辑时 |
| `sync-workstation-state.ps1` | 复杂需求登记与阶段同步 | Register、DesignReady、Developing、Released；不自动认定部署成功 |
| `publish-to-branch.cmd` | Windows 入口，将当前功能分支的指定文件提交、推送并受控合入指定远端分支 | 功能完成后提交并合入测试/集成分支 |
| `publish-to-branch.ps1` | 分支发布与冲突核验主脚本 | 调整提交、分支切换、合并、三方输入冻结、核验与推送时 |

---

## 三、使用约定

### 3.1 Git 看板

常用命令：

```powershell
.\scripts\git-dashboard.cmd -Board
.\scripts\git-dashboard.cmd -Detailed
```

约束：

- 项目列表只从 `__WORKSPACE_ROOT__\rules\worktree.md` 读取。
- 看板是只读查询工具，不负责创建、删除、切换 worktree。
- Agent 默认用 `-Board`，仅展示结果与必要标题；明确要求最近提交才用 `-Detailed`。
- 脚本内部使用 `GIT_OPTIONAL_LOCKS=0`，避免查询时主动产生 `index.lock`。

### 3.2 新增 worktree

常用命令：

```powershell
.\scripts\new-worktree.cmd -ProjectKey project-api -Name my-feature -Type feature -BaseBranch master -Preview
.\scripts\new-worktree.cmd -ProjectKey project-api -Name my-feature -Type feature -BaseBranch master
```

约束：

- 项目列表从 `rules/worktree.md` 的根项目注册表读取。
- worktree 路径固定为 `__WORKSPACE_ROOT__\worktrees\<项目>-worktree\<需求名>`。
- 分支名固定为 `feature/<需求名>` 或 `hotfix/<需求名>`。
- `-Name` 必须是 kebab-case。
- Git 生命周期入口依赖 PowerShell 7；缺失时报错，不回退到 5.1。
- 默认 master 更新要求根仓库干净，只允许快进；不执行个人工作站式的自动清理和硬重置。
- Agent 调用使用 `-OutputFormat Json`；复杂需求传 `-RequirementKey <type:name> -Role backend|frontend`，由脚本精确同步 WORKTREE-INDEX；返回 partial 时先修复索引，不启动实施。

### 3.3 数据库分析（可选）

本节只有初始化工作站时传入 `-IncludeDbAnalysis` 后才适用。未安装时，数据库入口和 `skills/db-analysis/SKILL.md` 不存在；Agent 应说明可选能力未启用，不要自行猜测入口。

常用命令：

```powershell
.\scripts\db-analysis.cmd -ListTargets
.\scripts\db-analysis.cmd -Target sample-local -Action ping
.\scripts\db-analysis.cmd -Target sample-local -Action tables
.\scripts\db-analysis.cmd -Target sample-local -Action columns -Table order_subscribe
.\scripts\db-analysis.cmd -Target sample-local -Action create -Table order_subscribe
pwsh -NoProfile -File .\scripts\db-analysis.ps1 -Target sample-local -Database app_test -Action query -Sql 'SELECT COUNT(*) FROM order_subscribe'
```

PostgreSQL / Hologres targets require an explicit database and schema:

```powershell
.\scripts\db-analysis.cmd -Target example-postgresql-readonly -Action databases
.\scripts\db-analysis.cmd -Target example-postgresql-readonly -Database app_prod -Action schemas
.\scripts\db-analysis.cmd -Target example-postgresql-readonly -Database app_prod -Schema public -Action tables
pwsh -NoProfile -File .\scripts\db-analysis.ps1 -Target example-postgresql-readonly -Database app_prod -Schema public -Action query -Sql 'SELECT COUNT(*) FROM public.orders'
```

约束：

- 支持本机 `mysql.exe` 及 `psql.exe`；目标以 `type: mysql` 或 `type: postgresql` 区分。Hologres 使用 PostgreSQL 协议。
- 自定义 SQL 优先从 PowerShell 7 直接调用 .ps1，以单引号保留标识符双引号，不经 .cmd 转发。本轮仅校正文档，不改现有数据库实现、目标或治理策略，不同步 Col 的测试写入能力。
- 工作区入口默认读取 `__WORKSPACE_ROOT__\scripts\db-targets.json`，也可显式传 `-ConfigPath`。
- 实际查询逻辑来自工作区内 `skills/db-analysis/scripts/db-analysis.ps1`，不依赖用户级 Codex 配置。
- 默认适用于本机已安装 MySQL 客户端、已开白或本地可直连的库。
- 口令认证目标优先配置 `clientDefaultsFile`，指向本机私有 MySQL option file；脚本通过 `--defaults-extra-file` 读取，避免将密码放入命令行参数。`password` 仅作为旧配置兼容字段。
- 若现有本地 `db-targets.json` 仍使用 `password`，可执行 `./scripts/migrate-db-client-credentials.ps1 -Preview` 查看迁移预案，确认后去掉 `-Preview`。
- 这是查询和分析工具，不负责 DDL 变更或批量写操作；生产读端默认连接超时 15 秒、查询超时 10 分钟、最多返回 1000 行；允许 `SELECT *`，但仍拒绝敏感字段、行锁和诊断表查询。每个目标必须在本地 `allowedDatabases` 中显式列出可查询 schema；`-Action databases` 仅显示该白名单，`tables`、`columns`、`create`、`query` 都必须传入一个已批准的 `-Database`。仅显式标记为 `environment: test` 的目标可使用高权限账号，且仍只允许读取 action 与只读 SQL。
- 每次连接目标都会先检查 `SHOW GRANTS FOR CURRENT_USER()`，发现写权限或管理权限会拒绝继续。
- PostgreSQL / Hologres 使用 `pgPassFile` 保存本机凭证，并在连接前检查超级用户、数据库/Schema 创建以及表 DML 能力；Holo 查询必须配置 `allowedDatabases`、`allowedSchemas` 并显式使用 `schema.table`。`create` 动作默认不对 Holo 开放。
- 测试 Redis 使用 `redis-cli` 和本地私有密码文件；只开放 `ping`、`key-info`、`get`、`hget`、单页 `scan`，不开放任意命令。

### 3.4 删除 worktree

常用命令：

```powershell
.\scripts\remove-worktree.cmd -WorktreePath "__WORKSPACE_ROOT__\worktrees\<项目>-worktree\<需求名>" -Preview
.\scripts\remove-worktree.cmd -WorktreePath "__WORKSPACE_ROOT__\worktrees\<项目>-worktree\<需求名>"
.\scripts\remove-worktree.cmd -WorktreePath "__WORKSPACE_ROOT__\worktrees\<项目>-worktree\<需求名>" -Force
```

约束：

- 只能删除 `__WORKSPACE_ROOT__\worktrees\<项目>-worktree\<需求名>` 这种具体 worktree 子目录。
- 默认先检查 Git dirty 状态；若存在未提交或未跟踪变更会拒绝删除，除非人工明确传入 `-Force`。
- 删除时保留 Git 分支，不执行 `git branch -D`。
- 若 worktree 已进入 Git 半删除状态，`-Force` 会进入残留清理模式，继续清理空目录和 Git worktree 元数据。
- Agent 使用 `-Preview -OutputFormat Json`，人工确认后用 `-Confirm -OutputFormat Json`。Force 不是免确认；关联需求同时传 RequirementKey 与 Role，映射不一致则拒绝，索引失败返回 partial。清理不自动标记上线。

### 结构化结果与状态同步

创建/删除脚本的 JSON 返回 `workflow-result.v1`：operation、mode、outcome、exitCode、effects、state、humanActionRequired、nextAction、error。仅预览不修改 Git、目录或索引。读取 JSON 本身不是执行授权。

```powershell
.\scripts\sync-workstation-state.ps1 -Action Register -RequirementKey backend:my-feature
.\scripts\sync-workstation-state.ps1 -Action DesignReady -RequirementKey backend:my-feature
.\scripts\sync-workstation-state.ps1 -Action Developing -RequirementKey backend:my-feature
# 仅用户确认部署完成、且最后一个 worktree 已清理后
.\scripts\sync-workstation-state.ps1 -Action Released -RequirementKey backend:my-feature
```

索引先登记；DesignReady 校验 spec 文档，Developing 校验有效目录，Released 校验无活动目录。实际 Git 仍须核验；状态只单向推进，重复动作幂等，不依赖客户端。

### 3.5 发布当前功能分支到指定分支

```powershell
.\scripts\publish-to-branch.cmd `
  -ProjectPath "__WORKSPACE_ROOT__\worktrees\<项目>-worktree\<需求名>" `
  -TargetBranch test `
  -Files "src\path\FileA.java,src\path\FileB.java" `
  -CommitMessage "feat(scope): describe change" `
  -Preview
```

确认预览后，使用相同参数去掉 `-Preview` 执行。

若 Git 合并发生冲突，脚本会冻结三方输入并停在目标分支。人工解决、`git add` 后，使用相同参数继续：

```powershell
.\scripts\publish-to-branch.cmd <原有参数> -Mode VerifyConflict
.\scripts\publish-to-branch.cmd <原有参数> -Mode CompleteConflict -ConfirmConflictCompletion

# Java/POM 冲突：必须提供当前 worktree 的 Maven 模块
.\scripts\publish-to-branch.cmd <原有参数> -Mode VerifyConflict -CompileModules <模块1,模块2> -MavenSettings <settings文件>

# B 类冲突：填写 artifact 中生成的 manual-acceptance.md 后继续
.\scripts\publish-to-branch.cmd <原有参数> -Mode VerifyConflict -ManualAcceptanceFile <已填写文件路径>

# 仅当本地 Git Hook 误拦截已通过核验的 CompleteConflict：人工创建批准文件后才可使用
.\scripts\publish-to-branch.cmd <原有参数> -Mode CompleteConflict -ConfirmConflictCompletion -UseHumanCompletionApproval
```

- `TargetBranch` 由调用方指定；脚本不固定测试分支名，也不自动创建远端目标分支。
- `Files` 使用逗号分隔的仓库相对路径，且当前所有未提交文件必须与该清单完全一致。
- 脚本先以 `git push -u origin <当前分支>` 推送源分支，修正误跟踪默认分支的 upstream。
- 若上一次执行已完成源分支 commit/push 但脚本在后续步骤前中断，重新以相同参数执行时，脚本会在工作区干净且 HEAD 提交信息等于 `-CommitMessage` 的情况下从现有源分支提交继续。
- 脚本按 Git 退出码判断失败，不把 `git push/fetch` 写入 stderr 的正常进度信息视为失败。
- 无冲突时，目标分支成功推送后才切回源分支。
- 冲突材料进入所属需求 `runtime/merge-verification/`；旧 artifacts 指针只兼容读取。只读预案就核验需求归属；无法定位时先取得最小需求容器授权，再传 `-BriefPath`，不自动建需求。
- A 类无重叠纯新增执行四项行多重集对账；重叠新增归 B，人类决策记录可选；Java/POM 仍必须编译。核验冻结暂存树，完成前检查未被修改；目标 push 失败可按记录继续，不重复提交。
- `-Files` 支持斜杠与反斜杠。多行提交说明用 `-CommitMessageFile`，与 CommitMessage 二选一；已有源提交的恢复比较使用 UTF-8 并统一换行。编译从当前 worktree 执行，settings 相对该目录解析。
- 分支占用、远端拒绝、目标不存在或任一 Git 失败均停止并要求人工决定；不强制处理、不自动回滚。
- `-UseHumanCompletionApproval` 是极窄的人工授权例外：仅 `CompleteConflict` 可用，且必须由人手工创建 `governance\agent-guard\local-git-hook-bypass-approval.json`（内容严格为示例中的 `enabled` 与 `scope`）。它只让受保护脚本在本次 merge 的 `commit`、`push` 使用受保护的空本地 hooks 目录；远端 CI、分支保护、冲突核验、编译证据和恢复源分支均不会跳过。使用记录会追加到核验报告；操作后由人手工删除批准文件。禁止手写 `--no-verify`、`core.hooksPath` 或环境变量绕过。
- 详细规则见 `rules/merge-verification.md`；不使用测试分支作为正确性基线，也不替代上线前 Review。


## 四、Agent 路由

当意图是以下场景时，优先读取本文件：

- 查看当前脚本有哪些
- 判断某个脚本该怎么用
- 查询数据库结构或执行只读分析 SQL（仅启用 db-analysis 后）
- 修改脚本结构
- 调整 Git 看板逻辑

路由建议：

- 查看 Git/worktree 状态：执行 `.\scripts\git-dashboard.cmd -Board`
- 新增 worktree：先执行 `.\scripts\new-worktree.cmd -ProjectKey <key> -Name <需求名> -Preview`，确认后再执行不带 `-Preview` 的创建命令
- 查询数据库目标：若已启用 db-analysis，执行 `.\scripts\db-analysis.cmd -ListTargets`
- 查询数据库结构：若已启用 db-analysis，执行 `.\scripts\db-analysis.cmd -Target <name> -Action tables|columns|create`
- 删除 worktree：先执行 `.\scripts\remove-worktree.cmd -WorktreePath <worktree路径> -Preview`，确认后再执行不带 `-Preview` 的删除命令
- 提交并合入指定测试/集成分支：先执行 `.\scripts\publish-to-branch.cmd ... -Preview`，确认后再去掉 `-Preview`；不要手写 checkout / merge / push 绕过脚本
- 合并冲突后核验：读取 `rules/merge-verification.md`，按 `VerifyConflict` → `CompleteConflict` 继续；不得绕过脚本直接提交 merge

---

## 五、结构边界

当前 `scripts/` 不需要再细分子目录。

原因：

- 当前文件数量少
- 只有少量脚本：Git 看板、worktree 维护，以及可选数据库分析
- 再拆 `git/`、`workspace/` 会增加路径层级，但不会明显降低复杂度

当脚本数量继续增长，再考虑拆分：

- `scripts/git/`
- `scripts/db/`
- `scripts/workspace/`
- `scripts/maintenance/`
