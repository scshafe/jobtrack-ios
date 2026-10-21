import Foundation

/// A column of the board (docs/brief.md): the fixed lifecycle, left to
/// right. Which of jobtrack's states each column holds, and which moves
/// between them jobtrack allows, is docs/design.md's to define.
public enum Column: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case found
    case pursuing
    case preparing
    case applied
    case interviewing
    case offer
    case closed

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .found: "Found"
        case .pursuing: "Pursuing"
        case .preparing: "Preparing"
        case .applied: "Applied"
        case .interviewing: "Interviewing"
        case .offer: "Offer"
        case .closed: "Closed"
        }
    }
}
