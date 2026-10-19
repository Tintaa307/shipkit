---
name: security-audit
description: Runs a periodic security audit on what changed in a period (new entry points, permissions, tenant isolation, data leaving the system, secrets). Verifies every finding before reporting it and turns each confirmed one into a fix and an automated rule that catches it next time. Use once a month or before a big release.
argument-hint: "[since which date or commit; default: the last month]"
disable-model-invocation: true
model: opus
---

# Periodic security audit

An audit is deep sampling; invariants and lint are coverage. This skill does the first and feeds the second. And an audit is a hypothesis: recommendations applied as written can break billing, onboarding or invitations. Nothing is reported without verification.

```
- [ ] 1. Scope
- [ ] 2. Review by family
- [ ] 3. Findings verified
- [ ] 4. Report
- [ ] 5. Fix and rule per finding
```

## 1. Scope
- What landed in the period: `git log --since=<date> --oneline <main-branch>`.
- Of that, what matters most: new entry points (server actions, route handlers, crons, webhooks, MCP/API tools), migrations and permission changes.
- With a code-graph tool if you have one, check impact of the changes to prioritize what has little test coverage.

## 2. Review by family
- **The database allows more than the app:** grants, exposed `security definer` functions, policies that do not require the right permission.
- **Tenant isolation:** the tenant/org id on every query that bypasses row-level security (service-role clients), the active tenant resolved from a validated session and never from a raw cookie or client input.
- **Permissions or second factor** declared but not enforced.
- **Data leaving the system:** logs, error trackers, raw errors returned to the client.
- **Rate limits** on public routes.
- **Trusting outside data:** OAuth `state`, `?next` redirects, payment ids, webhook payloads (verify signatures).
- **Secrets** in the repo or in client bundles.
- **Dependencies:** known-vulnerable packages (`npm audit` / `pip-audit` / equivalent).

Add one pass with the built-in security review (`/security-review` in Claude Code) over the period's diff, as one more pair of eyes and not the only one.

## 3. Verify
Reproduce every finding before reporting it, with a test or a read-only query. Also prove that the proposed fix does not break a real flow.

## 4. The report
Write `docs/audits/<YYYY-MM-DD>/README.md`: confirmed findings with severity, evidence and proposed fix, and discarded ones with the reason.

## 5. Fix and rule
Each confirmed finding leaves two things:
- a ticket for the fix (priority by severity);
- the rule that detects it next time: a lint rule, a structural test, a database invariant, or a line in the folder's agent docs.
