import JobtrackKit
import SwiftUI

/// The skeleton's one screen: the board's fixed columns, empty until the
/// design (docs/design.md) defines the API models.
struct BoardView: View {
    var body: some View {
        NavigationStack {
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(Column.allCases) { column in
                        VStack(alignment: .leading) {
                            Text(column.title).font(.headline)
                            Spacer()
                        }
                        .frame(width: 220, height: 400, alignment: .topLeading)
                        .padding()
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding()
            }
            .navigationTitle("jobtrack")
        }
    }
}

#Preview {
    BoardView()
}
