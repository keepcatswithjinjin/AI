# Yunxiao Workstation Safety

## Do not expose secrets

- Never print `YUNXIAO_ACCESS_TOKEN`.
- Never copy secret file content into replies, commits, Markdown docs, or task comments.
- If debugging configuration, only report whether the token exists and can be loaded.

## Read-only operations

These can run directly:

- get organization/current user info
- list/search configured projects, sprints, work items, work item types, comments
- get full work item detail by exact ID or internal work item id
- list work item attachments and activities
- list/search pipelines, pipeline runs, pipeline logs
- list repositories, branches, merge requests
- update the local personal organization/project directory when the user explicitly asks to initialize or update it

## Mutating operations

Require a preview and explicit user confirmation:

- create or update work item
- transition status
- add comments
- create effort record
- create/update sprint
- create branch or merge request
- run pipeline
- update pipeline YAML/configuration

Showing the preview itself is read-only and must not be treated as an operation requiring approval.

The preview must include:

- target organization/project/pipeline/work item, shown primarily with human-readable names
- operation
- exact fields or params to be changed
- expected external effect

For work item creation previews, include:

- organization name
- project/menu name
- work item category in Chinese: 需求 / 任务 / 缺陷
- concrete work item type name, such as 产品类需求 / 技术类需求 / 任务
- title and description summary
- assignee, participants, trackers, verifier when present
- optional technical IDs in a separate detail block

## Ambiguity handling

Stop and ask when:

- multiple projects/pipelines match
- a task title is too vague
- a create request does not specify whether to create a 需求 / 任务 / 缺陷
- a create request does not specify the target organization/project/menu or a local alias that resolves to exactly one project
- target branch or environment is not explicit for pipeline execution
- the MCP result omits required ids

Do not resolve ambiguity from memory or old conversation state.
Do not broaden task or pipeline discovery beyond the local personal config unless the user asks to initialize or update the directory.

## Pipeline execution boundary

Visible pipelines are not automatically executable. Only pipelines explicitly listed in the local personal config and marked `enabled: true` are eligible for execution. Production pipelines should be empty by default and manually whitelisted.
