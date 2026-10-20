# jobtrack-ios design

Status: draft for the owner. Nothing is built past the skeleton until the
owner accepts it. `docs/brief.md` is fixed and is not restated here.

**The API contract is pending.** jobtrack's agent is designing the request
queue, board read model and door in jobtrack's
`docs/design-mobile-and-discovery.md`, which has not landed. This document
designs the app against the request/board model in the brief. Everything
marked **[pending]** is an assumption to replace with that design; the app is
structured so that replacing it touches one layer (`APIClient` and its wire
models), not the UI.

## Principles

1. **The app never writes the store.** It files requests and displays
   jobtrack's answer. No optimistic move is ever shown as done.
2. **The server is the authority on lifecycle.** The app does not hard-code
   which transitions are legal beyond a fallback; it renders what the board
   read model says is allowed **[pending]**.
3. **No job content leaves the device except over the tailnet** to the door,
   and none is ever committed here (public repo; fixtures are synthetic).

## Architecture

- `JobtrackKit` (Swift package, `swift test`): wire models, column mapping,
  request model and state machine, API client protocol, auth/token logic,
  push-id resolution, local cache. No UIKit/SwiftUI imports.
- `Jobtrack` (app target, thin): SwiftUI views, view models only as
  `@Observable` adapters over Kit types, app delegate for APNs.
- `JobtrackShare` (share extension target): captures a URL and files a
  capture request through `JobtrackKit`. Shares the Keychain with the app
  through a keychain access group so it can use the signed-in session.
- Networking: `URLSession`, async/await. `APIClient` is a protocol; tests use
  a fake with synthetic fixtures.

## Board

Columns are the fixed set already in `Column.swift`. Each card has a
`BoardCard` from the board read model: id, title, company, jobtrack state,
column, allowed target columns/transitions, gate flags, and any in-flight or
refused request **[pending: exact shape]**.

- Column ↔ jobtrack state mapping is **server-provided** (each card carries
  its column), with a client-side table only as a fallback for display. The
  mapping of jobtrack's real states to the seven columns is jobtrack's to
  state **[pending]**; see decision 2.
- **Drag** (iPhone: long-press drag between columns, plus a "Move to…" action
  sheet as the accessible alternative). Drop targets not in the card's allowed
  transitions are dimmed and reject the drop.
- **Gated moves** (submit application, offer decision) show a confirmation
  sheet naming the card and the consequence before the request is filed.
- The board shows one column at a time at iPhone width (paged, column picker
  on top); the skeleton's horizontal scroll is kept for landscape-free
  iPhone only if the owner prefers it (decision 3).

## Requests and pending state

A request is `{client_request_id, kind, card_id, payload}`; kinds in v1:
`move`, `pursue`, `dismiss`, `approve`, `capture`. `client_request_id` is a
UUID generated on the device and sent as an idempotency key, so a retry after
a lost response cannot apply twice **[pending: server must honour it]**.

Lifecycle seen by the app: `queued` (stored locally, not yet accepted) →
`pending` (accepted by the API, waiting for the worker) → `applied` | `refused(reason)`.

- A card with a request in `queued`/`pending` shows a pending badge and stays
  in its *current* column; it moves only when the board read model says so.
- `refused` shows jobtrack's reason on the card and in a detail sheet, with
  Retry (new request) and Dismiss. Refusals are never silently dropped.
- Requests are persisted locally (small file store) until accepted, so a
  capture from the share sheet survives being offline or the app being
  killed. Local queue entries show as "not sent yet", distinct from pending.
- The board is refreshed on foreground, on pull-to-refresh, and when a push
  arrives. Polling while a request is pending, every few seconds, backing off
  **[pending: or a status endpoint/long-poll]**.

## Needs me

A list view fed by the same read model **[pending: separate endpoint or a
filter]**: pursue/dismiss decisions, approvals (gates), due follow-ups. Each
row acts in place (Pursue, Dismiss, Approve) by filing the corresponding
request; gated actions confirm first. The tab badge is the queue count.

## Push (APNs)

As mailroom-ios (`docs/design-inbox-zero.md`, "Push (APNs)"): the server
sends through Apple, the payload carries **no job content**, only an opaque
id plus a generic alert text ("jobtrack: something needs you"). On receipt
(visible push, tap, or foreground), the app resolves the id over the tailnet
to learn what changed and refreshes. Device-token registration is a call to
the API **[pending]**. APNs keys and server sending are the owner session's.

## Share-sheet extension

Accepts URLs (and text containing a URL) from Safari, LinkedIn or any app.
It files a `capture` request carrying the URL only, shows "Sent" or "Saved,
will send when signed in/online", and never fetches the posting itself.
Posting parsing is jobtrack's. Duplicate captures are jobtrack's to detect.

## Sign-in

Native OIDC authorization code + PKCE, public client, via
`ASWebAuthenticationSession`, against Pocket ID (client id and redirect URI
to be provisioned by the owner session; modeled on `homemesh-capture`).
`Authorization: Bearer <id token>` on every API call (the door accepts the ID
token). Tokens in the Keychain (shared access group for the extension),
refreshed with the refresh token; on refresh failure the app returns to
sign-in and keeps the local request queue. Issuer, client id, and base URL
are configuration, not committed values: build settings / a git-ignored
local config, with `<tailnet>` placeholders in anything committed.

## Offline and errors

The last board is cached for read-only viewing (marked stale with its age).
Filing a request requires the network except `capture`, which queues. A 401
triggers one silent refresh then sign-in; a 4xx on a request marks it
`refused` with the server's message; 5xx/network leaves it `queued`.

## Testing

- `swift test`: column mapping, request state machine and idempotency,
  decoding of synthetic fixtures, token refresh logic with a fake clock,
  queue persistence.
- `./scripts/verify` stays Swift-free (layout, XcodeGen spec).
- CI's macOS job runs `swift test` and the simulator build. Each PR states
  what needs a check on the Air (drag, share sheet, sign-in and push can only
  be checked on a device).

## Milestones (each its own PR, after acceptance)

1. `JobtrackKit` models, API client protocol, fakes and fixtures; board view
   on fixtures.
2. Sign-in (needs the Pocket ID client).
3. Live board and requests with pending/refused states (needs jobtrack's API).
4. Needs me.
5. Share extension.
6. Push (needs APNs key and server side).

## Owner decisions

1. **Wait for jobtrack's design before milestone 3?** Milestones 1 to 2 can
   proceed on this document; 3 onward depend on the API contract. Confirm this
   order, or hold everything until jobtrack's design lands.
2. **Column mapping source.** Server-provided column per card (my
   recommendation: one source of truth) versus the app owning the
   state→column table. Needs the same answer from jobtrack's agent.
3. **Board layout on iPhone.** One column at a time with a picker
   (recommended; cards stay readable) versus the skeleton's horizontal scroll
   of all seven columns.
4. **Idempotency key.** I assume the API accepts a client-generated request
   id and returns the same request on repeat. If the owner prefers otherwise
   (e.g. server-assigned ids only), offline capture queueing needs a
   different dedupe.
5. **Push alert text.** Generic fixed text ("something needs you") with no
   job content, or silent pushes only (content-available) with a local
   notification built after resolving the id. The first leaks nothing
   through Apple; the second is richer but unreliable on iOS.
6. **Extension and keychain group.** The share extension needs an App Group /
   keychain access group in the Apple developer account, with the
   `DEVELOPMENT_TEAM` the owner sets locally. Confirm the group id
   (suggested: `group.com.scshafe.jobtrack`).
