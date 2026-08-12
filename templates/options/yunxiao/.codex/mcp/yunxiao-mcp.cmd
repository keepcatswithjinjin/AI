@echo off
setlocal

set "SECRET_FILE=%~dp0..\secrets\yunxiao.env.cmd"
if exist "%SECRET_FILE%" call "%SECRET_FILE%"

if "%YUNXIAO_ACCESS_TOKEN%"=="" (
  echo YUNXIAO_ACCESS_TOKEN is not configured. Create %SECRET_FILE% from yunxiao.env.example.cmd. 1>&2
  exit /b 1
)

if "%DEVOPS_TOOLSETS%"=="" (
  set "DEVOPS_TOOLSETS=organization-management,code-management,project-management,pipeline-management"
)

call npx.cmd -y alibabacloud-devops-mcp-server
