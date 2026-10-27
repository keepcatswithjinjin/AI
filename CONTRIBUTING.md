# Contributing

Keep changes scoped to reusable workflow rules, templates, scripts and tests. Do not include business repositories, private knowledge, credentials, personal identities or generated workspace data.

Run with PowerShell 7 on Windows:

```powershell
pwsh -NoProfile -File ./check-environment.ps1
pwsh -NoProfile -File ./tests/test-workspace-template.ps1
```

Use disposable Git repositories for tests. Never use business remotes or production databases. Describe changes to authorization, destructive operations, template compatibility and dependencies explicitly. Keep generic defaults conservative; do not copy personal hard-reset policies.

The framework is licensed under MIT; see LICENSE. Contributions must be compatible with that license. Do not vendor third-party assets without their original notices. Installed tools and external services retain their own licenses and terms.
