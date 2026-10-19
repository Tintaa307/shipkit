---
name: implement-slice
description: Takes one slice of an approved spec all the way to a PR ready for review. Prepares the branch, asks the explorer for a map, plans, delegates the code to the implementer, checks it with the verifier, runs it past the reviewer and opens the PR with evidence, with at most two fix rounds. Use with a spec approved by /new-feature, in a fresh session per slice.
argument-hint: "[spec path] [slice number]"
disable-model-invocation: true
model: sonnet
---

# Implement a slice

Fixed steps (deterministic commands) interleaved with agent steps (small boxes with an input and an output). You orchestrate: the `implementer` writes the code, not you.

Never finish while the project's verify command is failing. Two fix rounds at most; on the third failure, stop and report.

```
- [ ] 1. Spec and slice read, Definition of Ready met
- [ ] 2. Branch ready
- [ ] 3. Map from the explorer
- [ ] 4. Plan
- [ ] 5. Code (implementer)
- [ ] 6. Verification (verifier), round 1 of 2
- [ ] 7. Screenshots, if UI
- [ ] 8. Review (reviewer), round 1 of 2
- [ ] 9. Commit, push and PR
- [ ] 10. Ticket and plan up to date
```

## 1. Spec and slice
- Read the spec and the requested slice. The spec must be approved: merged to the base branch, or, if single-slice, on the branch `/new-feature` left. If not, stop and suggest `/new-feature`.
- If the slice is a database migration, follow the `safe-migration` skill instead of steps 4 to 6.

## 2. The branch
- One session, one slice. If you are not in your own worktree (`git rev-parse --git-dir` equals `git rev-parse --git-common-dir`), say so before continuing.
- If the spec already created the branch, stay on it. Otherwise: `git fetch origin` and `git switch -c <type>/<ticket>-<slug> origin/<base>` (type: feat, fix, refactor, perf, chore, docs, test).

## 3. The map
Delegate to the `explorer` with the spec, the slice and the request "what gets touched, what can break, and what already exists to reuse". If its risk level differs from the spec's, the higher one wins: say so.

A narrow question at any step (where is X defined, which tests cover Y, what did CI say) goes to the `searcher`, which runs on Haiku: do not answer it by reading files with the session's model.

## 4. The plan
With the spec and the map: files, steps, and the tests that prove the acceptance criterion. Keep it short. Also:
- **Reuse:** the pieces the spec and the explorer listed. Creating something new needs a written reason in the plan.
- **Cleanups:** the ones the explorer flagged enter if the slice stays under ~400 lines; otherwise they go to the report as a separate ticket.
- **If it reads data:** which performance rules apply and which screen/query is measured.

If there is an execution plan, log the start in its progress section.

## 5. The code
Delegate to the `implementer` with the plan and the map, using the model from the slice's **Model** column (the `model` parameter of the call). If the slice has none: `opus` for red, `sonnet` for yellow and green. Anything it returns under "Out of scope" is not done in this slice: it goes to the report.

## 6. Verification
Delegate to the `verifier`. If it says FAIL, go back to the `implementer` with the exact errors, then to the `verifier` again. After two failed rounds, stop and report the errors: do not keep trying.

## 7. Screenshots
If the slice touches UI, follow the `verify-ui` skill on the screens named in the acceptance criterion.

## 8. Review
Delegate to the `reviewer` with the spec, the slice and the risk level. If it asks for changes: `implementer`, `verifier`, `reviewer`. Two rounds at most; if it still asks for changes, stop and show the findings to the human.

**On a red slice, the review is adversarial.** Give the `reviewer` only the diff, the acceptance criterion and the rules, with the request "adversarial mode": no plan and no summary from the implementer, so it does not read the change through the story it was told. Classify each finding before acting: valid `contract` and `risk` findings get fixed; a `question` goes to the human; noise is dropped with a note on why. If the second round comes back with findings but none actionable, do not run a third: report.

## 9. The PR
- **Commit** with Conventional Commits and the ticket id: `feat(clients): renewal date in the table (1cd09066)`.
- **Description:** the repo's PR template if there is one, with the verifier's summary, the risk level, what stayed out of scope and the reviewer's review path.
- **Open it** against the base branch (`gh pr create --base <base> --title … --body-file …`). Never merge: a human does that.

## 10. Wrap-up
- If there is a ticket, leave it in-progress: a human closes it after merge.
- If there is an execution plan, update progress, surprises and the slice row.
- Report the PR link, risk level, rounds used, evidence and what stayed out of scope.
