# 多项目工作站

本目录管理开发规则、需求方案、业务知识导航与受控脚本。业务源码留在独立项目仓库，可由不同客户端或 CLI 使用，不依赖自建客户端。

## 日常入口

| 当前需要 | 入口 |
| --- | --- |
| Agent 接入 | [AGENTS.md](AGENTS.md)，CLAUDE.md 仅导入公共入口 |
| 新需求与设计 | [生命周期](rules/task-lifecycle.md)、[设计规则](rules/design.md) |
| 接手开发 | 需求 README → [执行入口](rules/execution-entry.md) |
| 阶段交接 | [交接规则](rules/handoff.md)，阶段完成或暂停自动维护 |
| 上线前审查 | [Review 角色](rules/review-role-guide.md) |
| Git、worktree、发布及可选数据库 | [脚本索引](scripts/INDEX.md) |
| 业务知识、参考材料、临时文件 | [knowledge](knowledge/README.md)、[artifacts](artifacts/README.md)、[tmp](tmp/README.md) |
| 结构维护与项目接入 | [结构地图](STRUCTURE.md)、[规则索引](rules/INDEX.md)、[项目接入](vibe-coding-新项目初始化指南.md) |

## 目录边界

- projects：独立主项目容器；项目注册表只维护在 rules/worktree.md。
- worktrees：需求执行工作区；创建/删除先预览、确认并走受控脚本。
- briefs：复杂需求的 README 导航、spec 当前方案及 runtime 执行材料；登记不预建空模板。
- knowledge：使用者整理过的业务知识与操作资料；模板不包含任何真实业务资料。
- artifacts：用户选择留下的参考附件和交付产物，不强制绑定需求。
- tmp：用户定期清理的临时杂物，Agent 不自行清理。
- plans：待讨论的工作站改进计划，记录不等于实施授权。

数据库与云效是安装时显式选择的能力；未安装时不猜测工具入口。根目录默认不初始化 Git；如用户明确启用本地规则版本控制，按 .gitignore 排除业务仓库、资料和本机配置，不配置远端。完整职责见 STRUCTURE.md。
