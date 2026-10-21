import SwiftUI

@main
struct JobtrackApp: App {
    @State private var signIn = SignInModel()

    var body: some Scene {
        WindowGroup {
            if signIn.signedIn || !signIn.isConfigured {
                // Unconfigured builds (and CI) keep the fixture-backed board
                // until the live API exists (milestone 3).
                BoardView(signIn: signIn)
            } else {
                SignInView(model: signIn)
            }
        }
    }
}

struct SignInView: View {
    let model: SignInModel

    var body: some View {
        VStack(spacing: 16) {
            Text("jobtrack").font(.largeTitle)
            Button("Sign in") { Task { await model.signIn() } }
                .buttonStyle(.borderedProminent)
            if let message = model.message {
                Text(message).font(.footnote).foregroundStyle(.secondary)
            }
        }
        .padding()
    }
}
