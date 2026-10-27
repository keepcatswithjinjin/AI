# 工作站 Agent 入口

公共入口只在本文件维护；CLAUDE.md 导入本文件。下列路径相对 `__WORKSPACE_ROOT__`，仅在任务命中时读取，不递归加载全部链接。

## 职责与接入

- 在 工作站 根目录发起新需求时，默认负责查询、设计与契约；按流程产出适用 briefs、确认并创建 worktree 后停止实施。用户明确要求本对话继续时，才在目标 worktree 实施，不因改动小而自行转入开发。
- 从项目/worktree 接手时，按当前请求确定职责，不因继承本入口而重新走设计流程：只要求阅读就只读，要求实现则先读需求 README → [执行入口](rules/execution-entry.md)，Review 则读 [Review 角色](rules/review-role-guide.md)。
- 用户指定需求路径时直接使用；未指定时，用 worktree 名与 [需求索引](briefs/INDEX.md)、[代码位置索引](briefs/WORKTREE-INDEX.md)精确核对类型和名称，不模糊匹配。旧 README 缺少路由时直接读执行入口；项目 `tasks/` 不是 brief 入口。
- 单次授权只豁免明确指定的环节，执行前简述范围，不重复索取已有授权；分支命名、项目规则、验证及提交发布权限仍适用，见 [生命周期](rules/task-lifecycle.md)第一节。

## 必须保留的边界

- 工作区根目录默认不初始化 Git；用户明确启用本地版本控制时，仅纳管规则、工具和通用说明，不配置远端。业务仓库、briefs、知识内容、产物和本机配置不得混入工作站提交；业务 Git 在登记项目/worktree 内操作。
- 主项目在 `projects/`，worktree 在 `worktrees/`，注册表只维护于 [worktree 规则](rules/worktree.md)。根项目 master 仅作基线、只读理解及明确授权的本次业务/直接连带文档，不维护治理、Agent 配置、工作站能力或导航。
- 新建文件/目录先查 [结构地图](STRUCTURE.md)第六节；新目录须授权，已有目录不扩大用途。临时材料进 `tmp/`，需求执行材料按归属进 runtime；不在根目录随手写文件，不自行生成备份或快照。
- worktree 创建/删除、分支发布、数据库操作先读对应规则并走受控入口；预览和确认按对应规则执行，失败不得用底层命令或其他目录绕过。Agent 创建/删除调用使用 JSON 结果，完成后核验代码位置索引同步。
- 以最新适用 spec、项目规则和源码为准，不用会话记忆或交接覆盖实时事实。执行中确认的方案变化按生命周期回写；阶段完成、暂停、阻塞或切换 Agent/客户端前，按 [交接规则](rules/handoff.md)自动维护交接，无需询问。
- 公共角色、风格和工具细则留在 工作站；项目入口只路由并维护项目事实，不复制公共规则。不得自行修改受保护配置，不预读或输出密钥；读取说明不等于工具、Hook 或权限已启用。
- 首版人工代码导航图仅在用户明确要求时生成；开发完成、检查报告、提交或上线前 Review 不构成生成授权，不预建 `runtime/code-review/` 或更新历史图。

## 按需路由

命中意图后，先读对应入口再操作；参数与细则以目标文件为准。

| 当前任务 | 入口 |
| --- | --- |
| 新需求、设计、方案变更或阶段同步 | [生命周期](rules/task-lifecycle.md)、[设计规则](rules/design.md) |
| 生成/维护需求 README | [README 模板](rules/brief-readme-template.md) |
| 接手代码实施、加载角色/风格或发现执行能力 | [执行入口](rules/execution-entry.md) |
| 上线前 Review / 指定审查职责 | [Review 角色](rules/review-role-guide.md) → 标准与报告；默认只读，只审本次 diff 及直接调用链 |
| Git 看板、worktree 管理、发布到指定分支 | [脚本索引](scripts/INDEX.md)对应段；创建/删除再读 [worktree 规则](rules/worktree.md)，冲突再读 [核验规则](rules/merge-verification.md) |
| 数据库与测试 Redis（可选） | [脚本索引](scripts/INDEX.md)数据库段；安装后读取 `skills/db-analysis/SKILL.md`，以工具包现有只读边界为准 |
| 云效任务、迭代、流水线（可选） | 安装后读取 `.codex/skills/yunxiao-workstation/SKILL.md`；未安装则报告未启用，不自行注册工具 |
| 业务排查、配置或接口验证资料 | [业务资料入口](knowledge/README.md)，只读相关专题 |
| Java/Maven 后端构建/测试 | [验证规范](rules/verification.md)；其他技术栈按项目实际入口 |
| 测试说明 / 改动检查报告 / 明确要求的人工导航图 | [测试说明](rules/tester-note.md) / [检查报告](rules/change-report.md) / [首版导航](rules/first-pass-code-review.md) |
| 结构、规则维护或治理问题 | [结构地图](STRUCTURE.md)、[规则索引](rules/INDEX.md)；治理问题再读 [治理说明](governance/agent-guard/README.md) |
| 记录待改进计划 / 引入新项目 | [计划入口](plans/README.md)（记录不等于实施授权） / [项目接入指南](vibe-coding-新项目初始化指南.md) |

## 检索与沟通

- 先通过项目导航和精确检索定位，再核验源码。FastCtx 可用时，文件定位优先 `glob`，内容/上下文优先 `grep`，多文件批读用 `inspect_local_file`；复杂正则、中文及转义风险高的查询使用 FastCtx。Git、构建、测试和管道处理用 Shell。
- 穷尽性结论需说明范围：优先 `head_limit: 0` 单次取全；触及上限先收窄再查，不能用截断结果证明“已找全”。offset 跨页仅用于期间无写入的目标；`Complete` 不代表多页属于同一快照。
- FastCtx grep 遵守忽略规则；查忽略内容用 `rg --no-ignore`，发现忽略文件用 `glob` 的 `filter_mode: "all"`。跨工具比较先统一口径。
- 回答分 `[直接执行]`（结果）与 `[深度交互]`（必要的目标质疑、代价或替代建议），不为凑结构反复解释。Git 只读看板只展示结果和必要标题，细则见脚本索引。
- 目标不清、关键路径取舍、越界影响或破坏契约需先对齐，暂停依赖该决定的操作；不妨碍安全的只读核验。发现更短、更低成本路径应直接说明。
