---
name: arca-invoicing
description: Builds or changes electronic invoicing with ARCA (ex-AFIP) for Argentina, using the WSAA login and WSFEv1 web services: certificates, tokens, invoice type selection, CAE requests, numbering, retries, credit notes and the fiscal QR. Use when emitting invoices (Factura A/B/C), connecting a payment to an invoice, or debugging ARCA errors. Money-adjacent: treat as high risk.
argument-hint: "[what you need to invoice or fix]"
---

# ARCA electronic invoicing (WSAA + WSFEv1)

Invoices are legal documents: an invoice emitted twice or with the wrong total cannot be "undone" with a deploy (only with a credit note). Work in the **homologation** (sandbox) environment until the whole flow passes, then switch environment by configuration only.

> Facts below come from ARCA's public web-service manuals and from production experience. Endpoints, error codes and required fields change: before shipping, confirm against ARCA's current manuals for WSAA and WSFEv1.

```
- [ ] 1. Emitter setup (CUIT, tax condition, certificate, point of sale)
- [ ] 2. WSAA login with ticket cache
- [ ] 3. Receptor → invoice type
- [ ] 4. Amounts in integer cents
- [ ] 5. Numbering + CAE request
- [ ] 6. Classify the result (A / R / P / ambiguous)
- [ ] 7. Persist, QR, PDF
- [ ] 8. Credit notes and reversals
- [ ] 9. Tests against homologation
```

## 1. Emitter setup
- Config (env vars, never in the repo): `ARCA_ENV` (`homologacion` | `produccion`), `ARCA_CUIT`, `ARCA_CERT`, `ARCA_PRIVATE_KEY`, `ARCA_PUNTO_VENTA`, emitter tax condition. Accept PEM pasted directly **or base64** (multi-line env vars are fragile).
- Certificate: generate a private key and CSR with `openssl`, upload the CSR in ARCA's certificate tool (separate tool for homologation and for production), then authorize that certificate for the `wsfe` service. The point of sale must be of the "web services" type.
- URLs: homologation `wsaahomo.afip.gov.ar` / `wswhomo.afip.gov.ar/wsfev1`, production `wsaa.afip.gov.ar` / `servicios1.afip.gov.ar/wsfev1`. Keep them in one config module keyed by environment.
- `isConfigured()` should gate **emission**, not queueing: without config, still create the pending invoice record (it documents the charge) and emit once configuration appears.

## 2. WSAA login
- Build the TRA XML, sign it as CMS with the certificate and key, call `LoginCms`, receive `token` + `sign`.
- **Cache the ticket until it expires** (it lasts about 12 hours). Asking for a new ticket while one is valid fails with an "already authenticated" error — store it (DB or shared cache), not in process memory only, and serialize refreshes.
- Clock skew breaks the TRA validity window: keep servers on NTP.
- Never log `token`, `sign`, the private key or the certificate.

## 3. Receptor → invoice type
The customer declares their VAT condition; they do not pick the invoice type.
- **Emitter is Monotributo** → always Factura **C** (type 11), no VAT breakdown.
- **Emitter is Responsable Inscripto** → **A** (1) for RI and Monotributo receptors, **B** (6) for exempt and final consumers, with VAT breakdown.
- Send the receptor's VAT condition (`CondicionIVAReceptorId`, mandatory since the 2025 regulation) and a document type: CUIT 80, DNI 96, unidentified 99.
- Validate CUITs with the mod-11 checksum and persist digits only. If a receptor that requires a CUIT has no valid one, **degrade to final consumer** instead of blocking the invoice.

## 4. Amounts: integer cents
- Work in integer cents end to end; floats break the "adds up to the cent" rule that WSFE enforces.
- `ImpTotal` is **always what the payment processor actually charged**; net and VAT are derived from it, never the reverse.
- VAT-included price → `neto = round(total / 1.21)`, `iva = total − neto`, so `neto + iva === total` always.
- Format with a dot and two decimals in the XML.

## 5. Numbering and the CAE request
1. `FECompUltimoAutorizado(ptoVta, cbteTipo)` → next number is last + 1.
2. `FECAESolicitar` with concept (products 1, services 2, both 3). Concepts 2 and 3 **require** service period dates and payment due date.
3. Serialize emission **per (point of sale, type)**: two concurrent requests will fight for the same number.

## 6. Classify the result (the part that matters most)
- `A` approved → store CAE and CAE expiry.
- `R` rejected → store the observations/errors, do not retry blindly; fix the data.
- `P` partial/observed → treat as a finding for a human.
- **Network error or timeout = AMBIGUOUS.** The invoice may exist. Before any retry, call `FECompConsultar` for that number; only re-request if it does not exist (error 602). Never emit twice.
- One **invoice-intent row per payment** with a unique key makes emission idempotent: the queue can be retried safely.

## 7. Persist, QR, PDF
- Save: type, point of sale, number, CAE, expiry, issue date, receptor data, amounts, raw response.
- Fiscal QR: `https://www.afip.gob.ar/fe/qr/?p=<base64(JSON)>` with the JSON fields defined by the QR regulation (version, date, CUIT, point of sale, type, number, total, currency, rate, document type/number, `tipoCodAut: "E"`, CAE).
- Production may negotiate legacy TLS; if the handshake fails, relax the TLS security level **only for the ARCA client**, not globally.

## 8. Credit notes and reversals
Refunds and chargebacks require a credit note (types 3, 8, 13 for A, B, C) that references the original voucher. Do not auto-emit on every refund event: record the reversal and let the fiscal decision be explicit.

## 9. Tests
- Unit: CUIT checksum, receptor → type matrix, cent math (`neto + iva === total` for many totals), QR payload.
- Integration against homologation: one invoice per type you support, a rejected one (bad data) and a recovered timeout.
- Foreign customers and export invoices use a different service (WSFEX) and are out of scope here — park them in `on_hold` rather than forcing them through WSFE.
