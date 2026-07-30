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

跨项目方案、接口契约和执行交接统一放在工作站的 `briefs/`，不依赖项目内的自定义任务目录。需求对应的前端/后端代码位置和分支维护在 `briefs/WORKTREE-INDEX.md`。

## 2. 安装模板

```powershell
Set-Location D:\AI-Toolkit\multi-project-workstation
.\install.ps1 -WorkspaceRoot D:\Workspace
```

安装脚本仅允许写入空目录，且会把 `__WORKSPACE_ROOT__` 渲染为实际路径。随后手工维护 `rules/worktree.md`，登记自己的项目和 worktree 父目录。创建/删除 worktree 时优先使用安装后工作区内的 `scripts\new-worktree.cmd` 与 `scripts\remove-worktree.cmd`。

功能完成并需要合入测试或集成分支时，使用 `scripts\publish-to-branch.cmd`。它要求显式指定目标分支、逗号分隔的仓库相对文件清单和提交信息；先运行 `-Preview`，确认后再执行。脚本会先推送源分支并修正 upstream，再临时切换、合入并推送目标分支；目标分支占用、冲突或远端拒绝时会停止等待人工决定。

## 3. 安装数据库 skill 与本地配置

将 `skills/db-analysis` 复制到 Codex 的 skill 目录（通常是 `%USERPROFILE%\.codex\skills\db-analysis`）。复制 `scripts/db-targets.example.json` 为安装后工作区的 `scripts/db-targets.json`，只在本机填写只读账号。

`db-targets.json`、`maintenance-approval.json` 和所有真实凭据必须保持本地文件，不提交 Git。策略中的 `allowed_targets` 必须与本地目标名一致；`allowed_read_actions` 仅应包含允许的只读操作。

## 4. 注册治理 Hook

治理守卫读取 stdin JSON，并以 `PreToolUse` 的拒绝决策阻断操作。它会限制自身策略、数据库入口、直连 MySQL、写 SQL、敏感字段、锁定和诊断类查询。

### Codex

确保用户级 `config.toml` 的 `[features]` 中存在 `hooks = true`。随后执行安装后工作区中的：

```powershell
.\governance\agent-guard\sync-hooks.ps1
```

该脚本从 `governance\agent-guard\hook-registry.json` 生成用户级配置的受管 Hook 区块，包含 PreToolUse 与只校验 worktree 生命周期的 PostToolUse。不要手工维护 `[[hooks.*]]`。

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

## 5. Serena / Java 配置边界

Serena 是可选能力，适合复杂需求中大量查询函数、类、引用和调用关系。模板不会写死作者机器上的 Serena、JDK、JRE 或 JDTLS 路径。

启用方式：使用安装后工作区的 `.\scripts\new-worktree.cmd -ProjectKey project-api -Name my-feature -Serena Enable`。

`new-worktree.ps1` 会按顺序寻找 Serena 可执行文件：命令参数 `-SerenaExe <path>`、环境变量 `SERENA_EXE`、PATH 中的 `serena`。

如果 Serena 的 Java LSP 需要 JDK/JRE/JDTLS，请使用者在自己的 Serena 用户级配置或项目文档中配置，例如 `%USERPROFILE%\.serena\serena_config.yml`。不同项目需要不同 Java 版本时，以项目实际要求为准；不要复用模板作者的本机路径。

## 6. 维护与升级

框架变更在本仓库中提交；已有工作区不会自动更新。升级前先比较模板与工作区的治理、脚本和规则，再有选择地合并。不要用模板覆盖本地数据库配置、Serena 用户级配置、brief/worktree 分支索引或项目注册表。

受保护的治理文件默认不能由 Agent 修改。需要维护时，由人工在安装后的 `governance\agent-guard\` 中，从 `maintenance-approval.example.json` 创建 `maintenance-approval.json` 并将其内容设为 `{ "enabled": true }`；完成后手动删除该文件或改回 `false`。该文件本身始终受保护，Agent 无法自行开启维护窗口。
