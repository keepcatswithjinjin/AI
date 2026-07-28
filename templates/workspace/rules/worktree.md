# Worktree 管理规范

> 所有 worktree 均以以下注册表项目为根创建。本文件被 CLAUDE.md 和 AGENTS.md 路由引用。

---

## 根项目注册表

| Key | 仓库路径 | 定位 | Worktree 父目录 |
|-----|---------|------|----------------|
| `project-api` | `__WORKSPACE_ROOT__\project-api` | 示例后端项目 | `__WORKSPACE_ROOT__\worktrees\project-api-worktree` |
| `project-web` | `__WORKSPACE_ROOT__\project-web` | 示例前端项目 | `__WORKSPACE_ROOT__\worktrees\project-web-worktree` |

---

## 目录约定

```text
__WORKSPACE_ROOT__\
├── project-api\                       ← 根项目（主仓库）
├── project-web\
├── worktrees\                         ← 新 worktree 统一根目录
│   ├── project-api-worktree\
│   │   └── example-feature\
│   └── project-web-worktree\
└── briefs\                            ← 设计方案（独立于 worktree）
```

---

## 创建 Worktree

AI 检测到用户意图为“创建 worktree”时，除读取本文件外，还必须读取 `scripts/INDEX.md`，并优先使用脚本输出预案。

### Step 1: 选择根项目

列出注册表中的选项。

### Step 2: 输入需求名

kebab-case，如 `order-export`、`member-profile`。

### Step 3: 选择分支类型

```text
feature 还是 hotfix？
- feature: 功能开发（默认）
- hotfix: 紧急修复
```

### Step 4: 选择基于分支

默认基于最新 `master`。用户有特殊需求时，允许指定已存在分支，例如 `testing`、`feature/xxx`、`hotfix/xxx`。指定现有分支时，创建前必须确认该分支在本地或远端存在；不存在则停止并提示用户确认分支名。

### Step 5: 选择是否启用 Serena

询问用户：

```text
是否为该 worktree 启用 Serena？
- 是：在 worktree 根目录写入项目级 `.codex/config.toml`，Serena 仅索引该 worktree（复杂需求推荐）
- 否：不写入 Serena 配置（简单需求默认）
```

约束：

- 默认不启用 Serena，除非用户明确选择或本次需求已判断为复杂需求且用户确认需要。
- Serena 只允许在项目根或 worktree 根目录启用，禁止在 `__WORKSPACE_ROOT__` 根目录启用，避免将多项目工作区整体建索引。
- 启用时由 `scripts/new-worktree.cmd` 写入项目级 `.codex/config.toml`；若 `.codex/` 不存在则创建。
- 若 `.codex/config.toml` 已存在，只追加或补全 Serena MCP 配置，不覆盖已有项目级配置；尤其不得重写全局治理 hooks。
- Serena 配置用于桌面端新开到该 worktree 目录的 task；在工作区根 session 中创建 worktree 后，本 session 不会自动加载新 worktree 的项目级配置。

推荐写入内容由脚本生成：

```toml
[mcp_servers.serena]
command = "<your-serena-executable>"
args = ["start-mcp-server", "--context=codex", "--project-from-cwd"]
startup_timeout_sec = 120
```

通用配置要求：

- 不要在模板中写死某个用户的 Serena 路径。
- `scripts/new-worktree.ps1` 会按顺序寻找：`-SerenaExe <path>` 参数、`SERENA_EXE` 环境变量、PATH 中的 `serena` 命令。
- `--project-from-cwd` 必须保留，使 Codex 桌面端进入不同 worktree 时按当前目录决定 Serena 项目边界。
- Java / JRE / JDK / JDTLS 属于使用者本机或项目运行环境配置。若 Serena 的 Java LSP 需要这些路径，应由使用者在自己的 Serena 用户级配置或项目说明中配置，不得复用模板作者机器上的路径。

### 脚本入口

新增 worktree 必须优先使用 `__WORKSPACE_ROOT__\scripts\new-worktree.cmd`。

先预览，确认后再创建。Agent 不得用手写底层 Git 创建命令代替该脚本。

预览示例：

```powershell
__WORKSPACE_ROOT__\scripts\new-worktree.cmd -ProjectKey project-api -Name my-feature -Type feature -BaseBranch master -Serena Ask -Preview
```

创建示例：

```powershell
__WORKSPACE_ROOT__\scripts\new-worktree.cmd -ProjectKey project-api -Name my-feature -Type feature -BaseBranch master -Serena Enable
```

### 规则

1. Worktree 必须放在 `__WORKSPACE_ROOT__\worktrees\<原项目目录名>-worktree\<需求名>/` 目录下。
2. Worktree 父目录首次使用时自动创建。
3. 分支命名为 `feature/<需求名>` 或 `hotfix/<需求名>`。
4. 默认基于最新 `master`；有特殊需求时允许用户指定已存在分支。
5. 已有旧 worktree 不迁移。
6. 创建 worktree 时必须询问是否启用 Serena；启用时仅写入该 worktree 根目录的项目级 `.codex/config.toml`。

---

## Serena 启用边界

