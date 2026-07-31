import Foundation

enum ItemStatus: String, CaseIterable, Identifiable, Codable, Sendable {
    case active
    case sold
    case donated
    case discarded

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .active:
            "Em uso"

        case .sold:
            "Vendido"

        case .donated:
            "Doado"

        case .discarded:
            "Descartado"
        }
    }

    var symbol: String {
        switch self {
        case .active:
            "checkmark.circle.fill"

        case .sold:
            "banknote.fill"

        case .donated:
            "gift.fill"

        case .discarded:
            "trash.fill"
        }
    }

    var isActive: Bool {
        self == .active
    }
}
