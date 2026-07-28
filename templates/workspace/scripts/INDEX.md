# Scripts Index

> 本文件是 `__WORKSPACE_ROOT__\scripts` 的入口索引。需要使用脚本或调整脚本结构时，先读本文件。

---

## 一、目录职责

`__WORKSPACE_ROOT__\scripts` 存放：

- 可执行脚本入口（`.cmd` / `.ps1`）
- 本地工作台状态文件（`workspace-state.json`）
- 本地数据库目标配置（`db-targets.json`，由 example 复制后本机维护）

不存放：需求方案、项目级知识库、项目源码、真实数据库凭据的模板外副本。

---

## 二、当前文件说明

| 文件 | 用途 | 何时使用 |
|------|------|----------|
| `git-dashboard.cmd` | Windows 入口，查看多项目/worktree 看板 | 想快速查看分支状态、测试分支占用、脏 worktree |
| `git-dashboard.ps1` | Git 看板主脚本 | 调整看板逻辑、字段、过滤规则时 |
| `new-worktree.cmd` | Windows 入口，按注册表创建 worktree，并按需写入 Serena 配置 | 新增需求 worktree |
| `new-worktree.ps1` | Worktree 创建主脚本 | 调整创建流程、分支规则或 Serena 写入逻辑时 |
| `remove-worktree.cmd` | Windows 入口，受控删除 worktree 并清理可归属 Serena 索引 | 删除需求 worktree |
| `remove-worktree.ps1` | Worktree 删除主脚本 | 调整删除前检查、workspace-state 或 Serena 清理逻辑时 |
| `db-analysis.cmd` | Windows 入口，查询 MySQL 库结构和自定义 SQL | 想快速查库、查表、查字段、看建表语句 |
| `db-analysis.ps1` | 工作区快捷 wrapper，转调全局 `db-analysis` skill 脚本 | 调整默认配置路径时 |
| `db-targets.json` | 本地数据库目标配置 | 维护常用数据库连接目标，禁止提交真实凭据 |
| `open-workspace.cmd` | Windows 入口，按状态恢复本地工作台 | 想一键打开多个 agent 工作目录 |
| `open-workspace.ps1` | 工作台恢复主脚本 | 调整恢复逻辑、打开方式、resume 规则时 |
| `register-workspace.cmd` | Windows 入口，登记当前 worktree 到工作台状态 | 把当前执行目录和指定 session 名登记到工作台 |
| `register-workspace.ps1` | 工作台登记主脚本 | 调整状态写入规则、字段结构时 |
| `workspace-state.json` | 本地 agent 工作台状态 | 手工维护需要恢复的 session 列表 |

---

## 三、使用约定

### 3.1 Git 看板

```powershell
.\scripts\git-dashboard.cmd -Board
.\scripts\git-dashboard.cmd -Detailed
```

- 项目列表只从 `__WORKSPACE_ROOT__\rules\worktree.md` 读取。
- 看板是只读查询工具，不负责创建、删除、切换 worktree。
- 脚本内部使用 `GIT_OPTIONAL_LOCKS=0`，避免查询时主动产生 `index.lock`。

### 3.2 新增 worktree

```powershell
.\scripts\new-worktree.cmd -ProjectKey project-api -Name my-feature -Type feature -BaseBranch master -Serena Ask -Preview
.\scripts\new-worktree.cmd -ProjectKey project-api -Name my-feature -Type feature -BaseBranch master -Serena Enable
```

- 项目列表从 `rules/worktree.md` 的根项目注册表读取。
- worktree 路径固定为 `__WORKSPACE_ROOT__\worktrees\<项目>-worktree\<需求名>`。
- 分支名固定为 `feature/<需求名>` 或 `hotfix/<需求名>`。
- `-Name` 必须是 kebab-case。
- `-Serena Enable` 会在新 worktree 根目录写入项目级 `.codex/config.toml`。
- Serena 可执行文件按顺序解析：`-SerenaExe <path>`、`SERENA_EXE` 环境变量、PATH 中的 `serena`。
- Java / JRE / JDK / JDTLS 路径由使用者按自己的机器和项目配置，不在模板中写死。

### 3.3 删除 worktree

```powershell
.\scripts\remove-worktree.cmd -WorktreePath "__WORKSPACE_ROOT__\worktrees\<项目>-worktree\<需求名>" -Preview
.\scripts\remove-worktree.cmd -WorktreePath "__WORKSPACE_ROOT__\worktrees\<项目>-worktree\<需求名>"
.\scripts\remove-worktree.cmd -WorktreePath "__WORKSPACE_ROOT__\worktrees\<项目>-worktree\<需求名>" -Force -StopSerenaProcesses
```

