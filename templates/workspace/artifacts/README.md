# Artifacts

`__WORKSPACE_ROOT__\artifacts` 用于保存需要长期保留、跨项目复用或便于人工查阅的文件产物。

## 存放边界

- 可以保存：导出的文档、截图、安装包、验收材料、外部交付文件、一次性分析结果，以及发布脚本生成的合并冲突核验材料。
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

## 首版人工代码 Review 导航产物

`code-review/<需求名>/` 仅在用户明确要求、首版代码尚未提交时生成，包含 `code-flow.md` 与 `code-flow.html`。它帮助人工在 IDE 中定位本次未提交 diff 的入口、主调用链和关键改动点，不是上线前 Agent Review 报告，也不代表测试或上线结论。

- 不自动创建或更新；
- 不提交到业务仓库，不维护为 brief；
- 提交、切换分支或开始上线前 Review 后自动失效；
- 完整边界见 `__WORKSPACE_ROOT__\rules\first-pass-code-review.md`。

## 合并冲突核验产物

`merge-verification/<仓库名-哈希>/` 由 `scripts/publish-to-branch.ps1` 自动创建，保存 Git 三方输入、冲突态原文、核验报告和 B 类人工决策记录。

- 不复制到项目仓库，不纳入待提交文件；
- `active-merge.json` 仅指向当前活动合并；完成后删除指针，输入和报告保留复盘；
- 规则见 `rules/merge-verification.md`。
