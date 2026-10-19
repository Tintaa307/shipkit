---
name: rebill-subscriptions
description: Builds or changes recurring-billing (subscriptions) with Rebill: card tokenization, checkout, renewals, webhooks, the payments ledger, plan/seat changes, past-due handling and reconciliation. Lists the rules that must not be broken and the tests that must exist. Use when working on checkout, subscription state or the Rebill webhook. Real money: treat as high risk.
argument-hint: "[what you need to build or change in billing]"
---

# Recurring billing with Rebill

A subscription flow is a distributed system: your database, the payment provider and the customer's bank each have their own truth, and events arrive late, twice or out of order. The rules below come from auditing a real subscription circuit and fixing twelve defects in it.

> Provider APIs evolve. Check Rebill's current docs (docs.rebill.com) for endpoints, webhook contract and retry strategy before coding, and test every flow in their sandbox. This skill gives you the **architecture and failure modes**, not an API reference.

```
- [ ] 1. Decisions written down (currency, grace, change rules)
- [ ] 2. Tokenize card, never touch PAN/CVV
- [ ] 3. Reserve an attempt, then charge
- [ ] 4. Webhook with three barriers
- [ ] 5. Ledger separate from entitlements
- [ ] 6. State transitions are compare-and-set
- [ ] 7. Reconciliation job
- [ ] 8. Test matrix
```

## 1. Decide first (these are business decisions, not code)
- **Price currency policy:** fixed local-currency price, or a USD price converted each cycle? If it renews in USD-converted terms you must **recompute and update the amount before every debit** and verify it — otherwise the checkout promises one thing and the bank charges another.
- **Grace period vs provider retries:** align your "past due" window with the provider's retry schedule. Do not mark a subscription expired locally while the provider keeps retrying charges: **cancel or reconcile the remote subscription first**, or the customer can buy a second plan while the first still bills.
- **Change rules:** proration for upgrades (charged now, separately), downgrades applied at renewal, monthly↔annual changes (supported or rejected explicitly).
- **Foreign customers:** processing country and currency are properties of the contract; do not silently route them through the local flow.

## 2. Tokenization and checkout
- Tokenize the card in the browser with the provider's SDK; your server only sees a token. Compute **price, seats and plan on the server**, never from the request.
- Reserve a local **attempt** row (with an idempotency key and the full frozen payload) before calling the provider. A retry with the same key must send the **same payload**: if the user changed plan after a timeout, the new request waits for the old attempt to resolve — never mix fields from two contracts.
- Pass your attempt id in the provider metadata so an orphan payment can be linked back (re-validate org, amount and currency against the API before trusting it).

## 3. Three outcomes, not two
Every charge ends as one of:
1. **Declined (terminal)** → close the attempt, show the decline reason.
2. **Pending** → keep the attempt and any payment links alive; do **not** cancel; a later webhook may approve it.
3. **Unknown** (timeout, lost response) → raise a dedicated "outcome unknown" error. **Never tell the user "you were not charged"** in this case. Confirm by re-reading the provider.
An HTTP 409 only proves a duplicate operation, not an approval.

## 4. The webhook: three barriers
1. **Secret path segment** (≥16 chars, timing-safe compare). Wrong or missing → **404**, not 401, so scanners do not learn the route exists.
2. **HMAC signature** over the **raw body bytes** with the webhook signing secret, compared timing-safe. Check the exact header and key format in the provider's current docs; implement one algorithm, not guesses. If signature enforcement is on but the secret is missing, **fail closed**.
3. **Re-confirm with the API.** Never grant anything from the webhook body: re-fetch the payment/subscription with your secret key and decide from that.
A signature proves origin, not freshness: deduplicate by the delivery/log id. Store deliveries in a durable inbox and process with leases so a crash does not lose events.

## 5. Ledger separate from entitlements
- One ledger row per provider payment. "Payment known" and "entitlement applied" are different states: a payment that arrives as `pending` and later `approved` must still be applied exactly once.
- Credit the payment and grant access only through **one** database function (transactional, with row locks). Do not dedupe by throwing away the second event.
- A late payment from an old/cancelled subscription must be credited to its history **without overwriting** a newer subscription's entitlement.

## 6. State transitions
- Use compare-and-set updates (`where status = <expected>`) and a contract version on the grant function so a stale worker or an out-of-order event cannot move the state backwards.
- An old declined payment must not push a paid subscription back to past-due: record it, then sync the **current remote** state.
- Make activation idempotent (already active with a period = no-op) and robust to `subscription.updated` arriving before your own activation.

## 7. Reconciliation
Run a periodic job that re-reads from the provider: subscriptions marked active but overdue, orphan payments, failed webhook deliveries, changes charged but not applied, next charge date and amount drift. Alert on the **age** of unresolved operations. Also expose a status page that reads the real payment, not just the `?success` URL.

## 8. Tests that must exist
first purchase · renewal with an intermediate (pending) state · decline followed by approval · webhook arriving before the checkout response · lost response · plan change and cancellation at the same time · refunds/chargebacks · every supported country and currency · duplicate webhook delivery · invalid/absent signature. Write them as unit tests with mocks **and** as a run in the provider sandbox without real charges; attach the evidence to the PR.

## Review checklist
Spec approved · sandbox run attached · migration reviewed (see the `safe-migration` skill) · "how to revert" explains what happens to charges already made.
