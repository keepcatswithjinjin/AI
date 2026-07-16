# Scripts Index

> 本文件是 `__WORKSPACE_ROOT__\scripts` 的入口索引。需要使用脚本或调整脚本结构时，先读本文件。

---

## 一、目录职责

`__WORKSPACE_ROOT__\scripts` 只存放两类内容：

- 可执行脚本入口（`.cmd` / `.ps1`）
- 本地工作台状态文件（`workspace-state.json`）

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
| `db-analysis.cmd` | Windows 入口，查询 MySQL 库结构和自定义 SQL | 想快速查库、查表、查字段、看建表语句 |
| `db-analysis.ps1` | Col 快捷 wrapper，转调全局 `db-analysis` skill 脚本 | 调整 Col 默认配置路径时 |
| `db-targets.json` | 本地数据库目标配置 | 维护常用数据库连接目标 |
| `open-workspace.cmd` | Windows 入口，按状态恢复本地工作台 | 想一键打开多个 agent 工作目录 |
| `open-workspace.ps1` | 工作台恢复主脚本 | 调整恢复逻辑、打开方式、resume 规则时 |
| `register-workspace.cmd` | Windows 入口，登记当前 worktree 到工作台状态 | 把当前执行目录和指定 session 名登记到工作台 |
| `register-workspace.ps1` | 工作台登记主脚本 | 调整状态写入规则、字段结构时 |
| `workspace-state.json` | 本地 agent 工作台状态 | 手工维护需要恢复的 session 列表 |

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

### 3.2 数据库分析

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
- Col 入口默认读取 `__WORKSPACE_ROOT__\scripts\db-targets.json`，也可显式传 `-ConfigPath`。
- 实际查询逻辑来自全局 Codex skill：`%USERPROFILE%\.codex\skills\db-analysis\scripts\db-analysis.ps1`。
- 默认适用于本机已安装 MySQL 客户端、已开白或本地可直连的库。
- `password` 可留空；若后续改成口令认证，再补到本地配置。
- 这是查询和分析工具，不负责 DDL 变更或批量写操作；生产读端默认连接超时 15 秒、查询超时 10 分钟、最多返回 1000 行；允许 `SELECT *`，但仍拒绝敏感字段、行锁和诊断表查询。
- 每次连接目标都会先检查 `SHOW GRANTS FOR CURRENT_USER()`，发现写权限或管理权限会拒绝继续。

### 3.3 工作台恢复

常用命令：

```powershell
.\scripts\open-workspace.cmd
.\scripts\open-workspace.cmd -WhatIf -All
```

约束：

- `workspace-state.json` 由人工维护和脚本更新共同完成。
- 默认只打开 `enabled=true` 的 session。
- 工作台恢复使用 `workspace-state.json` 中登记的 `sessionName`。
- `sessionId` 当前仅作预留字段，可为空，不参与当前恢复逻辑。
- 注册工作台时，`sessionName` 由用户显式提供，用于后续 resume。
- `-WhatIf` 只做预览，不打开窗口；会列出每个 session 的状态和错误。
- 实际恢复会先全量校验路径和工具；只要存在错误，全部停止打开，避免半恢复。
- 删除 worktree 前必须同步检查 `workspace-state.json`，并在用户确认后清理对应 session 记录；具体规则见 `rules/worktree.md`。

### 3.4 当前目录登记到工作台

常用命令：

```powershell
& '__WORKSPACE_ROOT__\scripts\register-workspace.cmd' -Tool codex -SessionName "my-session"
& '__WORKSPACE_ROOT__\scripts\register-workspace.cmd' -Tool claude -SessionName "my-session"
```

约束：

- 在当前 git worktree 目录执行。
- 从 worktree 内调用时，优先使用绝对路径 `__WORKSPACE_ROOT__\scripts\register-workspace.cmd`。
- `-SessionName` 必填，取值以用户提供的可恢复 session 名为准。
- 不要求 `sessionName` 等于分支名，也不强制要求先执行 `/rename`。
- `-SessionId` 可选，当前仅预留，不作为恢复主链路。
- 同一路径再次登记时，更新原记录，不重复追加。

---

## 四、Agent 路由

当意图是以下场景时，优先读取本文件：

- 查看当前脚本有哪些
- 判断某个脚本该怎么用
- 查询数据库结构或执行只读分析 SQL
- 修改脚本结构
- 调整工作台恢复逻辑
- 调整 Git 看板逻辑

路由建议：

- 查看 Git/worktree 状态：执行 `.\scripts\git-dashboard.cmd -Board`
- 查询数据库目标：执行 `.\scripts\db-analysis.cmd -ListTargets`
- 查询数据库结构：执行 `.\scripts\db-analysis.cmd -Target <name> -Action tables|columns|create`
- 预览工作台恢复：执行 `.\scripts\open-workspace.cmd -WhatIf -All`
- 实际恢复工作台：执行 `.\scripts\open-workspace.cmd`
- 注册当前工作台：执行 `.\scripts\register-workspace.cmd -Tool <codex|claude> -SessionName <可恢复session名>`

---

## 五、结构边界

当前 `scripts/` 不需要再细分子目录。

原因：

- 当前文件数量少
- 只有三类脚本：Git 看板、数据库分析、工作台恢复
- 再拆 `git/`、`workspace/` 会增加路径层级，但不会明显降低复杂度

当脚本数量继续增长，再考虑拆分：

- `scripts/git/`
- `scripts/db/`
- `scripts/workspace/`
- `scripts/maintenance/`
