import Foundation

enum ItemTrackingMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case time
    case usage

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .time:
            "Tempo"

        case .usage:
            "Usos"
        }
    }

    var symbol: String {
        switch self {
        case .time:
            "calendar"

        case .usage:
            "checkmark.circle.fill"
        }
    }

    var explanation: String {
        switch self {
        case .time:
            "Acompanha quanto o item custou por dia, semana, mês ou ano."

        case .usage:
            "Acompanha o custo médio de cada uso registrado."
        }
    }

    var unitSuffix: String {
        switch self {
        case .time:
            "por dia"

        case .usage:
            "por uso"
        }
    }
}
