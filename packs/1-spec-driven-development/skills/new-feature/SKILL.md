---
name: new-feature
description: Turns an idea or ticket into an approved spec that is ready to implement. Maps the impact with the explorer agent, interviews the requester, writes the spec to docs/product/, sets a risk level, splits the work into slices under ~400 lines and, if the work is high-risk or multi-slice, opens an execution plan. Use when someone wants to start a feature, a behavior change or any non-trivial fix.
argument-hint: "[ticket id or description]"
disable-model-invocation: true
model: opus
---

# New feature: from idea to approved spec

The spec is where a human decides, before any code exists: fixing a spec costs a conversation, fixing an implementation costs a PR. This skill does not write code.

Copy this checklist and tick it as you go:

```
- [ ] 1. Request read
- [ ] 2. Impact mapped by the explorer
- [ ] 3. Interview done
- [ ] 4. Spec written
- [ ] 5. Slices and risk level defined
- [ ] 6. Execution plan opened (if high-risk or multi-slice)
- [ ] 7. Definition of Ready met
- [ ] 8. Approved by a human
- [ ] 9. Branch, spec PR and tickets created
```

## 1. The request
- With a ticket id or link: fetch it with whatever tracker tool is available (an MCP server, `gh issue view`, etc.).
- With a description: use it as-is and note that there is no ticket yet.

## 2. The impact
Delegate to the `explorer` agent with the description. Its map (files, dependents, tests, rules, reusable pieces, risk level) is the basis of the interview: do not ask what the code already answers.

## 3. The interview
Use AskUserQuestion, a few questions at a time, and only what neither the code nor the project docs answer. Keep going until you cover:
- Who benefits and what problem it solves. Which role sees it, on which plan or tier, whether it consumes quota.
- What happens to existing data.
- Whether it touches permissions, money, customer-facing emails, or anything irreversible.
- Whether it needs a migration.
- How we know it works: one criterion verifiable end to end.
- What is out of scope.

If an answer sets or changes a business rule, write it down: it goes in the project's glossary/decision log in the spec PR.

## 4. The spec
Write it with [spec-template.md](spec-template.md) at `docs/product/<ticket>-<slug>.md` (no ticket: `docs/product/<slug>.md`). It must stand on its own: name files and interfaces, say what is out of scope, and end with the end-to-end verification.

## 5. Slices and risk level
- Each slice is one PR under ~400 changed lines, with a single purpose, that can be merged without breaking anything.
- A database migration is its own slice, before the code that uses it. A contraction (drop/rename) is also its own slice, at the end.
- Risk level comes from the paths touched. Use the project's own rules if they exist (CLAUDE.md / AGENTS.md); otherwise default to:
  - **red:** migrations, auth and permissions, payments/billing, secrets, CI and infra config.
  - **yellow:** the rest of the backend, cron jobs, public API, emails.
  - **green:** UI, docs, tests.
  The feature's level is the highest of its slices.
- Each slice carries a **Model** for the `implementer`: `opus` for red, `sonnet` for yellow/green, `haiku` only for mechanical green work.
- If the explorer flagged problems in files the slice touches (missing validation, duplicated helpers, oversized files), include them in that slice only if it stays under ~400 lines. Otherwise list them under "Open questions" as a separate ticket.

## 6. Execution plan
If the feature is red or has more than one slice, open `docs/plans/<ticket>-<slug>.md` with: goal, slices in order, progress log, surprises/discoveries, and decision log. Update it as slices land.

## 7. Definition of Ready
Do not continue if any is missing:
- It is clear who it is for and how we know it worked.
- It has a risk level and, if red, the business decision is already made.
- It says what happens to existing data.
- Every slice fits under ~400 lines.

## 8. Approval
Show the summary (purpose, acceptance criterion, risk level, slices) and ask for the decision with AskUserQuestion: approve, change, or discard. Without an explicit "approve", do not move on.

## 9. Branch, spec PR and tickets
- **Red or multi-slice:** branch `docs/<ticket>-<slug>` with the spec, the execution plan and any glossary/decision-log changes. Open the PR. **Merging it is approving the spec**: slices start from the base branch with the spec in it.
- **Green or yellow, single slice:** branch `<type>/<ticket>-<slug>` with the spec committed. `implement-slice` continues on that branch and the spec travels in the same PR as the code.
- Ask whether to create the slices as tickets (`Slice N: …`, description with the spec path). If the original ticket exists, move it to in-progress.

## What you hand back
- The spec path, the plan path if any, the branch and the PR if opened.
- The slice table: number, what it does, risk level, model, dependencies.
- The next step: `/implement-slice <spec> <slice>`, in a fresh session and its own worktree. If the slice asks for `opus`, start that session on Opus.
