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

```
__WORKSPACE_ROOT__\
├── project-api/                      ← 根项目（主仓库）
├── project-web/
├── worktrees/                         ← 新 worktree 统一根目录
│   ├── project-api-worktree/
│   │   └── example-feature/
│   └── project-web-worktree/
└── briefs/                             ← 设计方案（独立于 worktree）
```

---

## 创建 Worktree

AI 检测到用户意图为"创建 worktree"时，按以下交互流程执行：

### Step 1: 选择根项目

列出注册表中的选项

### Step 2: 输入需求名

kebab-case，如 `order-export`、`member-profile`。

### Step 3: 选择分支类型

```
feature 还是 hotfix？
- feature: 功能开发（默认）
- hotfix: 紧急修复
```

默认使用 `feature`。

### Step 4: 选择基于分支

询问用户：

```
是否基于最新 master 创建？
- 是：先更新主项目 master，再从 master 创建新分支（默认）
- 否：请指定一个已存在分支名，基于该分支创建
```

约束：

- 默认基于最新 `master`。
- 用户有特殊需求时，允许指定已存在分支，例如 `testing`、`feature/xxx`、`hotfix/xxx`。
- 指定现有分支时，创建前必须先确认该分支在本地或远端存在；不存在则停止并提示用户确认分支名。
- 除非用户明确要求，不自动从非 `master` 分支创建。

### 执行命令

默认基于最新 `master`：

```bash
mkdir -p "<Worktree父目录>"
cd "<仓库路径>" && git fetch origin master && git checkout master && git pull --ff-only origin master
cd "<仓库路径>" && git worktree add -b <type>/<name> "<Worktree父目录>/<name>" master
```

指定已存在分支：

```bash
mkdir -p "<Worktree父目录>"
cd "<仓库路径>" && git fetch --all --prune
cd "<仓库路径>" && git worktree add -b <type>/<name> "<Worktree父目录>/<name>" <base-branch>
```

### 规则

1. **Worktree 必须放在 `__WORKSPACE_ROOT__\worktrees\<原项目目录名>-worktree\<需求名>/` 目录下**
2. **Worktree 父目录首次使用时自动创建**（`mkdir -p`）
3. **分支命名**：`feature/<需求名>` 或 `hotfix/<需求名>`
4. **基于分支**：默认基于最新 `master`；有特殊需求时允许用户指定已存在分支
5. **已有旧 worktree 不迁移**

---

## 删除 Worktree

用户指定删除某个 worktree 时，执行以下步骤：

1. **定位 worktree**：从 `git worktree list` 确认其所属的根项目仓库
2. **同步检查工作台状态**：读取 `__WORKSPACE_ROOT__\scripts\workspace-state.json`，找到与待删除 worktree 最匹配的 session
3. **用户确认**：向用户列出待删除 worktree、匹配到的 `sessionName`、匹配依据，并确认是否同步清理该 session 状态
4. **移除 worktree**：`cd <根项目> && git worktree remove <worktree路径>`
5. **清理残留**：若目录因锁定未被删除，手动 `rm -rf <worktree路径>`
6. **同步清理工作台状态**：仅在用户确认后，从 `workspace-state.json` 删除对应 session 记录

**强制约束**：
- ✅ 删除 `worktrees/<项目>-worktree/<name>/`（worktree 项目目录）
- ✅ 保留 git 分支（`git worktree remove` 不会删除分支）
- ✅ 删除前必须检查 `workspace-state.json`，避免留下已不存在目录的恢复项
- ✅ 清理工作台状态前必须得到用户确认
- ❌ **禁止**删除 `worktrees/<项目>-worktree/` 父目录本身
- ❌ **禁止**删除 `<Project>/` 根项目目录
- ❌ **禁止**执行 `git branch -D` 删除分支
- ❌ **禁止**在未确认匹配关系时自动删除 `workspace-state.json` 中的 session

---

## Worktree 删除时的 Session 匹配规则

清理 worktree 时，Agent 必须同步拉取当前工作台状态：

```powershell
Get-Content -LiteralPath __WORKSPACE_ROOT__\scripts\workspace-state.json
```

匹配优先级：

1. **路径完全匹配**：`session.path` 规范化后等于待删除 worktree 路径
2. **目录名匹配**：`sessionName` 等于待删除 worktree 目录名
3. **包含匹配**：`session.path` 或 `sessionName` 包含待删除 worktree 目录名

输出给用户确认时必须包含：

- 待删除 worktree 路径
- 匹配到的 `sessionName`
- session path
- 匹配依据（路径完全匹配 / 目录名匹配 / 包含匹配）
- 将执行的动作：仅删除 worktree，或同时删除 workspace-state session

若匹配到多个候选 session，必须让用户选择；若没有匹配项，只删除 worktree，不修改 `workspace-state.json`。

`sessionName` 是 CLI 恢复名，不要求等于分支名；匹配时只能作为候选依据，不能作为唯一自动删除依据。

## 历史 Worktree 处理

如果存在旧 worktree 直接平铺在 `__WORKSPACE_ROOT__\` 根目录，应按以下规则处理：

1. **旧 worktree 不强制迁移**：避免影响正在进行的开发。
2. **新需求禁止使用旧结构**：一律创建到 `__WORKSPACE_ROOT__\worktrees\<原项目目录名>-worktree\<需求名>/`。
3. **旧 worktree 开发完成后优先删除**：通过所属根项目执行 `git worktree remove <旧路径>`。
4. **确需长期保留时再迁移**：先确认无未提交变更，再使用 Git worktree 官方命令处理。

---

## Worktree 父目录约束

- `__WORKSPACE_ROOT__\worktrees\` 和各项目 worktree 父目录只作为容器，不直接开发、不提交代码。
- 每个项目 worktree 父目录保留 `README.md`，说明对应主项目和路径格式。
- 删除 worktree 时只删除子目录，禁止删除父目录。
