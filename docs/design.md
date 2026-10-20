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

- Column ↔ jobtrack state mapping is **server-owned** (decision 2): each
  card carries its column and its allowed moves; a client-side table is
  display fallback only. The concrete mapping is jobtrack's to state
  **[pending]**.
- **Drag** (iPhone: long-press drag between columns, plus a "Move to…" action
  sheet as the accessible alternative). Drop targets not in the card's allowed
  transitions are dimmed and reject the drop.
- **Gated moves** (submit application, offer decision) show a confirmation
  sheet naming the card and the consequence before the request is filed.
- iPhone layout (one column at a time with a picker, or all seven scrolling
  horizontally) is **open**, decision 3.

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
id plus alert text from fixed generic wording or counts only ("jobtrack: something needs you", "3 items need you"). On receipt
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

Answered by the owner session on PR #1 unless marked open.

1. **Order of work: decided.** Milestones 1 to 2 proceed now. Milestone 3
   onward waits for jobtrack's `docs/design-mobile-and-discovery.md`.
2. **Column mapping source: decided.** The server owns the state→column
   mapping (columns map to jobtrack's real states). The app renders the
   column each card carries and the moves the server says are allowed; any
   client-side table is display fallback only.
3. **Board layout on iPhone: open.** One column at a time with a picker
   (my recommendation; cards stay readable) versus the skeleton's horizontal
   scroll of all seven columns. The owner is deciding; no board layout work
   past the skeleton until he does.
4. **Idempotency key: decided as an assumption, still [pending].** Assume a
   client-generated request id. It will be filed as an agent-request to
   jobtrack once requests are enabled (not yet), and stays [pending] until
   jobtrack's design confirms it.
5. **Push text: decided.** Follow mailroom-ios's accepted pattern: an opaque
   push id, alert text from fixed generic wording or counts only, details
   fetched over the tailnet. A Notification Service Extension showing
   company/role on the lock screen is a later option, not v1.
6. **App Group and bundle ids: decided.** App Group and keychain access
   group `group.com.scshafe.jobtrack`; bundle ids `com.scshafe.jobtrack`
   (app) and `com.scshafe.jobtrack.share` (share extension).
