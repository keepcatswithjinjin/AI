# 工作站结构地图

本文件登记文件归属与维护边界；具体操作规则只引用，不复制。模板只含通用框架，不携带真实业务、项目注册或本机配置。

## 一、目录地图

| 路径 | 职责 |
| --- | --- |
| AGENTS.md | 公共 Agent 入口：职责、核心约束与按需路由 |
| CLAUDE.md | 仅导入 AGENTS.md，不重复正文 |
| README.md | 人工概览与导航 |
| LICENSE | 随安装保留的 MIT 许可声明 |
| workstation-install.json | 框架版本、安装时间和选项；非业务状态，不代表自动升级 |
| .gitignore | 用户启用根目录本地 Git 后的排除边界；安装不自动 git init |
| rules/INDEX.md | 规则职责与同步清单 |
| rules/execution-entry.md | 执行身份、必需上下文与按需能力路由 |
| rules/brief-readme-template.md | 需求 README 的生成约定，不预建空 brief |
| rules/verification.md | Maven reactor 测试与验证证据 |
| rules/ | 设计、角色、风格、Review、交接与生命周期规则 |
| scripts/INDEX.md | 工作站脚本及可选工具入口 |
| scripts/new-worktree.*、remove-worktree.* | 受控创建/删除、JSON 结果与代码位置索引同步 |
| scripts/publish-to-branch.* | 发布、冲突输入冻结、核验及显式完成 |
| scripts/sync-workstation-state.ps1 | 登记与单向阶段同步，不推断部署成功 |
| scripts/worktree-locations.ps1 | 同一索引内的新旧位置适配，不维护第二份注册信息 |
| rules/worktree-locations.md | 一需求多前后端位置的精确标识与兼容规则 |
| governance/agent-guard/ | 现有跨 Agent 治理；受保护文件由人工维护 |
| .codex/、.claude/ | 工作站本地 Hook 模板；不修改用户级配置 |
| projects/ | 独立主项目容器；不得把业务代码提交到工作站仓库 |
| worktrees/ | 需求执行目录；不得在容器层开发 |
| briefs/INDEX.md | 复杂需求登记，不维护进度；登记时方案可尚不存在 |
| briefs/WORKTREE-INDEX.md | 需求代码位置与分支，执行前核验实时 Git |
| briefs/WORKSTATION-STATE.json | 状态脚本按需生成；不预填真实任务 |
| briefs/<类型>/<需求名>/README.md | 单需求导航，不复制公共规则 |
| briefs/<类型>/<需求名>/spec/ | 当前设计、契约、计划与按需测试说明 |
| briefs/<类型>/<需求名>/runtime/ | 阶段交接、验证证据、冲突核验及明确触发的代码导航 |
| knowledge/ | 可复用的业务知识、架构参考、操作方法与辅助能力；模板只有目录说明 |
| artifacts/ | 用户保存的参考附件与交付产物，不强制绑定需求 |
| tmp/ | 用户定期清理的临时杂物、缓存、profile 与中间文件 |
| plans/ | 待改进计划，不构成实施授权 |

可选能力：数据库安装到 scripts/ 与 skills/db-analysis/；云效安装到 .codex/mcp/ 与 .codex/skills/。真实目标配置、凭据及个人组织/项目资料不由通用模板维护。

## 二、唯一维护位置

- 项目注册与 worktree 路径：rules/worktree.md。
- 需求决策：当前 spec；阶段停点与证据：runtime/agent-guide.md，不能覆盖实时 Git。
- 公共身份、风格和工具细则：rules/ 与对应 Skill，不复制到每个需求。
- 业务知识：knowledge；原始附件及交付：artifacts，不靠附件推断需求状态。
- 数据库/云效工具与治理：保留各自配置边界，未安装不视为可用。

## 三、项目与 worktree

主项目位于 __WORKSPACE_ROOT__\projects\<项目>，执行目录位于 __WORKSPACE_ROOT__\worktrees\<项目>-worktree\<需求名>。注册表中的项目仅是待替换示例，不代表实际仓库存在。

通用模板按项目配置更新基线：根项目须干净且只允许快进，不丢弃用户改动；离线模式不联网、不切根项目分支。

## 四、维护联动

- 目录与入口变更：检查本文件、README、AGENTS、rules/INDEX；CLAUDE 只检查导入。
- brief 接入变更：检查执行入口、README 模板、设计、生命周期、角色与交接规则。
- 脚本行为变更：同步 scripts/INDEX 与对应规则，补充离线测试。
- 可选能力变更：基础安装和可选安装均须验证，不覆盖用户配置。
- 框架同步与升级：仅同步通用能力，业务、本地凭据和实例状态不进入模板。

## 五、Git 与历史资料

工作区默认不初始化 Git。用户明确启用本地规则版本控制后，业务仓库、briefs、知识内容、产物、运行材料和本机配置由 .gitignore 排除；模板框架本身由工具包仓库管理。

历史平铺 brief、旧交接、旧 artifacts 核验材料只兼容读取，不自动迁移删除；新材料按 spec/runtime 归属写入，不新增快照或 .bak。

## 六、文件创建与写入边界

- 新增文件先确定归属；新增目录先获授权。用户批准的固定目录模式可随对应任务创建，不逐次重复询问。
- 需求 README/spec/runtime、受控 worktree、需求内 merge-verification 及明确要求的 code-review 属于固定模式，不预建空文件。
- 根目录不承载临时 SQL、截图、查询输出或调试文件；临时材料进 tmp。
- 已有目录不等于允许扩大用途；没有合适位置先说明并申请，不自行建兜底目录。
- 不自动清理用户材料，不复制业务仓库源码，不读写凭据或修改受保护配置。
