# Security boundaries

Rules guide agents; scripts validate their own operations; hooks cover supported tool events only. None replaces OS permissions, Git hosting protections or human review. Unsupported clients and execution paths may not invoke hooks.

Use least-privilege credentials. Do not publish tokens, database configurations, approval files, session logs or customer data. Optional tools remain disabled until locally configured.

Do not open public issues containing secrets or exploit details. A private reporting channel has not yet been configured; establish one before public release. Revoke exposed credentials immediately. No response-time or security-audit guarantee is currently offered.
