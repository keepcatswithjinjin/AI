# 使用指南

## 1. 工作站与业务项目的边界

本仓库是工作站框架仓库。它只保存通用规则、脚本、治理和无凭据 skill；业务项目应克隆到安装后的工作区根目录，并继续由各自 Git 仓库管理。

```text
D:\AI-Toolkit\multi-project-workstation\   # 本仓库，受 Git 管理
D:\Workspace\                               # 安装后的工作区容器，不初始化 Git
  rules/ scripts/ governance/ briefs/ artifacts/
  worktrees/                            # 各项目 worktree 的统一容器
  project-a\                               # 独立 Git 仓库
  project-b\                               # 独立 Git 仓库
  worktrees\                               # 各项目 Git worktree
```

不要在工作区根目录执行 `git init` 或 `git add .`。项目 Git 操作只在项目根目录或其 worktree 中执行。

跨项目方案、接口契约和执行交接统一放在工作站的 `briefs/`，不依赖项目内的自定义任务目录。需求对应的前端/后端代码位置和分支维护在 `briefs/WORKTREE-INDEX.md`。需要长期保存或跨项目复用的文件产物放在 `artifacts/`，不要用它推断需求状态或分支。

## 2. 安装模板

```powershell
Set-Location D:\AI-Toolkit\multi-project-workstation
.\install.ps1 -WorkspaceRoot D:\Workspace
```

默认安装只包含多项目/worktree/治理的基础结构。数据库分析与云效能力是可选项：

```powershell
.\install.ps1 -WorkspaceRoot D:\Workspace -IncludeDbAnalysis
.\install.ps1 -WorkspaceRoot D:\Workspace -IncludeYunxiao
.\install.ps1 -WorkspaceRoot D:\Workspace -IncludeDbAnalysis -IncludeYunxiao
```

安装脚本仅允许写入空目录，且会把 `__WORKSPACE_ROOT__` 渲染为实际路径。随后手工维护 `rules/worktree.md`，登记自己的项目和 worktree 父目录。创建/删除 worktree 时优先使用安装后工作区内的 `scripts\new-worktree.cmd` 与 `scripts\remove-worktree.cmd`。

功能完成并需要合入测试或集成分支时，使用 `scripts\publish-to-branch.cmd`。它要求显式指定目标分支、逗号分隔的仓库相对文件清单和提交信息；先运行 `-Preview`，确认后再执行。脚本会先推送源分支并修正 upstream，再临时切换、合入并推送目标分支；目标分支占用、冲突或远端拒绝时会停止等待人工决定。

## 3. 安装数据库 skill 与本地配置（可选）

只有初始化时传入 `-IncludeDbAnalysis`，安装后的工作区才会包含 `scripts\db-analysis.cmd`、`scripts\db-analysis.ps1` 和 `scripts\db-targets.example.json`。

如需使用，将 `skills/db-analysis` 复制到 Codex 的 skill 目录（通常是 `%USERPROFILE%\.codex\skills\db-analysis`）。复制 `scripts/db-targets.example.json` 为安装后工作区的 `scripts/db-targets.json`，只在本机填写只读账号。

MySQL 使用本机私有 `clientDefaultsFile`；PostgreSQL/Hologres 使用本机私有 `pgPassFile`，格式为 `host:port:database:user:password`。Hologres 与 PostgreSQL 的对象层级是“实例 → database → schema → table”，因此目标必须维护 `allowedDatabases` 和 `allowedSchemas`，查询时显式传入 `-Database`、`-Schema` 并使用 `schema.table`。

`db-targets.json`、`maintenance-approval.json` 和所有真实凭据必须保持本地文件，不提交 Git。策略中的 `allowed_targets` 必须与本地目标名一致；`allowed_read_actions` 仅应包含允许的只读操作。

## 4. 配置云效任务管理（可选）

