---
name: verify-ui
description: Verifies a visible change in the running app against a test environment. Starts the dev server if needed, signs in with a saved test session, walks the screens from the acceptance criterion, takes desktop and mobile screenshots and collects console and network errors. Use after implementing a UI change or when a PR lacks visual evidence.
argument-hint: "[routes to visit, e.g. /dashboard /settings]"
---

# Verify in the app

UI evidence is looking at the screen, not assuming it "should work". Always against a test environment, never production.

```
- [ ] 1. App running against test data
- [ ] 2. Test session
- [ ] 3. Screenshots
- [ ] 4. Screenshots checked against the criterion
- [ ] 5. Report
```

## 1. The app
If `http://localhost:3000` (or the project's dev URL) does not respond, start the dev server in the background using the project's dev command. Check that its environment points to a **test** database, not production.

## 2. The session
Capture needs a signed-in browser state. Create a Playwright storage state for a **test user** (log in once with Playwright codegen or a script and save it with `context.storageState({ path: 'e2e/.auth/user.json' })`). Never use real customer credentials. If the app is public, skip this step.

## 3. The screenshots
Install Playwright once if missing (`npm i -D playwright && npx playwright install chromium`), then:

```
node scripts/capture.mjs --out .captures/<branch> [--base http://localhost:3000] [--state e2e/.auth/user.json] <route> [<route> …]
```
(`scripts/capture.mjs` is in this skill's folder; copy it into the project or call it by its full path.)
- Takes one screenshot per route at desktop (1440 px) and mobile (390 px).
- Reports console errors, failed requests and 4xx/5xx responses for each screen.
- Exits non-zero if any screen had errors, so it can be used in a loop.

## 4. Look
Open each screenshot with Read and compare it to the spec's acceptance criterion and to the project's design guide. Anything that does not match is a finding: do not fix it from here.

## 5. The report
Per route: what is seen, what matches the criterion and what does not, plus console or network errors. Screenshots stay in `.captures/`, which should be git-ignored because the test database can hold customer-like data: do not upload them anywhere without looking at them first.
