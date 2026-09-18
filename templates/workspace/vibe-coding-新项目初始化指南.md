# Vibe-Coding 新项目初始化指南

> 当有新项目加入 多项目工作站时，按此指南快速建立统一的管理结构。
> 本指南适用于后端（Java/Spring Boot）和前端（Vue/TS）项目。

---

## 一、前置检查

### 1.1 全局 Git 配置确认

确保已配置全局 `.gitignore`（排除 `knowledge/` 目录）：

```bash
git config --global core.excludesfile ~/.gitignore_global
cat ~/.gitignore_global | grep knowledge
# 应输出：knowledge/
```

若未配置，执行：
```bash
echo "knowledge/" >> ~/.gitignore_global
```

### 1.2 项目位置确认

新项目平级放入 `__WORKSPACE_ROOT__\`，新 worktree 统一放入 `__WORKSPACE_ROOT__\worktrees\<项目目录名>-worktree\`：

```
__WORKSPACE_ROOT__\
├── CLAUDE.md                  ← 设计工作站路由
├── AGENTS.md                  ← 同上（兼容 Codex）
├── README.md                  ← 人工入口说明
├── STRUCTURE.md               ← 全局结构地图和维护清单
├── rules/                     ← 公共操作规则
│   ├── INDEX.md
│   ├── worktree.md
│   ├── design.md
│   ├── task-lifecycle.md
│   └── handoff.md
├── briefs/                     ← 设计方案
├── worktrees/                 ← 新 worktree 统一根目录
│   └── 项目目录名-worktree/   ← 该项目的所有新 worktree
├── 新项目/                    ← 根项目（主仓库）
└── 已有项目...
```

---

## 二、必须创建的文件和目录

### 2.1 项目级 CLAUDE.md

在项目根目录创建 `CLAUDE.md`。参考模板：

- **后端项目**：参考 `project-api/CLAUDE.md`
- **前端项目**：参考 `project-web/CLAUDE.md`

**必须修改的 3 处**：
1. 文件顶部标题：`# 项目名 - 执行工作站`
2. 工作目录：`__WORKSPACE_ROOT__\项目名\`
3. Git worktree 路径：`__WORKSPACE_ROOT__\worktrees\项目目录名-worktree\`

> 项目级 CLAUDE.md 保持精简，详细的全局规则通过 `__WORKSPACE_ROOT__\rules/` 统一维护。

项目级 `CLAUDE.md` 与 `AGENTS.md` 都应注明：新增 worktree 必须先读取工作站的 `rules/worktree.md` 和 `scripts/INDEX.md`，走 `scripts/new-worktree.cmd` 预览、确认和执行；失败时停止报告，不自行调用 `git worktree add` 或改用仓库内目录。

### 2.2 knowledge/ 目录结构

在项目根目录创建：

```bash
mkdir -p knowledge/modules
```

创建两个文件：

**`knowledge/INDEX.md`** — 模块路由表模板：
```markdown
# 项目名 模块索引

> 本文件为项目的模块路由表。
> 开发前请先阅读本文件，定位相关模块后再深入阅读模块卡片。

---

## 模块列表

<!-- 按业务域分类，逐步补充 -->

### 域1
- [模块名](modules/module-name.md) — 一句话描述
  - 入口：`路径/to/Entry.java` 或 `pages/xxx/index.vue`

---

## 快速定位

| 需求类型 | 通常涉及的模块 |
|---------|--------------|
| 类型1 | module-a, module-b |

---

## 维护说明

- 新增模块时，在此文件添加索引条目，并在 `modules/` 下创建对应卡片
- 模块卡片控制在一屏（50 行）以内，超过则拆分
- 历史决策带日期标注，方便判断知识是否过时
```

**`knowledge/modules/README.md`** — 模块卡片说明：
```markdown
# modules/ 目录说明

本目录存放项目的**模块知识卡片**。

## 什么是模块知识卡片

每个 `.md` 文件对应一个业务模块，记录：
- **核心职责与边界**
- **跨模块调用关系**
- **历史决策**（带日期）
- **约束与坑**

## 不记录什么

