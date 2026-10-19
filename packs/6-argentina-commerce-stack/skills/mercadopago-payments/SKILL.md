---
name: mercadopago-payments
description: Integrates Mercado Pago payments (Checkout Pro preferences, webhooks, payment verification, refunds and sandbox testing) in an ecommerce or SaaS. Covers signature validation, idempotency, order reconciliation and the mistakes that cause lost or duplicated orders. Use when adding Mercado Pago checkout or its notifications, or debugging a payment that "was approved but the order did not update". Real money: treat as high risk.
argument-hint: "[what you need to build or fix]"
---

# Mercado Pago payments

The rule that prevents most bugs: **the browser redirect is a hint, the webhook is a signal, and the Payments API is the truth.** An order is paid only when you have re-read the payment from the API and it says `approved` for the amount you expect.

> Verify details against Mercado Pago's current developer docs for your country (mercadopago.com.ar/developers) before shipping. This skill is the integration pattern and the failure modes.

```
- [ ] 1. Credentials and environments
- [ ] 2. Create the order first, then the preference
- [ ] 3. Redirect and back_urls
- [ ] 4. Webhook: validate, re-fetch, apply once
- [ ] 5. Statuses and refunds
- [ ] 6. Sandbox test matrix
```

## 1. Credentials
- Two credential sets: **test** and **production**; keep them in separate env vars and make the active one obvious in logs (never the secret itself).
- The access token lives only on the server. The public key is the only one the browser may see.
- Create test sellers and test buyers in the developer dashboard; do not pay with real cards in sandbox.

## 2. Order first, preference second
- Create **your own order row** (status `pending`, amount computed on the server, items snapshot) before calling Mercado Pago.
- Create the Checkout Pro **preference** with: items (price from your order, not from the client), `external_reference` = your order id, `notification_url` (your webhook, public HTTPS), `back_urls` (success / pending / failure), `auto_return: "approved"`, and an expiry if the stock is reserved.
- Store the preference id on the order. Send an `X-Idempotency-Key` on creating calls so a retry does not create a second charge/preference.

## 3. The redirect
The buyer returns to `back_urls` with query parameters (payment id, status, `external_reference`). **Do not mark the order paid from these.** Show a "processing your payment" state and poll your own order status, which the webhook flow updates.

## 4. The webhook
1. Respond **fast** (200/201) and do the work asynchronously; failures or slow replies make Mercado Pago retry.
2. **Validate the signature.** Read the `x-signature` header (`ts=…,v1=…`) and `x-request-id`. Build the manifest `id:<data.id lowercased>;request-id:<x-request-id>;ts:<ts>;` (omit any part not present), compute **HMAC-SHA256 hex** with the webhook secret from the dashboard as key, compare with `v1` in constant time. Optionally reject a `ts` too far from now.
3. **Re-fetch** the payment (`GET /v1/payments/{id}`) with your access token. Ignore whatever amount or status the notification body suggests.
4. Find the order by `external_reference`. Check **amount, currency and status** match your order; mismatch → flag for review, do not fulfill.
5. Apply **exactly once**: dedupe by payment id (unique constraint), update the order in a transaction, then trigger fulfillment (access, stock, invoice, shipment). Duplicate and out-of-order notifications are normal.
6. Unknown topics and payment ids you cannot resolve: return 200 and log; do not make the sender retry forever.

## 5. Statuses and refunds
`approved` → fulfill. `pending` / `in_process` → keep waiting (cash and bank-transfer methods can take days). `rejected` / `cancelled` → release stock, allow retry with a new preference. `refunded` / `charged_back` → reverse access, record the reversal, and trigger a credit note if you invoiced (see `arca-invoicing`). Partial refunds exist: track the refunded amount, not just a flag.
Orders stuck in `pending` need a reconciliation job that re-reads the payment by `external_reference` search.

## 6. Sandbox test matrix
approved · rejected (use the documented test cards/holder names for each outcome) · pending · duplicate webhook · webhook before redirect · redirect without webhook · wrong amount · refund · expired preference.

## Never
Trust the client's price · fulfill from the redirect or the raw webhook body · log tokens or full payloads with buyer data · put the access token in the browser · process the same payment id twice.
