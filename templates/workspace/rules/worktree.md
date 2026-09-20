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
├── project-api/                      ← 根项目（主仓库）
├── project-web/
├── worktrees/                         ← 新 worktree 统一根目录
│   ├── project-api-worktree/
│   │   └── example-feature/
│   └── project-web-worktree/
│       └── example-feature/
└── briefs/                            ← 设计方案（独立于 worktree）
```

---

## 根项目 master 边界

- 根项目的 `master` 只用于基线同步、只读代码理解，以及用户明确要求的本次业务需求和其直接连带文档。
- Agent 不得在根项目 `master` 新增、修改或迁移治理规则、Hook / Agent 配置、工作站脚本、项目导航、知识库或其他与本次业务无关的文档。
- 需要维护工作站、治理或通用 Agent 能力时，只能在工作站目录维护；需要修改业务代码时，必须在该需求对应的 worktree 分支中执行。
- 如果用户明确要求在 `master` 修改非业务内容，先说明该动作突破本边界，并等待用户再次确认；不得将“便于当前 Agent 使用”视为业务连带理由。

---

## 创建 Worktree

AI 检测到用户意图为"创建 worktree"时，按以下交互流程执行：

### Step 1: 选择根项目

列出注册表中的选项

### Step 2: 输入需求名

kebab-case，如 `example-feature`、`member-profile`。

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

### 脚本入口

新增 worktree 必须使用 `__WORKSPACE_ROOT__\scripts\new-worktree.cmd`，包括从项目根目录启动的 Agent 会话；项目级 `AGENTS.md` / `CLAUDE.md` 应路由到本规则和 `scripts/INDEX.md`。

先预览，确认后再创建。

Agent 不得用手写底层 Git 创建命令代替该脚本，也不得因目标目录写入受限而改建到项目内 `.codex-worktrees/` 或其他路径。脚本失败时保留现场，报告失败命令、环境限制和已产生的状态；取得正确路径的执行权限或由用户明确修改工作站规则后再继续。

先以 `-Preview` 获取预案，经确认后再执行。真正创建时若远端访问或写入被沙箱限制，应申请所需权限，不能用其他目录或原生 Git 命令绕过。

预览示例：

```powershell
__WORKSPACE_ROOT__\scripts\new-worktree.cmd -ProjectKey project-api -Name my-feature -Type feature -BaseBranch master -Preview
```

创建示例：

```powershell
__WORKSPACE_ROOT__\scripts\new-worktree.cmd -ProjectKey project-api -Name my-feature -Type feature -BaseBranch master
```

### 底层动作说明（不可直接调用）

脚本负责创建父目录、更新或核验基线分支、创建并注册 Git worktree。此处不提供可复制的底层 Git 命令；实际创建入口只有上述脚本。

### 规则

1. **Worktree 必须放在 `__WORKSPACE_ROOT__\worktrees\<原项目目录名>-worktree\<需求名>/` 目录下**
2. **Worktree 父目录首次使用时自动创建**（`mkdir -p`）
3. **分支命名**：`feature/<需求名>` 或 `hotfix/<需求名>`
4. **基于分支**：默认基于最新 `master`；有特殊需求时允许用户指定已存在分支
5. **已有旧 worktree 不迁移**
6. **同步代码位置索引**：创建完成后必须更新 `briefs/WORKTREE-INDEX.md`，记录 brief、代码位置和分支

---

## 临时发布到测试或集成分支

功能 worktree 不需要长期维护额外的测试分支 worktree。功能完成后，可在同一 worktree 临时切换到调用方指定的目标分支；必须先用 `__WORKSPACE_ROOT__\scripts\publish-to-branch.cmd` 预览并经人工确认后执行。

脚本会严格校验文件清单，先提交并推送源分支、修正源分支 upstream，再临时切换目标分支更新、合并和推送。只有目标推送成功后才切回源分支。

目标分支被其他 worktree 占用、存在冲突、目标分支不存在、远端拒绝或任一 Git 命令失败时，必须停止并由人工决定；不得自动解决冲突、强推、回滚或切回分支。

## 删除 Worktree

用户指定删除某个 worktree 时，执行以下步骤：

1. **读取脚本索引**：先读取 `__WORKSPACE_ROOT__\scripts\INDEX.md`
2. **预览删除计划**：执行 `__WORKSPACE_ROOT__\scripts\remove-worktree.cmd -WorktreePath <worktree路径> -Preview`
3. **用户确认**：向用户展示预览结果，确认是否删除 worktree
4. **执行删除**：确认后执行 `__WORKSPACE_ROOT__\scripts\remove-worktree.cmd -WorktreePath <worktree路径>`
5. **Dirty 场景**：若脚本提示存在未提交或未跟踪变更，必须先让用户确认；只有用户明确接受删除这些变更时，才可追加 `-Force`
6. **半删除状态**：若 worktree 已不是完整 Git worktree，但仍位于安全边界内，允许脚本在 `-Force` 下进入残留清理模式

**强制约束**：
- ✅ 删除 `worktrees/<项目>-worktree/<name>/`（worktree 项目目录）
- ✅ 保留 git 分支（`git worktree remove` 不会删除分支）
- ✅ 删除后必须同步更新 `briefs/WORKTREE-INDEX.md` 中对应代码位置
- ✅ Git 半删除残留只允许清理所属主仓库 `.git\worktrees\<name>` 下的精确目录
- ❌ **禁止**删除 `worktrees/<项目>-worktree/` 父目录本身
- ❌ **禁止**删除 `<Project>/` 根项目目录
- ❌ **禁止**执行 `git branch -D` 删除分支
- ❌ **禁止**维护或依赖 Agent 会话恢复状态推断代码位置

---

## Brief 对应代码位置维护规则

`briefs/WORKTREE-INDEX.md` 是需求 brief 对应代码位置和分支的唯一维护点。

创建、删除或迁移 worktree 后，必须同步更新：

- 需求名
- brief 路径
- 后端代码位置与分支（如有）
- 前端代码位置与分支（如有）
- 单端需求的代码位置与分支

禁止维护 Agent 会话名、恢复状态、当前进度等易漂移信息。最终执行 Git 操作前，仍必须实时执行 Git 查询确认。

## 历史 Worktree 处理

如果存在旧 worktree 直接平铺在 `__WORKSPACE_ROOT__\` 根目录，应按以下规则处理：

1. **旧 worktree 不强制迁移**：避免影响正在进行的开发。
2. **新需求禁止使用旧结构**：一律创建到 `__WORKSPACE_ROOT__\worktrees\<原项目目录名>-worktree\<需求名>/`。
3. **旧 worktree 开发完成后优先删除**：优先使用 `__WORKSPACE_ROOT__\scripts\remove-worktree.cmd -WorktreePath <旧路径> -Preview` 预览；旧路径若不在新安全边界内，先人工确认再按 Git 官方命令处理。
4. **确需长期保留时再迁移**：先确认无未提交变更，再使用 Git worktree 官方命令处理。

---

## Worktree 父目录约束

- `__WORKSPACE_ROOT__\worktrees\` 和各项目 worktree 父目录只作为容器，不直接开发、不提交代码。
- 每个项目 worktree 父目录保留 `README.md`，说明对应主项目和路径格式。
- 删除 worktree 时只删除子目录，禁止删除父目录。
