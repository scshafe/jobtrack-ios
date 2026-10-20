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

<!-- scshafe-dev:begin landing -->
## Verify and landing

Managed by scshafe-dev: `dev adopt` and `dev update` refresh this section from `dev.toml`; change `dev.toml`, not these lines.

Before finishing, both of these must pass:

```sh
./scripts/verify
dev check .
```

How a change lands:

1. Work on a branch and open a PR.
2. Run the two commands above. If the repository is private, GitHub Actions does not run for it: verify locally and say in the PR what you ran. If it is public, wait for CI to be green.
3. Merge the PR with a merge commit, one change at a time: `gh pr merge <N> --merge --subject "Merge #<N>: <title>"`. Never squash or rebase (both are off on the repository), and pass `--subject`: `gh pr merge` does not make the `Merge #N: <title>` subject by itself.
<!-- scshafe-dev:end landing -->
