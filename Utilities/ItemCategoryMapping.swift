import Foundation

extension ItemCategory {
    var expenseCategory: ExpenseCategory {
        switch self {
        case .clothing:
            return .clothing

        case .electronics:
            return .electronics

        case .home:
            return .home

        case .leisure:
            return .leisure

        case .study:
            return .education

        case .transport:
            return .transport

        case .health:
            return .health

        case .tools:
            return .tools

        case .other:
            return .other
        }
    }
}
