# 使用指南

## 1. 工作站与业务项目的边界

本仓库是工作站框架仓库。它只保存通用规则、脚本、治理和无凭据 skill；业务项目应克隆到安装后的工作区根目录，并继续由各自 Git 仓库管理。

```text
D:\AI-Toolkit\multi-project-workstation\   # 本仓库，受 Git 管理
D:\Workspace\                               # 安装后的工作区容器，不初始化 Git
  rules/ scripts/ governance/ briefs/
  worktrees/                            # 各项目 worktree 的统一容器
  project-a\                               # 独立 Git 仓库
  project-b\                               # 独立 Git 仓库
  worktrees\                               # 各项目 Git worktree
```

不要在工作区根目录执行 `git init` 或 `git add .`。项目 Git 操作只在项目根目录或其 worktree 中执行。

跨项目方案、接口契约和执行交接统一放在工作站的 `briefs/`，不依赖项目内的自定义任务目录。

## 2. 安装模板

```powershell
Set-Location D:\AI-Toolkit\multi-project-workstation
.\install.ps1 -WorkspaceRoot D:\Workspace
```

安装脚本仅允许写入空目录，且会把 `__WORKSPACE_ROOT__` 渲染为实际路径。随后手工维护 `rules/worktree.md`，登记自己的项目和 worktree 父目录。

## 3. 安装数据库 skill 与本地配置

将 `skills/db-analysis` 复制到 Codex 的 skill 目录（通常是 `%USERPROFILE%\.codex\skills\db-analysis`）。复制 `scripts/db-targets.example.json` 为安装后工作区的 `scripts/db-targets.json`，只在本机填写只读账号。

`db-targets.json`、`workspace-state.json`、`maintenance-approval.json` 和所有真实凭据必须保持本地文件，不提交 Git。策略中的 `allowed_targets` 必须与本地目标名一致；`allowed_read_actions` 仅应包含允许的只读操作。

## 4. 注册治理 Hook

治理守卫读取 stdin JSON，并以 `PreToolUse` 的拒绝决策阻断操作。它会限制自身策略、数据库入口、直连 MySQL、写 SQL、敏感字段、锁定和诊断类查询。

### Codex

在用户级 `config.toml` 添加（并确保 `[features]` 中存在 `hooks = true`）：

```toml
[[hooks.PreToolUse]]
matcher = "Bash|apply_patch|Edit|Write"

[[hooks.PreToolUse.hooks]]
type = "command"
command = 'python "D:\\Workspace\\governance\\agent-guard\\pre_tool_guard.py"'
timeout = 10
```

### Claude Code

在 `~/.claude/settings.json` 的根对象合并：

```json
{
  "hooks": {
    "PreToolUse": [{
      "matcher": "Bash|Edit|Write",
      "hooks": [{
        "type": "command",
        "command": "python \"D:\\Workspace\\governance\\agent-guard\\pre_tool_guard.py\"",
        "shell": "powershell",
        "timeout": 10
      }]
    }]
  }
}
```

重启对应 Agent 后，以安全查询、非法目标和受保护文件修改分别验证允许与拒绝行为。

## 5. 维护与升级

框架变更在本仓库中提交；已有工作区不会自动更新。升级前先比较模板与工作区的治理、脚本和规则，再有选择地合并。不要用模板覆盖本地数据库配置、工作台状态或项目注册表。

受保护的治理文件默认不能由 Agent 修改。需要维护时，由人工在安装后的 `governance\agent-guard\` 中，从 `maintenance-approval.example.json` 创建 `maintenance-approval.json` 并将其内容设为 `{ "enabled": true }`；完成后手动删除该文件或改回 `false`。该文件本身始终受保护，Agent 无法自行开启维护窗口。
