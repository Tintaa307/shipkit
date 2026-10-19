---
name: safe-migration
description: Writes and tests a database migration (Postgres / Supabase) without breaking the code that already runs. Fixes the phase (expand, migrate or contract), locks down default grants, handles security-definer functions, policies and foreign keys, applies it to a test database, checks it against the database and regenerates types. Use for any schema, permission, function, trigger or policy change.
argument-hint: "[what changes in the database]"
model: opus
---

# Safe migration

A migration is the one thing a new deploy cannot undo. This is the procedure. Production is not touched from here: a human applies it before releasing.

```
- [ ] 1. Phase decided
- [ ] 2. File created with the CLI
- [ ] 3. SQL written with the rules
- [ ] 4. Applied to the test database
- [ ] 5. Checked against the database
- [ ] 6. Types regenerated
- [ ] 7. Migration PR, on its own
```

## 1. The phase (expand → migrate → contract)
Every migration coexists with the code that is already running.
- **expand:** adds (tables, nullable columns or columns with a default, functions, indexes). Old code keeps working.
- **migrate:** moves or backfills data.
- **contract:** drops or renames the old thing. Only when no code uses it. It goes alone and last.

### Before a contract: is "no code" really true?
A contract ships without code **only if nothing uses the thing anymore**. Check before planning, not while writing:
1. Grep the column/table name and whatever writes it: services, repositories, tests, generated types and scripts. A code index will not see unpublished branches.
2. If code still reads **or writes** it (a "backup" that is still written counts), the contract is **two PRs**: first a code PR that stops using it, shipped and deployed; only then the migration. Otherwise the running production code writes a column that no longer exists.
3. On a read-only production connection, confirm no function, view, index, constraint, policy or trigger names it (`pg_proc`, `pg_get_viewdef`, `pg_indexes`, `pg_constraint`, `pg_policies`, `pg_trigger`). Look at what data it holds, so the PR says what is lost.

## 2. The file
Create it with the migration CLI (e.g. `supabase migration new <snake_case_name>`) so the timestamp is right. First line: `-- phase: expand`, `-- phase: migrate` or `-- phase: contract`, followed by a comment on why it exists.

## 3. The SQL
Before writing, look at how the latest migrations in the repo solve the same thing. The rules:
- **New table:** `alter table … enable row level security`, policies using the project's membership helper functions, and `revoke all on table public.<table> from anon, authenticated` before granting only what is needed.
- **`security definer` function:** `set search_path to 'public'`, and `revoke all on function public.<fn>(<args>) from public, anon, authenticated` unless it must be executable. In that case the reason goes in a comment.
- **Foreign keys to tenant/org tables:** declare their `on delete` explicitly.
- **Idempotent when possible:** `if not exists`, `create or replace`.
- **Nothing destructive** (`drop`, `rename`, `alter … type`) outside a contraction.
- **Indexes on big tables:** think about the lock they take (`create index concurrently` where the tool allows it).

## 4. Test database
Apply to the **test** database only. If the CLI says the history diverges, stop: repair it with the CLI's repair command, never by applying again.

## 5. Check against the database
Run the queries in [checks.sql](checks.sql) against the test database: what must exist exists, RLS is on, grants are the expected ones, functions have their `search_path`. Paste the output in the PR description.

## 6. Types
Regenerate the database types with the project's generator and commit the result.

## 7. The PR
Only the migration and the types, in their own PR, treated as red/high risk. A contract also names the code PR that stopped using what it drops and confirms it is already in production. The description carries the phase, what you checked on the test database and the instruction for the human: "in production this is applied at release time, from an up-to-date base branch, and only then is the release PR merged".
