# ship-it-ar

Six battle-tested packs for [Claude Code](https://claude.com/claude-code), extracted from a real production codebase and generalized for any project. Build a SaaS, an ecommerce or anything in between: from spec to production, **including charging, invoicing and shipping in Argentina**. Each pack is a set of skills (and, for pack 1, sub-agents) you can drop into `.claude/`.

| # | Pack | Skills / agents | What it does |
|---|------|-----------------|--------------|
| 1 | [Spec-Driven Development](packs/1-spec-driven-development) | `/new-feature`, `/implement-slice` + agents `explorer`, `implementer`, `verifier`, `reviewer`, `searcher` | Idea → approved spec → slices under ~400 lines → agent team implements → PR with evidence. |
| 2 | [Debug, test first](packs/2-debug-test-first) | `/debug` | Reproduce, localize, minimize, write a failing test, fix the root cause, leave a guard. |
| 3 | [Security audit](packs/3-security-audit) | `/security-audit` | Monthly audit of what changed. Every finding is verified, then becomes a fix **and** an automated rule. |
| 4 | [Safe migrations](packs/4-safe-migrations) | `/safe-migration` | Postgres/Supabase migrations with expand → migrate → contract, RLS, grants and post-checks. |
| 5 | [UI verification](packs/5-ui-verification) | `/verify-ui` | Opens the running app, takes desktop + mobile screenshots, collects console/network errors. |
| 6 | [Argentina Commerce Stack](packs/6-argentina-commerce-stack) | `/arca-invoicing`, `/rebill-subscriptions`, `/mercadopago-payments`, `/correo-argentino-shipping` | Invoice with ARCA, bill with Rebill or Mercado Pago, ship with Correo Argentino. |

## Install

```bash
git clone https://github.com/Tintaa307/ship-it-ar
cd ship-it-ar

# into the current project (.claude/)
./install.sh

# only some packs
./install.sh 1 2 6

# globally (~/.claude)
./install.sh --global
```

Or copy any `skills/<name>` folder into your project's `.claude/skills/` and any `agents/*.md` into `.claude/agents/` by hand.

## How the packs fit together

```
/new-feature  →  spec approved by a human
/implement-slice  →  explorer → implementer → verifier → reviewer → PR
      ├─ uses /verify-ui for UI evidence
      ├─ uses /safe-migration when the slice is a DB change
      └─ uses /debug when a bug shows up
/security-audit  →  run monthly or before a big release

Pack 6 (commerce): payment webhook → ledger → ARCA invoice + Correo Argentino shipment
```

## Adapting them to your project

The skills are intentionally stack-agnostic. They look for your project's own commands and rules (`CLAUDE.md`, `AGENTS.md`, `package.json` scripts, CI config). To get the most out of them:

- Put your **verify command** (typecheck + lint + tests) in `CLAUDE.md`.
- Define your own **risk levels** (which paths are red/yellow/green) in `CLAUDE.md`; otherwise sensible defaults are used.
- Agents declare a `model` (`haiku` / `sonnet` / `opus`) in their frontmatter so cheap steps run on cheap models. Change them to taste.
- If you have a code-graph or code-search MCP server, the explorer and searcher agents will benefit from it; they fall back to Grep/Glob.

## Requirements

- Claude Code
- Git, plus `gh` if you want PRs opened from the CLI
- Pack 4: Postgres (written for Supabase, works with any Postgres migration tool)
- Pack 5: Node 18+ and [Playwright](https://playwright.dev)
- Pack 6: accounts and credentials with each provider (ARCA certificate, Rebill, Mercado Pago, Correo Argentino). Always test in their sandboxes first.

## License

MIT

## Disclaimer
Pack 6 is engineering guidance, not legal or tax advice. Provider APIs change: confirm details against each provider's current documentation.
