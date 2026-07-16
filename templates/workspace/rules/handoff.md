# 执行交接规范

> 本文件被 CLAUDE.md 和 AGENTS.md 路由引用。

---

## 适用范围

本 session 内执行了任何代码修改（含小型执行），或切换至子项目执行了代码修改。

---

## 交接文档

每次执行任务结束后，Agent **MUST** 主动提问：

> "是否需要创建/更新执行交接文档（`agent-guide.md`）？"

若用户确认，生成文件到 `__WORKSPACE_ROOT__\briefs\[类型]\[需求]\agent-guide.md`。

命名标准：

- 统一使用 `agent-guide.md`
- 历史已存在的 `需求-agent-guide.md`、`handoff-agent-guide.md` 保留兼容，不强制改名
- 从现在开始，新增或覆盖交接文档时不再创建新的旧命名文件

---

## 文档内容

```markdown
# [需求名称] - Agent 交接指南

## 当前进度
- 已完成：...
- 未完成：...

## 文件变更清单
| 文件 | 变更类型 | 说明 |
|------|---------|------|

## 关键设计决策
- 决策1：...（为什么这么做）

## 下一个 Agent 接入指引
1. 读取本文件了解上下文
2. 参考 design.md（如有）
3. 继续未完成事项
```

---

## 约束

- 禁止跳过此步骤直接结束 session
- 文档内容必须自包含，不依赖本 session 的对话历史
- 文件命名 kebab-case，内容可用中文
- 纯 markdown 格式，兼容 Claude Code / Codex / Copilot 等任意 AI CLI 工具

