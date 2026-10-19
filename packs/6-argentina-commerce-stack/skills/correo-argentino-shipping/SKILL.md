---
name: correo-argentino-shipping
description: Integrates Correo Argentino shipping (MiCorreo API) into an ecommerce: authentication, quoting, branch lookup, creating shipments and handling errors. Covers packaging math, caching quotes, and keeping orders and shipments consistent. Use when adding shipping costs at checkout or creating Correo Argentino shipments from orders.
argument-hint: "[what you need to build or fix]"
---

# Correo Argentino shipping (MiCorreo API)

Shipping touches checkout (a price), fulfillment (a shipment) and customer support (a status). Keep all three tied to your own order id.

> This skill is based on the MiCorreo REST API as exposed by community client libraries and public information, because Correo Argentino shares its documentation and credentials with registered customers. **Confirm every endpoint, field and limit against the documentation Correo gives you with your credentials**, and test in their TEST environment first. Another product, PAQ.AR 2.0, exists for agreement-based business accounts and has a different API.

```
- [ ] 1. Credentials per environment
- [ ] 2. Auth: Basic → JWT
- [ ] 3. Packaging → quote
- [ ] 4. Checkout shows quoted options
- [ ] 5. Create the shipment on paid order
- [ ] 6. Errors and retries
- [ ] 7. Tests
```

## 1. Credentials and environments
- Request API access from Correo Argentino. **TEST and PROD have different credentials and different base URLs** (`apitest.correoargentino.com.ar/micorreo/v1` vs `api.correoargentino.com.ar/micorreo/v1`) and a `customerId` registered in each. Config via env vars: base URL, user token, password token, customer id.
- Never log credentials, the JWT or recipient personal data.

## 2. Auth
`POST /token` with HTTP Basic (user token + password token) returns a JWT with an expiry. Cache it until shortly before it expires and refresh on 401. Switching environment must reset the cached JWT. `POST /users/validate` returns the `customerId` once; store it.

## 3. Packaging → quote
- Each product needs weight (grams, integer; the quote endpoint accepts roughly 1–25,000 g), and length/width/height in cm (quote limit ~150 cm per side; the shipment endpoint's limit differs — check both).
- A cart with several items becomes **one virtual package**: sum of weights, the largest length, the largest width, the sum of heights (or use your own packing rules, but make them explicit and tested).
- `POST /rates` with origin and destination postal codes, optionally `deliveredType`: `D` (home delivery) or `S` (branch pickup); omit to get both. Each rate has product type, name, price and min/max delivery days, and a `validTo`.
- **Cache quotes** by (origin, destination, package, type) until `validTo`; never call the API on every keystroke.

## 4. At checkout
- Validate the postal code format, then show only quoted options. For branch pickup, load branches with `GET /agencies?provinceCode=<letter>` and let the buyer pick one.
- **Compute and store the shipping cost on the server** when the order is created. The client never sends a price.
- If the quote fails, offer a clear fallback (flat rate or "we'll contact you") instead of blocking the sale.

## 5. Creating the shipment
Create it **after payment is confirmed** (see `mercadopago-payments` / `rebill-subscriptions`), from a queue job:
- `POST /shipping/import` with `customerId`, `extOrderId` (**must be unique** — use your order id; a duplicate is rejected, which makes retries safe), sender (optional, defaults to the account profile), recipient (name and email required), shipping block (`deliveryType`, `agency` for `S`, `address` for `D` with street, number, city, province code, postal code), weight, declared value and dimensions.
- Validate all fields on your side before sending, and persist the response and the shipment reference on the order.
- Treat timeouts as **unknown**: look up before re-creating, or rely on the unique `extOrderId`.

## 6. Errors
401 → wrong or expired credentials for that environment (refresh the JWT once, then alert). 402 → a business rule failed (duplicate `extOrderId`, missing sender data): read the message, do not retry. 429 → back off exponentially. Surface a human-readable message to staff, never raw payloads to customers.

## 7. Tests
Packaging math (several items, single item, over-limit) · quote cache expiry · `D` vs `S` validation · duplicate `extOrderId` retry · expired JWT refresh · shipment creation only once per paid order · order paid but shipment failed → visible in an admin queue with a retry button.

## Out of scope here
Label printing and tracking: the community API surface does not cover them, so check what your Correo documentation provides (or a tracking aggregator) before promising them to customers.