- 只能删除 `__WORKSPACE_ROOT__\worktrees\<项目>-worktree\<需求名>` 这种具体 worktree 子目录。
- 默认先检查 Git dirty 状态；若存在未提交或未跟踪变更会拒绝删除，除非人工明确传入 `-Force`。
- 删除时保留 Git 分支，不执行 `git branch -D`。
- 若匹配到 `workspace-state.json` 中的 session，会同步清理该恢复项。
- 若检测到 worktree 启用了 Serena，会清理用户级 Serena `projects` 注册项和可明确归属该 worktree 的 JDTLS workspace 索引目录。
- 若 Serena/JDTLS 进程仍占用该 worktree 或索引，预览会列出匹配进程和可停止进程；默认不停止进程，只有人工确认后传入 `-StopSerenaProcesses` 才会停止可明确归属 Serena/JDTLS 且排除当前清理脚本自身的进程。
- Serena 的 `sharedIndex` 是跨项目共享缓存，删除单个 worktree 时必须保留；logs 默认保留。

### 3.4 数据库分析

```powershell
.\scripts\db-analysis.cmd -ListTargets
.\scripts\db-analysis.cmd -Target sample-local -Action ping
.\scripts\db-analysis.cmd -Target sample-local -Action tables -Database app_db
.\scripts\db-analysis.cmd -Target sample-local -Action columns -Database app_db -Table order_subscribe
.\scripts\db-analysis.cmd -Target sample-local -Action create -Database app_db -Table order_subscribe
.\scripts\db-analysis.cmd -Target sample-local -Action query -Database app_db -Sql "SELECT COUNT(*) FROM order_subscribe"
```

- 当前脚本只支持 `mysql.exe`。
- 入口默认读取 `__WORKSPACE_ROOT__\scripts\db-targets.json`，也可显式传 `-ConfigPath`。
- 实际查询逻辑来自全局 Codex skill：`%USERPROFILE%\.codex\skills\db-analysis\scripts\db-analysis.ps1`。
- 这是查询和分析工具，不负责 DDL 变更或批量写操作。
- 每个目标必须在本地 `allowedDatabases` 中显式列出可查询 schema；`-Action databases` 仅显示该白名单，`tables`、`columns`、`create`、`query` 都必须传入一个已批准的 `-Database`。
- 仅显式标记为 `environment: test` 的目标可使用高权限账号，且仍只允许读取 action 与只读 SQL。
- 每次连接目标都会先检查 `SHOW GRANTS FOR CURRENT_USER()`；生产目标发现写权限或管理权限会拒绝继续。

### 3.5 工作台恢复

```powershell
.\scripts\open-workspace.cmd
.\scripts\open-workspace.cmd -WhatIf -All
```

- `workspace-state.json` 由人工维护和脚本更新共同完成。
- 默认只打开 `enabled=true` 的 session。
- 工作台恢复使用 `workspace-state.json` 中登记的 `sessionName`。
- 删除 worktree 前必须同步检查 `workspace-state.json`，并在用户确认后清理对应 session 记录；具体规则见 `rules/worktree.md`。

### 3.6 当前目录登记到工作台

```powershell
& '__WORKSPACE_ROOT__\scripts\register-workspace.cmd' -Tool codex -SessionName "my-session"
& '__WORKSPACE_ROOT__\scripts\register-workspace.cmd' -Tool claude -SessionName "my-session"
```

- 在当前 git worktree 目录执行。
- 从 worktree 内调用时，优先使用绝对路径 `__WORKSPACE_ROOT__\scripts\register-workspace.cmd`。
- `-SessionName` 必填，取值以用户提供的可恢复 session 名为准。
- 同一路径再次登记时，更新原记录，不重复追加。

---

## 四、Agent 路由

当意图是以下场景时，优先读取本文件：

- 查看当前脚本有哪些
- 判断某个脚本该怎么用
- 创建或删除 worktree
- 查询数据库结构或执行只读分析 SQL
- 修改脚本结构
- 调整工作台恢复逻辑
- 调整 Git 看板逻辑

路由建议：

- 查看 Git/worktree 状态：执行 `.\scripts\git-dashboard.cmd -Board`
- 新增 worktree：先执行 `.\scripts\new-worktree.cmd -ProjectKey <key> -Name <需求名> -Preview`，确认后再执行不带 `-Preview` 的创建命令
- 删除 worktree：先执行 `.\scripts\remove-worktree.cmd -WorktreePath <worktree路径> -Preview`，确认后再执行不带 `-Preview` 的删除命令
- 查询数据库目标：执行 `.\scripts\db-analysis.cmd -ListTargets`
- 查询数据库结构：执行 `.\scripts\db-analysis.cmd -Target <name> -Action tables|columns|create -Database <schema>`
- 预览工作台恢复：执行 `.\scripts\open-workspace.cmd -WhatIf -All`
- 实际恢复工作台：执行 `.\scripts\open-workspace.cmd`
- 注册当前工作台：执行 `.\scripts\register-workspace.cmd -Tool <codex|claude> -SessionName <可恢复session名>`

---

## 五、结构边界

当前 `scripts/` 不需要再细分子目录。脚本数量继续增长后，再考虑拆分 `scripts/git/`、`scripts/db/`、`scripts/workspace/`、`scripts/maintenance/`。