- `__WORKSPACE_ROOT__` 是多项目调度层，不是代码项目，禁止在 `__WORKSPACE_ROOT__\.codex/config.toml` 中启用 Serena。
- 简单需求通常不需要 Serena，可在工作区根 session 中直接处理低风险改动。
- 复杂需求需要 Serena 时，应先创建 worktree 并写入项目级 `.codex/config.toml`，然后在 Codex 桌面端新开 task，目录选择该 worktree 根目录。
- 需求方案设计或复杂代码理解中，若需要大量查询函数、类、引用、调用关系，可优先考虑使用已启用 worktree 中的 Serena 工具；简单文本检索和文件定位仍使用 `rg`。
- 后续若验证 Serena 效果稳定，可考虑通过 Hook 强制检查：新建复杂需求 worktree 时必须显式记录是否启用 Serena，并对跳过启用的情况要求人工确认。

---

## 删除 Worktree

用户指定删除某个 worktree 时，除读取本文件外，还必须读取 `scripts/INDEX.md`，并优先使用脚本输出删除预案。

1. 预览删除计划：`__WORKSPACE_ROOT__\scripts\remove-worktree.cmd -WorktreePath <worktree路径> -Preview`
2. 用户确认：展示预览结果，确认是否删除 worktree、同步清理 `workspace-state.json`、清理可归属 Serena 索引。
3. 执行删除：确认后执行 `__WORKSPACE_ROOT__\scripts\remove-worktree.cmd -WorktreePath <worktree路径>`。
4. Dirty 场景：若脚本提示存在未提交或未跟踪变更，必须先让用户确认；只有用户明确接受删除这些变更时，才可追加 `-Force`。
5. Serena 进程占用：若预览列出 Serena/JDTLS 进程，默认停止删除；只有用户明确同意时，才可追加 `-StopSerenaProcesses`。
6. 半删除状态：若 worktree 已不是完整 Git worktree，但仍位于安全边界内，允许脚本在 `-Force` 下进入残留清理模式。

强制约束：

- ✅ 删除 `worktrees/<项目>-worktree/<name>/` 具体 worktree 项目目录。
- ✅ 保留 git 分支（`git worktree remove` 不会删除分支）。
- ✅ 删除前必须检查 `workspace-state.json`，避免留下已不存在目录的恢复项。
- ✅ 若启用了 Serena，删除时必须清理用户级 Serena `projects` 注册项。
- ✅ 若启用了 Serena，删除时必须清理可明确归属该 worktree 的 JDTLS workspace 索引目录。
- ✅ Serena 的项目级 `.serena/` 随 worktree 目录一同删除。
- ✅ Serena 的 `sharedIndex` 是跨项目共享缓存，删除单个 worktree 时必须保留。
- ✅ Serena logs 默认保留，用于审计与排障。
- ❌ 禁止删除 `worktrees/<项目>-worktree/` 父目录本身。
- ❌ 禁止删除 `<Project>/` 根项目目录。
- ❌ 禁止执行 `git branch -D` 删除分支。
- ❌ 禁止在未确认匹配关系时自动删除 `workspace-state.json` 中的 session。

---

## Worktree 删除时的 Serena 清理规则

当待删除 worktree 满足以下任一条件时，视为启用了 Serena：

- worktree 根目录存在 `.serena/`
- worktree 根目录存在 `.codex/config.toml` 且包含 `[mcp_servers.serena]`
- 用户级 Serena 配置中存在该 worktree 的项目注册
- 可定位到归属该 worktree 的 JDTLS workspace 索引目录

删除时必须同步检查并清理：

1. 项目级 Serena 目录：`.serena/` 随 worktree 目录一起删除。
2. 用户级项目注册：从 `%USERPROFILE%\.serena\serena_config.yml` 的 `projects` 中移除该 worktree 路径。
3. JDTLS workspace 索引：删除 `%USERPROFILE%\.serena\language_servers\static\EclipseJDTLS\workspaces\<hash>` 中可明确归属该 worktree 的目录。

删除时必须保留：

- `%USERPROFILE%\.serena\language_servers\static\lsp\EclipseJDTLS\sharedIndex`：跨项目共享缓存。
- `%USERPROFILE%\.serena\logs`：审计与排障日志。

若脚本无法明确定位 JDTLS workspace 归属，只删除 worktree 和项目注册，不猜测删除共享或未知缓存。

---

## 历史 Worktree 处理

如果存在旧 worktree 直接平铺在 `__WORKSPACE_ROOT__\` 根目录，应按以下规则处理：

1. 旧 worktree 不强制迁移，避免影响正在进行的开发。
2. 新需求禁止使用旧结构，一律创建到 `__WORKSPACE_ROOT__\worktrees\<原项目目录名>-worktree\<需求名>/`。
3. 旧 worktree 开发完成后优先删除；若旧路径不在新安全边界内，先人工确认再按 Git 官方命令处理。
4. 确需长期保留时再迁移：先确认无未提交变更，再使用 Git worktree 官方命令处理。

---

## Worktree 父目录约束

- `__WORKSPACE_ROOT__\worktrees\` 和各项目 worktree 父目录只作为容器，不直接开发、不提交代码。
- 每个项目 worktree 父目录保留 `README.md`，说明对应主项目和路径格式。
- 删除 worktree 时只删除子目录，禁止删除父目录。