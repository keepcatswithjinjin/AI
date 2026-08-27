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
| `new-worktree.cmd` | Windows 入口，按注册表创建 worktree，并按需写入 Serena 配置 | 新增需求 worktree |
| `new-worktree.ps1` | Worktree 创建主脚本 | 调整创建流程、分支规则或 Serena 写入逻辑时 |
| `db-analysis.cmd` | 可选：Windows 入口，查询 MySQL 库结构和自定义 SQL | 启用 db-analysis 后，想快速查库、查表、查字段、看建表语句 |
| `db-analysis.ps1` | 可选：工作区快捷 wrapper，转调全局 `db-analysis` skill 脚本 | 启用 db-analysis 后，调整默认配置路径时 |
| `db-targets.json` | 可选：本地数据库目标配置 | 启用 db-analysis 后，维护常用数据库连接目标 |
| `remove-worktree.cmd` | Windows 入口，受控删除 worktree 并清理可归属 Serena 索引 | 删除需求 worktree |
| `remove-worktree.ps1` | Worktree 删除主脚本 | 调整删除前检查或 Serena 清理逻辑时 |
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
- 脚本内部使用 `GIT_OPTIONAL_LOCKS=0`，避免查询时主动产生 `index.lock`。

### 3.2 新增 worktree

常用命令：

```powershell
.\scripts\new-worktree.cmd -ProjectKey project-api -Name my-feature -Type feature -BaseBranch master -Serena Ask -Preview
.\scripts\new-worktree.cmd -ProjectKey project-api -Name my-feature -Type feature -BaseBranch master -Serena Enable
```

约束：

- 项目列表从 `rules/worktree.md` 的根项目注册表读取。
- worktree 路径固定为 `__WORKSPACE_ROOT__\worktrees\<项目>-worktree\<需求名>`。
- 分支名固定为 `feature/<需求名>` 或 `hotfix/<需求名>`。
- `-Name` 必须是 kebab-case。
- `-Serena Enable` 会在新 worktree 根目录写入项目级 `.codex/config.toml`。
- Serena 命令必须使用已验证的可执行文件绝对路径，不自动回退到裸 `serena`。

### 3.3 数据库分析（可选）

本节只有初始化工作站时传入 `-IncludeDbAnalysis` 后才适用。未安装时，`scripts\db-analysis.cmd`、`scripts\db-analysis.ps1` 和 `scripts\db-targets.example.json` 不存在；Agent 应说明 db-analysis 可选能力未启用，不要自行猜测数据库入口。

常用命令：

```powershell
.\scripts\db-analysis.cmd -ListTargets
.\scripts\db-analysis.cmd -Target sample-local -Action ping
.\scripts\db-analysis.cmd -Target sample-local -Action tables
.\scripts\db-analysis.cmd -Target sample-local -Action columns -Table order_subscribe
.\scripts\db-analysis.cmd -Target sample-local -Action create -Table order_subscribe
.\scripts\db-analysis.cmd -Target sample-local -Action query -Sql "SELECT COUNT(*) FROM order_subscribe"
```

约束：

- 当前脚本只支持 `mysql.exe`。
- 工作区入口默认读取 `__WORKSPACE_ROOT__\scripts\db-targets.json`，也可显式传 `-ConfigPath`。
- 实际查询逻辑来自全局 Codex skill：`%USERPROFILE%\.codex\skills\db-analysis\scripts\db-analysis.ps1`。
- 默认适用于本机已安装 MySQL 客户端、已开白或本地可直连的库。
- 口令认证目标优先配置 `clientDefaultsFile`，指向本机私有 MySQL option file；脚本通过 `--defaults-extra-file` 读取，避免将密码放入命令行参数。`password` 仅作为旧配置兼容字段。
- 若现有本地 `db-targets.json` 仍使用 `password`，可执行 `./scripts/migrate-db-client-credentials.ps1 -Preview` 查看迁移预案，确认后去掉 `-Preview`。
- 这是查询和分析工具，不负责 DDL 变更或批量写操作；生产读端默认连接超时 15 秒、查询超时 10 分钟、最多返回 1000 行；允许 `SELECT *`，但仍拒绝敏感字段、行锁和诊断表查询。每个目标必须在本地 `allowedDatabases` 中显式列出可查询 schema；`-Action databases` 仅显示该白名单，`tables`、`columns`、`create`、`query` 都必须传入一个已批准的 `-Database`。仅显式标记为 `environment: test` 的目标可使用高权限账号，且仍只允许读取 action 与只读 SQL。
- 每次连接目标都会先检查 `SHOW GRANTS FOR CURRENT_USER()`，发现写权限或管理权限会拒绝继续。

