import Foundation

//Gerenciar os tipos de dispesas

enum ExpenseCategory: String, CaseIterable, Identifiable, Codable {
    case food = "Alimentação"
    case clothing = "Roupas"
    case electronics = "Eletrônicos"
    case transport = "Transporte"
    case home = "Casa"
    case tools = "Ferramentas"
    case leisure = "Lazer"
    case health = "Saúde"
    case education = "Educação"
    case subscriptions = "Assinaturas"
    case other = "Outros"

    var id: String {
        rawValue
    }

    var symbol: String {
        switch self {
        case .food:
            "fork.knife"

        case .clothing:
            "tshirt.fill"

        case .electronics:
            "desktopcomputer"

        case .transport:
            "car.fill"

        case .home:
            "house.fill"

        case .tools:
            "wrench.and.screwdriver.fill"

        case .leisure:
            "gamecontroller.fill"

        case .health:
            "cross.case.fill"

        case .education:
            "book.fill"

        case .subscriptions:
            "repeat.circle.fill"

        case .other:
            "square.grid.2x2.fill"
        }
    }
}
