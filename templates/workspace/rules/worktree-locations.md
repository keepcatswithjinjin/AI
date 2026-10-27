# 一需求多代码位置

需求可以关联多个后端、多个前端项目；同属需求不代表相互依赖。项目仍登记在 worktree.md，位置唯一维护于 briefs/WORKTREE-INDEX.md。

- 原 cross/backend/frontend 表不迁移。新增带 LocationId 的位置追加到同一索引的 `## locations-v2` 表，不预建真实记录。
- 表列依次为 RequirementKey、LocationId、Role、ProjectKey、Path、Branch、Group、Note。
- RequirementKey 为 type:name；LocationId 在需求内唯一、稳定，建议 role-projectkey。Role 为 backend/frontend；单端需求可有多个同角色项目。
- Group 是可选 kebab-case 标签，不决定依赖或顺序；实际协作关系写 design 与计划。
- 创建用 `new-worktree.cmd -ProjectKey <key> -Name <name> -RequirementKey <type:name> -Role <role> -LocationId <id> -Preview -OutputFormat Json`；可加 LocationGroup、BaseBranch、Remote。确认后移除 Preview。
- 清理用 `remove-worktree.cmd -WorktreePath <path> -RequirementKey <type:name> -Role <role> -LocationId <id> -Preview -OutputFormat Json`；确认后移除 Preview 并加 Confirm。ID、角色、路径必须匹配。
- 同仓前后端复用一个物理位置，在计划说明职责；不重复创建同一工作区。
- 多位置逐个执行；失败保留成功项，不自动删除回滚。索引同步失败返回 partial，核验现场再继续。
- 状态检查合并旧表与新表；仍有任一有效位置存在时不能推进 Released。清理不等于已部署，仍须用户确认。
- 新表不省略 LocationId；旧表继续使用旧创建/清理机制。发布可从新表定位需求 runtime，但发布授权与冲突核验不放宽。
