import Foundation

enum ItemCostPeriod: String, CaseIterable, Identifiable, Codable, Sendable {
    case day
    case week
    case month
    case year

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .day:
            "Dia"

        case .week:
            "Semana"

        case .month:
            "Mês"

        case .year:
            "Ano"
        }
    }

    var shortTitle: String {
        switch self {
        case .day:
            "dia"

        case .week:
            "sem."

        case .month:
            "mês"

        case .year:
            "ano"
        }
    }

    var approximateDayCount: Int {
        switch self {
        case .day:
            1

        case .week:
            7

        case .month:
            30

        case .year:
            365
        }
    }
}
