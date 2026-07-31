import SwiftUI

struct PredictiveProjectionCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let expenses: [Expense]

    private var report: PredictiveReport {
        ExpensePredictiveService.shared.generateReport(expenses: expenses)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Projeção Preditiva", systemImage: "sparkles.tv.fill")
                    .font(.headline)

                Spacer()

                Image(systemName: report.trend.symbol)
                    .font(.title3)
                    .foregroundStyle(trendColor)
            }

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Estimativa Próximo Mês")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(report.projectedNextMonthTotalInCents.currencyText)
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .foregroundStyle(trendColor)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Média Histórica")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(report.historicalMonthlyAverageInCents.currencyText)
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                }
            }

            Divider()

            HStack(spacing: 10) {
                Image(systemName: "info.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(AppStyle.accentForeground(colorScheme))

                Text(report.recommendation)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 0)
            }

            if let topCat = report.topIncreasingCategory {
                HStack {
                    Text("Maior tendência de alta:")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Label(topCat.rawValue, systemImage: topCat.symbol)
                        .font(.caption2.bold())
                        .foregroundStyle(AppStyle.warningForeground(colorScheme))
                }
                .padding(.top, 2)
            }
        }
        .appCard(colorScheme: colorScheme)
    }

    private var trendColor: Color {
        switch report.trend {
        case .increasing:
            return AppStyle.warningForeground(colorScheme)
        case .decreasing:
            return AppStyle.accentForeground(colorScheme)
        case .stable:
            return .blue
        }
    }
}
