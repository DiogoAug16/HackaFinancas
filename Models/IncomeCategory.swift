import Foundation

enum IncomeCategory: String, CaseIterable, Identifiable, Codable, Sendable {
    case salary
    case freelance
    case extra
    case benefits
    case sales
    case investments
    case investment
    case gifts
    case refunds
    case other

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .salary:
            "Salário"

        case .freelance:
            "Freelance"

        case .extra:
            "Renda Extra"

        case .benefits:
            "Benefícios"

        case .sales:
            "Vendas"

        case .investments, .investment:
            "Investimentos"

        case .gifts:
            "Presentes"

        case .refunds:
            "Reembolsos"

        case .other:
            "Outros"
        }
    }

    var symbol: String {
        switch self {
        case .salary:
            "banknote.fill"

        case .freelance, .extra:
            "laptopcomputer"

        case .benefits:
            "giftcard.fill"

        case .sales:
            "tag.fill"

        case .investments, .investment:
            "chart.line.uptrend.xyaxis"

        case .gifts:
            "gift.fill"

        case .refunds:
            "arrow.uturn.backward.circle.fill"

        case .other:
            "plus.circle.fill"
        }
    }
}
