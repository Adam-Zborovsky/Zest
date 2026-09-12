# Local recipe gateway review — 2026-09-12

Scope: approved development-only backend prerequisite to M5; Node/TypeScript/Fastify, backend-only provider key, existing five recipe operations, configurable Flutter gateway address. No Docker, Nginx, deployment, backend database, accounts, graph or new discovery feeds.

Luna authored the initial 16 backend tests. A separate Luna instance reviewed source and tests independently. Main added seven hardening tests and performed Flutter, backend and cross-language verification. The reviewer independently re-ran the final 23 backend tests, typecheck and build.

## Findings and resolution

| Finding | Resolution |
| --- | --- |
| Initial reviewer noted missing explicit close-abort coverage. | Main added close, late/noncooperative fetch and body-stream timeout tests. |
| Main's new denied-origin preflight regression failed: expected 403, received 204. | Register the root origin guard before the CORS plugin. Allowed OPTIONS remains 204; denied OPTIONS is now 403. Reviewer checked the fix and regression. |
| Reviewer noted list records validate only the consumed ingredient-name field, unlike full recipes. | Intentional: names-only contract. Additional source fields are preserved and never used as typed properties or availability claims. |
| Final reviewer found a missing review-record link and stale direct-provider manual-run instructions. | Added this record; corrected DISCOVERY, README, kickoff instructions and local setup. |

Final code verdict: approve; no unresolved code/security blockers. Source UI behavior, accessibility components and golden baselines were not changed. Backend validation, URL allowlists, secret redaction, origin handling, cache/deadline bounds, request sharing and monotonic cooldown were inspected.

Verified by main: backend 23 tests, strict typecheck/build, synthetic gateway demo; Flutter analysis, all 126 tests, web build, original M2 synthetic demo and five-operation Flutter/Fastify contract demo. The existing Cupertino font warning persists in the web build; it was not suppressed.

Not verified: actual paid-key behavior, live provider/full-catalog responses, a real browser's local CORS exchange, physical devices, screen readers or production security. No listening server/watcher, private key or provider-content asset was used. CORS plus loopback binding is a development boundary, not authentication or a public abuse-control system. See [GATEWAY.md](../GATEWAY.md).