只有初始化时传入 `-IncludeYunxiao`，安装后的工作区才会包含 `yunxiao-workstation` skill、工作站本地 MCP 启动脚本和示例配置。模板不会携带任何个人 token、组织 ID 或项目 ID。Yunxiao MCP 默认不启用，避免未配置 token 时新 session 启动失败。

安装后如需启用：

```powershell
Copy-Item .\.codex\secrets\yunxiao.env.example.cmd .\.codex\secrets\yunxiao.env.cmd
Copy-Item .\.codex\secrets\yunxiao.personal.example.json .\.codex\secrets\yunxiao.personal.json
```

然后只在本机填写：

- `.codex\secrets\yunxiao.env.cmd`：`YUNXIAO_ACCESS_TOKEN`
- `.codex\secrets\yunxiao.personal.json`：当前用户、组织、项目、项目别名、工作项编号前缀

填写完成后，在 `.codex\config.toml` 中取消以下片段的注释：

```toml
[mcp_servers.yunxiao]
command = '<WorkspaceRoot>\.codex\mcp\yunxiao-mcp.cmd'
startup_timeout_sec = 120
```

真实文件 `yunxiao.env.cmd` 与 `yunxiao.personal.json` 是个人本地状态，必须保持不提交。示例文件可以提交。

默认能力边界：

- 读取组织、项目、需求、任务、Bug、评论、附件、活动：只读，可直接执行。
- 创建/更新工作项、评论、状态流转：先展示中文预案，再人工确认。
- 流水线：保留 `pipelines.test` 与 `pipelines.production` 空结构；默认不启用自动化。只有人工维护到个人配置白名单且 `enabled: true` 的流水线，才允许 Agent 预案确认后执行。

如果使用者不需要云效，保持 `.codex\config.toml` 中的 Yunxiao MCP 片段注释即可。

## 5. 注册治理 Hook

治理守卫读取 stdin JSON，并以 `PreToolUse` 的拒绝决策阻断操作。它会限制自身策略、工作站本地 Hook 配置、数据库入口、直连 MySQL、写 SQL、敏感字段、锁定和诊断类查询。

### Codex

安装脚本会生成工作站本地配置：

```text
<WorkspaceRoot>\.codex\config.toml
```

该文件启用 `hooks = true`，并指向当前工作站的 `governance\agent-guard\pre_tool_guard.py` 与 `post_tool_guard.py`。用户级 `~/.codex/config.toml` 不需要绑定某个工作站的治理 Hook；用户级配置只保留个人默认。

调整 Codex Hook 时，先修改：

```text
<WorkspaceRoot>\governance\agent-guard\hook-registry.json
```

再在工作站根目录执行：

```powershell
.\governance\agent-guard\sync-hooks.ps1
```

该脚本只同步到 `<WorkspaceRoot>\.codex\config.toml`，不要手工维护 `[[hooks.*]]`。

### Claude Code

安装脚本会生成工作站本地配置：

```text
<WorkspaceRoot>\.claude\settings.local.json
```

该文件注册 `PreToolUse` 与 `PostToolUse`，并指向当前工作站的同一套 `agent-guard`。不要把某个工作站的治理 Hook 写入 `~/.claude/settings.json`。

重启或新开从工作站根目录进入的 Agent 后，以安全查询、非法目标、危险 Git、缺少 `-OutputFormat Json` 的 worktree 脚本和受保护文件修改分别验证允许与拒绝行为。

## 6. 维护与升级

框架变更在本仓库中提交；已有工作区不会自动更新。升级前先比较模板与工作区的治理、脚本和规则，再有选择地合并。不要用模板覆盖本地数据库配置、云效 token、云效个人组织/项目目录、brief/worktree 分支索引或项目注册表。

受保护的治理文件默认不能由 Agent 修改。需要维护时，由人工在安装后的 `governance\agent-guard\` 中，从 `maintenance-approval.example.json` 创建 `maintenance-approval.json` 并将其内容设为 `{ "enabled": true }`；完成后手动删除该文件或改回 `false`。该文件本身始终受保护，Agent 无法自行开启维护窗口。
