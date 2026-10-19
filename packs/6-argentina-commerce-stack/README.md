# Pack 6 — Argentina Commerce Stack

Everything you need to **charge, invoice and ship** from an Argentine SaaS or ecommerce.

| Skill | What it covers |
|---|---|
| `/arca-invoicing` | Electronic invoices with ARCA (ex-AFIP): WSAA login, WSFEv1, invoice types A/B/C, CAE, QR, credit notes. |
| `/rebill-subscriptions` | Recurring billing with Rebill: checkout, renewals, webhooks, ledger, past-due, reconciliation. |
| `/mercadopago-payments` | One-time payments with Mercado Pago: preferences, signed webhooks, verification, refunds. |
| `/correo-argentino-shipping` | Shipping with Correo Argentino (MiCorreo): quotes, branches, shipments. |

## How they fit together

```
Buyer ─► Checkout ─► Mercado Pago (one-off) / Rebill (subscriptions)
                          │ webhook (signed) → re-fetch from the API
                          ▼
                   Orders / ledger (exactly once)
                    ├─► entitlement or stock
                    ├─► invoice queue ─► ARCA (CAE, QR, PDF)
                    └─► shipment queue ─► Correo Argentino
Refund / chargeback ─► reversal ─► credit note (ARCA)
```

Shared principles in all four: the provider's response is data to verify, not an instruction · money in integer cents · one idempotency key per external side effect · "unknown outcome" is a state of its own · a reconciliation job closes the gaps webhooks leave.

Pair with pack 1 (spec first), pack 4 (migrations for ledger tables) and pack 3 (audit the webhooks).

> Disclaimer: these skills are engineering guidance, not legal or tax advice. Confirm fiscal rules with your accountant and API details with each provider's current documentation.
