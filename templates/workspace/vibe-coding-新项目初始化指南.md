# 新项目接入指南

仅在用户授权接入时执行。不要为接入修改全局 Git 配置、强制创建项目知识库，或复制其他项目的业务规则。

## 1. 确认路径

新主项目统一放在 __WORKSPACE_ROOT__\projects\<项目目录名>；保留独立 Git 仓库。已有项目的迁移、克隆和分支处理须单独确认，不由模板安装自动完成。

## 2. 登记

唯一注册表为 [worktree 规则](rules/worktree.md)。替换其中示例，登记真实 key、项目路径、职责与 worktree 父目录；不在其他文件复制注册表。

| Key | 仓库路径 | 定位 | Worktree 父目录 |
| --- | --- | --- | --- |
| project-api | __WORKSPACE_ROOT__\projects\project-api | 后端 | __WORKSPACE_ROOT__\worktrees\project-api-worktree |

实际登记须按 worktree 规则的反引号格式，供脚本读取。

## 3. 项目入口

先读取项目现有规则。若需要接入工作站，在用户批准的项目变更范围内维护精简入口：

- 项目事实、代码导航、构建测试命令、专属约束留在项目。
- 工作站执行规则引用 __WORKSPACE_ROOT__\rules\execution-entry.md。
- 用户指定 brief 时以该需求 README 接入；未指定时按需求与代码位置索引精确核对。
- 创建/删除 worktree 必须走工作站脚本；不自行创建仓库内备用 worktree。
- 公共风格与流程不复制进项目。若项目已用 AGENTS 维护公共入口，CLAUDE 可仅导入，避免双份漂移。

不强制新增项目 knowledge、修改项目 .gitignore 或自动为项目启用工具与 Hook。

## 4. 开始需求

按 [生命周期](rules/task-lifecycle.md)分级；复杂需求只登记索引与状态，实际设计时再产出 README/spec，不预建空模板。主项目与 worktree 的 Git 操作范围独立于工作站框架。

## 5. 核验

确认项目路径、注册表、项目入口路由、Git 分支与受控 worktree 预案一致；不得用历史交接代替实时状态。安装模板不代替接入授权，也不替使用者决定远端、发布分支或数据库目标。
