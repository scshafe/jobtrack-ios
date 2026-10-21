import JobtrackKit
import SwiftUI

/// The board. iPhone: a stage picker with counts and one full-width column.
/// iPad: all columns side by side (docs/design.md, decision 3).
struct BoardView: View {
    @State private var model = BoardModel(api: FakeAPIClient())
    @State private var selected = Column.found
    @State private var confirming: (card: BoardCard, target: Column)?
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        NavigationStack {
            Group {
                if sizeClass == .regular {
                    ScrollView(.horizontal) {
                        HStack(alignment: .top, spacing: 12) {
                            ForEach(Column.allCases) { column in
                                VStack(alignment: .leading) {
                                    Text("\(column.title) \(model.board.count(in: column))")
                                        .font(.headline)
                                    columnList(column)
                                }
                                .frame(width: 280)
                            }
                        }
                        .padding()
                    }
                } else {
                    VStack(spacing: 0) {
                        picker
                        columnList(selected)
                    }
                }
            }
            .navigationTitle("jobtrack")
            .task { await model.load() }
            .refreshable { await model.load() }
            .confirmationDialog(
                "Move to \(confirming?.target.title ?? "")?",
                isPresented: Binding(
                    get: { confirming != nil },
                    set: { if !$0 { confirming = nil } }),
                titleVisibility: .visible
            ) {
                if let pending = confirming {
                    Button("Move \(pending.card.title) to \(pending.target.title)") {
                        Task { await model.move(pending.card, to: pending.target) }
                    }
                }
            } message: {
                if let pending = confirming {
                    Text("\(pending.card.company): \(pending.card.title). jobtrack will check this before applying it.")
                }
            }
        }
    }

    private var picker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(Column.allCases) { column in
                    Button {
                        selected = column
                    } label: {
                        Text("\(column.title) \(model.board.count(in: column))")
                    }
                    .buttonStyle(.bordered)
                    .tint(column == selected ? .accentColor : .gray)
                }
            }
            .padding()
        }
    }

    private func columnList(_ column: Column) -> some View {
        List(model.board.cards(in: column)) { card in
            CardRow(card: card)
                .contextMenu {
                    if !card.allowedMoves.isEmpty {
                        Menu("Move to…") {
                            ForEach(card.allowedMoves) { target in
                                Button(target.title) {
                                    if card.isGated(target) {
                                        confirming = (card, target)
                                    } else {
                                        Task { await model.move(card, to: target) }
                                    }
                                }
                            }
                        }
                    }
                }
        }
        .listStyle(.plain)
        .overlay {
            if model.board.count(in: column) == 0 {
                Text("Nothing here").foregroundStyle(.secondary)
            }
        }
    }
}

private struct CardRow: View {
    let card: BoardCard

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(card.title).font(.body)
            Text(card.company).font(.subheadline).foregroundStyle(.secondary)
            if let request = card.request {
                switch request.state {
                case .queued: Label("Not sent yet", systemImage: "clock")
                case .pending: Label("Pending", systemImage: "hourglass")
                case .refused:
                    Label(request.reason ?? "Refused", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                case .applied: EmptyView()
                }
            }
        }
        .font(.caption)
    }
}

#Preview {
    BoardView()
}