- 具体字段列表、API URL（以接口契约为准）
- 正常业务逻辑（代码自述）
- 频繁变动的常量

## 维护时机

- 新需求启动：查 INDEX，读相关模块卡片
- 开发过程中：发现代码与卡片不符，当场更新
- 需求结束：有重大结构性改动，更新模块卡片首段
```

---

## 三、更新全局注册表

新项目加入后，**只更新 1 处**，避免多处注册表不同步：

| 文件 | 位置 | 添加内容 |
|------|------|---------|
| `__WORKSPACE_ROOT__\rules\worktree.md` | 根项目注册表 | 新增一行（含 Worktree 父目录） |

格式：
```markdown
| `key` | `__WORKSPACE_ROOT__\项目路径` | 项目描述 | `__WORKSPACE_ROOT__\worktrees\项目目录名-worktree` |
```

---

## 四、创建 Worktree 父目录

新项目加入时，同步创建 Worktree 父目录和说明文件：

```text
__WORKSPACE_ROOT__\worktrees\项目目录名-worktree\
└── README.md
```

`README.md` 内容保持简短，只说明：

- 本目录只存放该项目的临时并行开发 worktree。
- 不在父目录直接开发。
- 不删除父目录。
- 子 worktree 完成后使用工作站 `scripts/remove-worktree.cmd` 清理，并更新 `briefs/WORKTREE-INDEX.md`。

---

## 五、新需求初始化

新项目结构初始化完成后，新需求按 `__WORKSPACE_ROOT__\rules\task-lifecycle.md` 执行：

| 需求类型 | 处理方式 |
|----------|----------|
| 简单需求 | 不进入 `briefs/INDEX.md`，直接创建 worktree 执行 |
| 后端复杂需求 | 创建 `briefs/backend/<需求名>/` |
| 前端复杂需求 | 创建 `briefs/frontend/<需求名>/` |
| 跨端需求 | 创建 `briefs/cross/<需求名>/` |

复杂需求必须保持：

```text
需求名 = brief 文件夹名 = worktree 目录名
```

---

## 六、可选初始化脚本

当前阶段先不强制引入脚本。原因：

- 项目结构仍在稳定期，手工初始化更容易发现规则问题。
- `rules/worktree.md` 是唯一注册表，脚本过早介入会增加维护面。
- 后续连续多个项目按本指南稳定落地后，再抽象脚本更稳。

后续脚本建议只做机械动作：

1. 创建项目级 `knowledge/` 模板。
2. 创建 `worktrees/<项目目录名>-worktree/README.md`。
3. 提示用户手工更新 `rules/worktree.md` 注册表。
4. 做结构校验，不自动修改业务项目代码。

---

## 七、CLAUDE.md 内容扩展准则

当项目运行一段时间后，按需扩展项目级 `CLAUDE.md`：

| 时机 | 扩展内容 |
|------|---------|
| 发现 agent 经常犯同一类错误 | 在对应规范章节增加约束说明 |
| 引入新技术/工具 | 在"项目概述与技术栈"中补充 |
| 建立稳定的代码模式 | 在"开发规范"中增加命名/结构约定 |
| 踩过重大坑 | 在对应规范章节增加"注意"或"禁止"条目 |

**准则**：
- 不预置过多规则，只添加**已验证的必要约束**
- 规则表述要**具体可执行**，避免抽象描述
- 优先放在代码规范章节，而非通用交互规范

---

## 八、检查清单

新项目初始化完成后，确认：

- [ ] 项目平级放在 `__WORKSPACE_ROOT__\` 下
- [ ] 项目级 `CLAUDE.md` 已创建，3 处项目名已替换
- [ ] 项目级 `AGENTS.md` / `CLAUDE.md` 已路由工作站 worktree 脚本，并注明失败时不得降级到原生 Git 命令
- [ ] `knowledge/INDEX.md` 已创建
- [ ] `knowledge/modules/README.md` 已创建
- [ ] `knowledge/` 未被 Git 追踪（`git status` 验证）
- [ ] `__WORKSPACE_ROOT__\rules\worktree.md` 注册表已添加
- [ ] `__WORKSPACE_ROOT__\worktrees\项目目录名-worktree\README.md` 已创建