### 3.4 删除 worktree

常用命令：

```powershell
.\scripts\remove-worktree.cmd -WorktreePath "__WORKSPACE_ROOT__\worktrees\<项目>-worktree\<需求名>" -Preview
.\scripts\remove-worktree.cmd -WorktreePath "__WORKSPACE_ROOT__\worktrees\<项目>-worktree\<需求名>"
.\scripts\remove-worktree.cmd -WorktreePath "__WORKSPACE_ROOT__\worktrees\<项目>-worktree\<需求名>" -Force -StopSerenaProcesses
```

约束：

- 只能删除 `__WORKSPACE_ROOT__\worktrees\<项目>-worktree\<需求名>` 这种具体 worktree 子目录。
- 默认先检查 Git dirty 状态；若存在未提交或未跟踪变更会拒绝删除，除非人工明确传入 `-Force`。
- 删除时保留 Git 分支，不执行 `git branch -D`。
- 若检测到 worktree 启用了 Serena，会清理用户级 Serena `projects` 注册项和可明确归属该 worktree 的 JDTLS workspace 索引目录。
- 若 Serena/JDTLS 进程仍占用该 worktree 或索引，预览会列出匹配进程和可停止进程；默认不停止进程，只有人工确认后传入 `-StopSerenaProcesses` 才会停止可明确归属 Serena/JDTLS 且排除当前清理脚本自身的进程。
- 若 worktree 已进入 Git 半删除状态，`-Force` 会进入残留清理模式，继续清理空目录、Git worktree 元数据和 Serena 可归属索引。
- Serena 的 `sharedIndex` 是跨项目共享缓存，删除单个 worktree 时必须保留。
- Serena logs 默认保留，用于审计与排障。

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
```

- `TargetBranch` 由调用方指定；脚本不固定测试分支名，也不自动创建远端目标分支。
- `Files` 使用逗号分隔的仓库相对路径，且当前所有未提交文件必须与该清单完全一致。
- 脚本先以 `git push -u origin <当前分支>` 推送源分支，修正误跟踪默认分支的 upstream。
- 若上一次执行已完成源分支 commit/push 但脚本在后续步骤前中断，重新以相同参数执行时，脚本会在工作区干净且 HEAD 提交信息等于 `-CommitMessage` 的情况下从现有源分支提交继续。
- 脚本按 Git 退出码判断失败，不把 `git push/fetch` 写入 stderr 的正常进度信息视为失败。
- 无冲突时，目标分支成功推送后才切回源分支。
- 冲突时，脚本冻结 Git stage 1/base、stage 2/ours、stage 3/theirs 与冲突态原文到 `artifacts/merge-verification/`；解决后必须 `VerifyConflict`，通过后才可显式 `CompleteConflict`。
- A 类纯新增冲突执行四项行多重集对账；B 类必须有人工决策记录；Java/POM 冲突必须通过 `mvn -pl ... -am compile`。
- 分支占用、远端拒绝、目标不存在或任一 Git 失败均停止并要求人工决定；不强制处理、不自动回滚。
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
- 创建 worktree 并启用 Serena：按 `rules/worktree.md` 写入项目级 `.codex/config.toml`，Serena 命令必须使用已验证的可执行文件绝对路径，不自动回退到裸 `serena`
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
