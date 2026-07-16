# Worktrees

此目录只作为各项目 Git worktree 的统一父目录，不是 Git 仓库，也不直接存放业务代码。

目录格式：

```text
worktrees/<项目目录名>-worktree/<需求名>/
```

在 `rules/worktree.md` 登记项目后，再创建对应父目录与 worktree。删除时只能移除具体需求目录，不得删除项目父目录。
