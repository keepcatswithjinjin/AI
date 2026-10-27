# Safety Model

The script enforces two layers of protection.

## Account check

Before any target operation, it runs:

```sql
SHOW GRANTS FOR CURRENT_USER();
```

It refuses accounts with write or administrative privileges such as `ALL PRIVILEGES`, `INSERT`, `UPDATE`, `DELETE`, `CREATE`, `DROP`, `ALTER`, `GRANT OPTION`, `EXECUTE`, and similar grants.

This check is best-effort for MySQL grant strings. It cannot replace a real read-only database account.

## SQL check

For `-Action query`, only these statement families are allowed:

- `SELECT`
- `SHOW`
- `DESCRIBE`
- `DESC`
- `EXPLAIN`
- `WITH`

The script rejects multi-statement SQL and common write/admin operations.

For PostgreSQL-compatible targets, it additionally rejects `SELECT INTO`,
`COPY`, `DO`, `CALL`, locking clauses, maintenance commands, and known
server-control functions. It requires explicit approved `schema.table` sources
and supplies a read-only session setting plus a bounded statement timeout.

## Operating rule

If the account check fails, create a dedicated read-only account instead of bypassing the script. The only exception is a deliberately configured test target with both `environment: test` and `allowPrivilegedTestAccount: true`; its SQL checks remain read-only and it must still be allowed by the Hook policy.

## Redis test provider

Redis test accounts may have write permissions. The provider permits only `PING`, exact-key metadata (`TYPE`, `TTL`, type-specific length), bounded `GET`/`HGET`, and one-page `SCAN` with a literal prefix. It sends no arbitrary command text, checks value lengths before retrieval, caps SCAN work at `COUNT 100`, and never loops through the complete keyspace in one request. SCAN `COUNT` is a hint rather than an exact result limit; returned keys are truncated for display. The Hook blocks direct `redis-cli` invocation and allows only explicit target/action names.
