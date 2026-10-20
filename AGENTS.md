# jobtrack-ios agent notes

- The iPhone app for jobtrack. `docs/brief.md` is fixed. Your first PR is
  `docs/design.md`, with an "Owner decisions" section; nothing is built past
  the skeleton until the owner accepts it.
- The app never writes jobtrack's store: it files requests to jobtrack's API
  and shows them pending until jobtrack applies them. The server side
  (request queue, board read model, door) is jobtrack's, designed by its
  agent in jobtrack's `docs/design-mobile-and-discovery.md`. Never edit
  jobtrack: ask its agent with an agent request (`request`), and follow its
  design.
- SwiftUI, iOS 26. `project.yml` (XcodeGen) generates the Xcode project; it
  is not committed. App logic goes in `JobtrackKit` (a Swift package with
  `swift test` tests); keep the app target thin.
- There is no Swift on the PC: `./scripts/verify` is Swift-free (scripts,
  the XcodeGen spec, the layout). CI's macOS job runs `swift test` and the
  simulator build; the owner runs the app on the Air. Say in each PR what
  needs his Mac check.
- Public repository: CI runs; wait for it to be green. Never commit personal
  data, job or store contents, screenshots with real data, tokens, or the
  tailnet name (write `<tailnet>`). Fixtures and test data are synthetic.
- The Pocket ID client, the door, APNs keys and tailnet changes are the owner
  session's work: put what you need in the PR and ask.
