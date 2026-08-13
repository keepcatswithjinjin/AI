---
name: yunxiao-workstation
description: >-
  Use this skill when Codex needs to manage Alibaba Cloud Yunxiao/云效 DevOps work inside a multi-project workstation: read work items by ID, query current requirements/tasks/bugs, perform fuzzy project or requirement lookup, inspect organizations/projects/sprints, create or update work items after confirmation, list or inspect pipelines, or connect Yunxiao work items with local briefs/worktrees. Use a workspace-local yunxiao MCP and personal config; never expose tokens.
---

# Yunxiao Workstation

Use the workspace-local `yunxiao` MCP for live Yunxiao data. Use the local personal config as the routing source of truth for organizations, projects, aliases, custom codes, and optional pipeline grouping.

## Required setup check

1. Use the MCP tools exposed by the `yunxiao` server when available.
2. Before task or pipeline listing, read the workspace-local personal config, normally `<WorkspaceRoot>\.codex\secrets\yunxiao.personal.json`.
3. If the personal config is missing, empty, or has no organizations/projects for the request, stop and ask whether to initialize or update the Yunxiao organization/project directory. Do not auto-scan every organization without user direction.
4. Call `get_current_organization_info` only when needed to confirm the current user/default organization or to refresh the personal config.
5. If Yunxiao tools are not available in the current session, report that the local MCP is configured but the session likely needs reload. Do not guess task data.
6. Never print, copy, summarize, or write `YUNXIAO_ACCESS_TOKEN`.

Workspace-local files:

- MCP entry: `<WorkspaceRoot>\.codex\mcp\yunxiao-mcp.cmd`
- Secret file: `<WorkspaceRoot>\.codex\secrets\yunxiao.env.cmd`
- Personal config: `<WorkspaceRoot>\.codex\secrets\yunxiao.personal.json`

The personal config is user-owned local state. It may contain organization IDs, project IDs, aliases, pipeline environment grouping, and secret-file references. Do not treat its contents as public skill behavior.

## Safety boundary

Read [references/safety.md](references/safety.md) before any operation that creates, updates, transitions, comments on, or runs anything in Yunxiao.

Default policy:

- Read-only listing and inspection can execute directly, including reading full work item content by ID.
- Creating/updating work items, adding comments, running pipelines, updating pipelines, creating branches, or creating MRs requires a concise preview and explicit user confirmation.
- Showing a preview is read-only and does not require approval. Generate the preview directly, then wait for explicit confirmation before calling the mutating MCP tool.
- Pipeline execution must show pipeline name/id, branch/params, expected environment, and external effect before running.
- If the tool response is ambiguous, stop and ask for clarification instead of choosing a project, sprint, or pipeline by guess.

## Direct work item reading

When the user specifies an exact work item number such as `YQPN-205` or `PROJ-123`, read the content directly without extra approval:

1. Read the personal config and use `customCode`, project aliases, or organization aliases to resolve candidate projects.
2. If the config cannot resolve the prefix/project, ask whether to initialize or update the organization/project directory.
3. Prefer a single `search_workitems` call with `includeDetails: true` in the resolved project and category. Filter returned items by exact `serialNumber`. Do not search the serial number as `subject`; Yunxiao serial numbers are not title text.
4. Call `get_work_item` only when the exact item cannot be returned with details from `search_workitems`, or when the user already provided an internal work item id.
5. Do not read comments, attachments, or activities by default. Only call `list_work_item_comments`, `list_workitem_attachments`, or `list_workitem_activities` when the user explicitly asks for comments, attachments, activity history, audit trail, or complete collaboration records.
6. Summarize in implementation-friendly form: background, scope, business rules, acceptance criteria, open questions, and risk points.

Do not ask for confirmation for read-only detail retrieval. Minimize MCP calls because some clients request approval per MCP tool call. Ask only when multiple exact serial-number matches appear across organizations.

## Task management workflow

For “当前任务 / 我的任务 / 需求列表 / bug / 工作项 / 迭代”:

1. Read the personal config first.
2. Resolve the requested organization/project from local aliases, ids, names, or custom codes.
3. If the user asks for current tasks without narrowing the scope, use all organizations/projects listed in personal config as the allowed scan set.
4. Search work items by resolved project:
   - categories: `Req`, `Task`, `Bug`
   - common assigned filter: `assignedTo: "self"`
   - common active statuses: 待处理、进行中、开发完成、测试中
5. Distinguish project demand pools from items assigned to the current user.
6. Return a compact table: organization, project, type, id, title, status, assignee, sprint, updated time.
7. If the user asks to start development from a work item, connect the selected work item to the workstation brief/worktree workflow; do not infer code branches from Yunxiao alone.

For detailed parameters and status codes, read [references/workflows.md](references/workflows.md).

## Work item creation routing

When creating a Yunxiao work item:

1. If the user does not explicitly say whether to create a `需求` / `任务` / `缺陷`, stop and ask which type to create.
2. If the user does not explicitly say which project/menu/pool to create it under, stop and ask for the target organization/project or recognizable project alias.
3. Map user wording strictly:
   - `需求` -> category `Req`; use the project default requirement type unless the user chooses a specific requirement subtype.
   - `任务` -> category `Task`.
   - `缺陷` / `Bug` -> category `Bug`.
4. Before creation, generate a preview directly. The preview must use human-readable names for organization, project/menu, work item category/type, assignee, participants, trackers, and status expectation. Include IDs only as supplemental technical details.
5. Call `create_work_item` only after explicit confirmation, then immediately call `get_work_item` and report the returned serial number, type, project, status, and assignee.

## Personal configuration maintenance

When the user asks to update Yunxiao organization/project configuration:

1. Read the personal config if it exists.
2. Use read-only MCP calls: `get_current_organization_info`, `get_user_organizations`, and `search_projects`.
3. Update organizations and projects with ids, names, custom codes, and aliases.
4. Preserve manually curated aliases unless they are clearly obsolete.
5. Keep secrets as references only; do not write token values into JSON.

## Pipeline workflow

Pipeline automation is optional and should stay disabled until the user curates a local whitelist.

For “流水线 / 构建 / 发布 / 日志 / webhook / 运行 pipeline”:

1. Read the personal config first.
2. If `pipelines.test` and `pipelines.production` are empty, report that pipeline automation is not configured. Listing/searching visible pipelines is allowed as read-only discovery when the user asks.
3. Only execute pipelines that are explicitly present in the local whitelist and `enabled: true`.
4. For inspection, directly read latest run and logs.
5. For execution, preview target pipeline, branch, params, environment variables, and expected effect; wait for confirmation.
6. After execution, poll run status and summarize result with direct evidence.

Read [references/workflows.md](references/workflows.md) for tool names and argument patterns.
