# Git 合并冲突核验规范

> 本规则只约束 `publish-to-branch` 遇到**真实 Git 冲突**后的核验。Git 仍是唯一合并器；本规则不改写 Git 合并结果，也不替代上线前 Review。

## 目标与边界

- 目标：防止人工或 Agent 解决冲突时漏掉、重复或夹带代码，并在 Java/POM 冲突时要求编译证据。
- 不使用测试分支作为正确性依据；测试分支可能包含混合需求。
- 不审查功能需求本身、历史问题或整个 diff；这些属于 `review-role-guide.md`、`review-standard.md`。
- 产物保存在 `__WORKSPACE_ROOT__\artifacts\merge-verification\<仓库名-哈希>\`，不写入 Git 工作区，不改变待提交文件范围。

## 固定流程

### 1. Publish：Git 合并并自动冻结输入

正常入口不变：

```powershell
__WORKSPACE_ROOT__\scripts\publish-to-branch.cmd <原有参数>
```

脚本会使用 `git -c merge.conflictStyle=zdiff3 merge --no-ff --no-commit <source>`：

- 无冲突：执行 `git diff --check`、提交、推送并恢复功能分支。
- 有冲突：立即从 Git 暂存区冻结每个冲突文件的 stage 1/base、stage 2/ours、stage 3/theirs 和冲突态原文，随后停止在目标分支；不得直接提交或切回源分支。

### 2. 人工解决后 VerifyConflict

人工解决冲突并对每个文件执行 `git add` 后运行：

```powershell
__WORKSPACE_ROOT__\scripts\publish-to-branch.cmd `
  -ProjectPath <当前 worktree> `
  -TargetBranch <目标分支> `
  -Files <原文件清单> `
  -CommitMessage <原提交信息> `
  -Mode VerifyConflict
```

验证前提：仍位于目标分支、`MERGE_HEAD` 存在、无未解决 stage、无冲突标记、`git diff --check` 通过。

#### A 类：可机械证明的纯新增冲突

仅当共同 base 的每一行都仍被 ours 和 theirs 保留时，才判为 A；其余一律按 B，宁可人工核验也不误放行。

对 A 类，脚本用行的**多重集**完成四项对账：

1. `add(theirs→merged) = add(base→ours)`
2. `del(theirs→merged) = del(base→ours)`
3. `add(ours→merged) = add(base→theirs)`
4. `del(ours→merged) = del(base→theirs)`

任一计数不同即失败。它可捕获漏掉重复 `}`、空行或任意新增/删除行；但不把“行顺序正确”或“业务语义正确”伪装成机械结论。

#### B 类：共享 base 被改写的冲突

脚本生成 `manual-acceptance.md` 模板。人工必须按每个 B 文件说明：目标侧行为、源侧行为、最终取舍、受影响调用方和定向验证。

填写完成后重新验证：

```powershell
__WORKSPACE_ROOT__\scripts\publish-to-branch.cmd <原有参数> `
  -Mode VerifyConflict `
  -ManualAcceptanceFile <artifact 下已填写的 manual-acceptance.md>
```

占位项未填写、缺少文件决策或没有显式传入该文件时，验证不会通过。

#### Java / POM 冲突

任何冲突文件为 `.java` 或 `pom.xml` 时，必须同时给出当前 worktree 的 Maven 模块：

```powershell
__WORKSPACE_ROOT__\scripts\publish-to-branch.cmd <原有参数> `
  -Mode VerifyConflict `
  -CompileModules <模块1,模块2> `
  -MavenSettings <项目 settings 文件>
```

脚本执行 `mvn [-s settings] -pl <模块> -am compile`。未提供模块或退出码非 0 都不能进入完成阶段。定向测试仍按 `rules/verification.md` 判断是否需要，编译不替代测试。

### 3. CompleteConflict：显式确认后提交与推送

只有 `VerifyConflict` 状态为 `passed` 才能执行：

```powershell
__WORKSPACE_ROOT__\scripts\publish-to-branch.cmd <原有参数> `
  -Mode CompleteConflict `
  -ConfirmConflictCompletion
```

它会提交当前 merge、推送目标分支，成功后恢复源分支。远端拒绝时停留在目标分支，不自动回滚或切回。

#### 本地 Git Hook 的人工授权例外

当 `VerifyConflict` 已为 `passed`，但 Agent 运行时仅因**本地 Git Hook**拦截完成命令，人工可手动从
`__WORKSPACE_ROOT__\governance\agent-guard\local-git-hook-bypass-approval.example.json` 创建同目录的
`local-git-hook-bypass-approval.json`，并执行：

```powershell
__WORKSPACE_ROOT__\scripts\publish-to-branch.cmd <原有参数> `
  -Mode CompleteConflict `
  -ConfirmConflictCompletion `
  -UseHumanCompletionApproval
```

该批准文件只能由人维护，Agent 即使处于维护窗口也不能创建、修改或删除。脚本只在本次 `CompleteConflict` 的
`git commit` 与 `git push` 中使用受保护的空本地 hooks 目录；远端 CI、远端分支保护、冻结输入、冲突核验、
编译要求和源分支恢复仍完整执行，并会在 `report.md` 留下使用证据。完成后由人手工删除批准文件。不得以
`--no-verify`、`core.hooksPath` 或 `GIT_CONFIG_*` 方式直接绕过。

## 结论

| 状态 | 含义 | 允许完成 |
|------|------|----------|
| `passed` | A 类四项对账通过；B 类有完整人工记录；所需编译通过 | 是 |
| `manual-acceptance-required` | 存在 B 类，但没有完整人工决策记录 | 否 |
| `compile-required` | Java/POM 冲突尚未给出编译模块 | 否 |
| `failed` | A 类对账、编译、残留标记或基础检查失败 | 否 |

## 与其他规则的分工

- `rules/verification.md`：Maven 模块选择、测试类与测试通过证据。
- `rules/review-role-guide.md` / `rules/review-standard.md`：基于需求和 diff 的上线前 Review。
- 本规则：只保证“冲突解决后的 Git 合并输入未丢失，并按分类获得相应证据”。
