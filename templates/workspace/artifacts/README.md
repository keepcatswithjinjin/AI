# Artifacts

`__WORKSPACE_ROOT__\artifacts` 用于保存需要长期保留、跨项目复用或便于人工查阅的文件产物。

## 存放边界

- 可以保存：导出的文档、截图、安装包、验收材料、外部交付文件、一次性分析结果。
- 不保存：项目源码、需求执行状态、Agent 会话状态、worktree 分支映射。
- 复杂需求方案仍放在 `__WORKSPACE_ROOT__\briefs`。
- 代码位置和分支仍只维护在 `__WORKSPACE_ROOT__\briefs\WORKTREE-INDEX.md`。

## 目录建议

按稳定主题或项目名建子目录，例如：

```text
artifacts/
├── project-docs/
└── release-v1.0/
```

新增文件时优先使用可读名称；若产物与日期强相关，可在文件名中加入 `YYYY-MM-DD`。
