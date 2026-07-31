import Foundation

enum ItemCategory: String, CaseIterable, Identifiable, Codable, Sendable {
    case clothing
    case electronics
    case home
    case leisure
    case study
    case transport
    case health
    case tools
    case other

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .clothing:
            "Roupas"

        case .electronics:
            "Eletrônicos"

        case .home:
            "Casa"

        case .leisure:
            "Lazer"

        case .study:
            "Estudo"

        case .transport:
            "Transporte"

        case .health:
            "Saúde"

        case .tools:
            "Ferramentas"

        case .other:
            "Outros"
        }
    }

    var symbol: String {
        switch self {
        case .clothing:
            "tshirt.fill"

        case .electronics:
            "desktopcomputer"

        case .home:
            "house.fill"

        case .leisure:
            "gamecontroller.fill"

        case .study:
            "book.fill"

        case .transport:
            "car.fill"

        case .health:
            "cross.case.fill"

        case .tools:
            "wrench.and.screwdriver.fill"

        case .other:
            "shippingbox.fill"
        }
    }
}
