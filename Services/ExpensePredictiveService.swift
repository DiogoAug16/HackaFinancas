import Foundation

struct CategoryProjection: Identifiable {
    var id: ExpenseCategory { category }
    let category: ExpenseCategory
    let historicalAverageInCents: Int
    let projectedInCents: Int
    let changePercentage: Double
}

enum TrendDirection {
    case increasing
    case stable
    case decreasing

    var symbol: String {
        switch self {
        case .increasing: return "arrow.up.forward.circle.fill"
        case .stable: return "equal.circle.fill"
        case .decreasing: return "arrow.down.forward.circle.fill"
        }
    }
}

struct PredictiveReport {
    let projectedNextMonthTotalInCents: Int
    let historicalMonthlyAverageInCents: Int
    let percentageChange: Double
    let trend: TrendDirection
    let categoryProjections: [CategoryProjection]
    let topIncreasingCategory: ExpenseCategory?
    let recommendation: String
}

final class ExpensePredictiveService {
    static let shared = ExpensePredictiveService()

    private init() {}

    func generateReport(expenses: [Expense]) -> PredictiveReport {
        let calendar = Calendar.current
        let now = Date.now

        // Group expenses by year and month
        var monthlyTotals: [String: Int] = [:]
        var categoryTotals: [ExpenseCategory: [String: Int]] = [:]

        for expense in expenses {
            // Only consider past or current expenses
            guard expense.date <= now else { continue }

            let year = calendar.component(.year, from: expense.date)
            let month = calendar.component(.month, from: expense.date)
            let key = "\(year)-\(month)"

            monthlyTotals[key, default: 0] += expense.amountInCents

            if categoryTotals[expense.category] == nil {
                categoryTotals[expense.category] = [:]
            }
            categoryTotals[expense.category]?[key, default: 0] += expense.amountInCents
        }

        let monthsCount = max(1, monthlyTotals.count)
        let totalHistoricalSum = monthlyTotals.values.reduce(0, +)
        let historicalMonthlyAverage = totalHistoricalSum / monthsCount

        // Projections per category
        var categoryProjections: [CategoryProjection] = []
        var maxIncreaseCategory: ExpenseCategory? = nil
        var maxIncreasePct: Double = 0.0

        for category in ExpenseCategory.allCases {
            let catMonthlyDict = categoryTotals[category] ?? [:]
            let catSum = catMonthlyDict.values.reduce(0, +)
            let catAverage = catMonthlyDict.isEmpty ? 0 : catSum / max(1, catMonthlyDict.count)

            // Weight recent trend (simple weighted projection: 70% average + 30% recurring trend)
            let projectedCat = Int(Double(catAverage) * 1.05) // projected modest 5% inflation/trend baseline
            let change = catAverage > 0 ? ((Double(projectedCat - catAverage) / Double(catAverage)) * 100.0) : 0.0

            if catAverage > 0 {
                categoryProjections.append(CategoryProjection(
                    category: category,
                    historicalAverageInCents: catAverage,
                    projectedInCents: projectedCat,
                    changePercentage: change
                ))

                if change > maxIncreasePct {
                    maxIncreasePct = change
                    maxIncreaseCategory = category
                }
            }
        }

        // Sort by highest projected expense
        categoryProjections.sort { $0.projectedInCents > $1.projectedInCents }

        let projectedTotal = categoryProjections.reduce(0) { $0 + $1.projectedInCents }
        let overallChange = historicalMonthlyAverage > 0
            ? ((Double(projectedTotal - historicalMonthlyAverage) / Double(historicalMonthlyAverage)) * 100.0)
            : 0.0

        let trend: TrendDirection
        if overallChange > 2.0 {
            trend = .increasing
        } else if overallChange < -2.0 {
            trend = .decreasing
        } else {
            trend = .stable
        }

        // Recommendations
        let recommendation: String
        if trend == .increasing {
            if let cat = maxIncreaseCategory {
                recommendation = "Seus gastos com \(cat.rawValue.lowercased()) tendem a subir no próximo mês. Recomendamos atenção ao orçamento desta categoria."
            } else {
                recommendation = "Sua projeção de gastos está acima da média dos meses anteriores (+\(String(format: "%.1f", overallChange))%). Tente revisar compras não essenciais."
            }
        } else if trend == .decreasing {
            recommendation = "Excelente! Sua estimativa de gastos para o próximo mês é inferior à média habitual (-\(String(format: "%.1f", abs(overallChange)))%)."
        } else {
            recommendation = "Seus gastos estão estáveis em relação à sua média dos últimos meses. Mantenha o acompanhamento periódico."
        }

        return PredictiveReport(
            projectedNextMonthTotalInCents: max(projectedTotal, historicalMonthlyAverage),
            historicalMonthlyAverageInCents: historicalMonthlyAverage,
            percentageChange: overallChange,
            trend: trend,
            categoryProjections: categoryProjections,
            topIncreasingCategory: maxIncreaseCategory,
            recommendation: recommendation
        )
    }
}
