# jobtrack-ios

The iPhone app for [jobtrack](https://github.com/scshafe/jobtrack), a
job-search system of record: a kanban board of applications in fixed
lifecycle columns, a "needs me" queue, push alerts, and a share-sheet
extension that captures a posting URL. SwiftUI, iOS 26, iPhone.

The app never writes jobtrack's store. jobtrack's CLI stays its only writer:
the app **files requests** (move a card, pursue or dismiss, approve a gate,
capture a posting) to a jobtrack API, jobtrack's worker validates each one and
runs the matching CLI operation, and a card shows "pending" until it is
applied.

- Brief: [docs/brief.md](docs/brief.md). The design (`docs/design.md`) is the
  first PR; nothing is built past this skeleton until it is accepted.
- The server side (request queue, board read model, door) is jobtrack's,
  designed in its `docs/design-mobile-and-discovery.md`.
- Released under the [MIT licence](LICENSE). Test data is synthetic.

## Build (on a Mac)

The Xcode project is generated from `project.yml` by
[XcodeGen](https://github.com/yonaskolb/XcodeGen) (2.46.0, pinned in
`.github/workflows/ci.yml`); the `.xcodeproj` is not committed.

```sh
swift test --package-path JobtrackKit       # the app's logic, unit tested
cp project.local.yml.example project.local.yml   # once: your signing team
xcodegen generate --spec project.local.yml
open Jobtrack.xcodeproj
```

## Verify (any machine)

```sh
./scripts/verify      # Swift-free checks: scripts, project.yml, layout
```

It runs on Linux: shell syntax, then the repository's Python tests, which
check that the XcodeGen spec parses and points at files that exist, and that
generated or private files are not committed. CI runs it on every push,
plus a macOS job that runs `swift test` and builds the app for a simulator.
