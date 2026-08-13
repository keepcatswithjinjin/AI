# Yunxiao MCP Workflows

Use these names as the preferred MCP calls when the `yunxiao` server is exposed.

## Initialization

1. Read `<WorkspaceRoot>\.codex\secrets\yunxiao.personal.json`.
2. If it contains matching organizations/projects, use it as the allowed routing directory.
3. Use `get_current_organization_info({})` only when the current user/default organization must be confirmed or the user asks to initialize/update the directory.
4. If the user asks to initialize/update the directory, call `get_user_organizations({})` and then `search_projects` for each selected organization.
5. Do not scan every returned organization for ordinary task listing unless the user has approved initialization/update or the organizations already exist in the personal config.

## Project discovery

When updating the local directory, search projects in each selected organization:

```json
{
  "organizationId": "<org>",
  "scenarioFilter": "participate",
  "userId": "<current-user-id>",
  "page": 1,
  "perPage": 20
}
```

If user names a project and it is not in personal config, ask whether to update the directory. After confirmation, use:

```json
{
  "organizationId": "<org>",
  "name": "<project-name>",
  "page": 1,
  "perPage": 20
}
```

## Work item search

Tool: `search_workitems`

Common categories:

- `Req`: 需求
- `Task`: 任务
- `Bug`: 缺陷

Creation wording must map strictly:

- User says `需求`: create category `Req`; choose the default enabled requirement type when the user does not specify a subtype.
- User says `任务`: create category `Task`.
- User says `缺陷` or `Bug`: create category `Bug`.
- User omits the category: ask before previewing or creating.
- User omits the target organization/project/menu: ask before previewing or creating, unless a local alias resolves to exactly one configured project.

Common active query:

```json
{
  "organizationId": "<org>",
  "spaceId": "<project-id>",
  "category": "Task",
  "assignedTo": "self",
  "includeDetails": false,
  "page": 1,
  "perPage": 20
}
```

When the user says “与我有关”, treat it as broader than assignee:

- assignedTo is current user
- creator is current user
- modifier is current user
- participants contains current user
- trackers contains current user

If the MCP does not expose a direct participant/tracker filter, fetch the project-level active work item pool and filter locally.

## Direct work item detail by serial number

If the user gives an exact serial number such as `PROJ-123`, first resolve its project by `customCode` or alias in the personal config. If no local route matches, ask whether to initialize/update the directory.

If the internal work item id is already known, call:

```json
{
  "organizationId": "<org>",
  "workItemId": "<internal-work-item-id>"
}
```

Tool: `get_work_item`

If the internal id is not known, prefer one `search_workitems` call per resolved candidate project with `includeDetails: true`. Do not put the serial number in `subject`; Yunxiao serial numbers are not title text. Filter the returned list locally by exact `serialNumber`.

```json
{
  "organizationId": "<org>",
  "spaceId": "<project-id>",
  "category": "Req",
  "includeDetails": true,
  "page": 1,
  "perPage": 50
}
```

Then select the item whose `serialNumber` exactly matches the requested number. If the first page does not contain the exact item and pagination indicates more pages, continue page-by-page until the item is found or the project result set is exhausted. Use `get_work_item` only when `search_workitems(includeDetails=true)` cannot return the required detail.

Only call the following tools when the user explicitly asks for comments, attachments, activity history, audit trail, or complete collaboration records:

- `list_work_item_comments`
- `list_workitem_attachments`
- `list_workitem_activities`

Reading details is a read-only operation and does not require business confirmation. Minimize MCP calls because some clients request approval per MCP tool call.

## Work item changes

Read safety.md first. Then preview and wait for confirmation before:

- `create_work_item`
- `update_work_item`
- `create_work_item_comment`
- `create_effort_record`

Preview generation is read-only and does not require approval. The preview must be understandable without IDs:

```text
组织：<组织中文名>
项目/菜单：<项目中文名>
创建类型：<需求/任务/缺陷> / <具体类型中文名>
标题：<subject>
负责人：<姓名>
参与人：<姓名列表>
抄送人：<姓名列表>
描述：<简要描述>

技术细节：
- organizationId: <id>
- spaceId: <id>
- workitemTypeId: <id>
```

Only after the user confirms, call `create_work_item`. After creation, call `get_work_item` and report `serialNumber`, `workitemType.name`, `space.name`, `status.displayName`, and `assignedTo.name`.

## Pipeline inspection

Tools:

- `list_pipelines`
- `smart_list_pipelines`
- `get_pipeline`
- `get_latest_pipeline_run`
- `get_pipeline_run`
- `get_pipeline_job_run_log`

Visible pipeline lists are read-only discovery and are not executable whitelists.

## Pipeline whitelist shape

Keep the structure even when pipeline automation is disabled:

```json
{
  "pipelines": {
    "test": [],
    "production": []
  }
}
```

When the user later chooses to enable automation, a whitelisted pipeline can use:

```json
{
  "id": 123456,
  "name": "test-service-api",
  "organizationId": "<org-id>",
  "organizationName": "<org-name>",
  "environment": "test",
  "aliases": ["service-api-test"],
  "enabled": true,
  "requiresConfirmation": true
}
```

## Pipeline execution

Read safety.md first. Before `create_pipeline_run`, preview:

- pipeline id/name
- branch mode and branches
- repository binding when present
- environment variables or params
- expected deployment/build target

Only call `create_pipeline_run` after explicit user confirmation.
