import Charts
import SwiftUI

struct CategoryChartData: Identifiable {
    let id = UUID()
    let category: ExpenseCategory
    let totalInCents: Int
    let percentage: Double
    let color: Color
}

struct DonutChartView: View {
    @Environment(\.colorScheme) private var colorScheme

    let expenses: [Expense]
    @Binding var selectedPeriod: ExpenseReportPeriod

    private let calendar = Calendar.current
    private let locale = Locale(identifier: "pt_BR")

    private var filteredExpenses: [Expense] {
        ExpenseSummary.expenses(
            from: expenses,
            in: selectedPeriod,
            containing: Date.now,
            calendar: calendar
        )
    }

    private var totalInCents: Int {
        filteredExpenses.reduce(0) { $0 + $1.amountInCents }
    }

    private var chartData: [CategoryChartData] {
        let totals = ExpenseSummary.totalByCategory(filteredExpenses)
        let totalSum = max(1, totalInCents)

        // Palette of vibrant colors for categories
        let colors: [Color] = [
            AppStyle.mintStrong,
            Color.orange,
            Color.purple,
            Color.blue,
            Color.pink,
            Color.teal,
            Color.indigo,
            Color.yellow,
            Color.red,
            Color.cyan
        ]

        return totals.enumerated().map { index, item in
            let pct = (Double(item.totalInCents) / Double(totalSum)) * 100.0
            return CategoryChartData(
                category: item.category,
                totalInCents: item.totalInCents,
                percentage: pct,
                color: colors[index % colors.count]
            )
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header & Period Picker
            HStack {
                Label("Gráfico em Rosca", systemImage: "chart.pie.fill")
                    .font(.headline)

                Spacer()

                Picker("Período", selection: $selectedPeriod) {
                    ForEach(ExpenseReportPeriod.allCases) { period in
                        Text(period.title).tag(period)
                    }
                }
                .pickerStyle(.menu)
                .font(.caption.bold())
            }

            if chartData.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "chart.pie")
                        .font(.system(size: 44))
                        .foregroundStyle(.tertiary)

                    Text("Nenhum gasto no período selecionado")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 180)
            } else {
                VStack(spacing: 20) {
                    // Donut Chart Container with Center Total
                    ZStack {
                        Chart(chartData) { item in
                            SectorMark(
                                angle: .value("Gasto", item.totalInCents),
                                innerRadius: .ratio(0.66),
                                angularInset: 2.0
                            )
                            .cornerRadius(5)
                            .foregroundStyle(item.color)
                        }
                        .frame(height: 220)

                        // Center Content
                        VStack(spacing: 4) {
                            Text("Total Gasto")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)

                            Text(totalInCents.currencyText)
                                .font(.system(.title3, design: .rounded, weight: .bold))
                                .minimumScaleFactor(0.7)
                                .lineLimit(1)
                        }
                        .padding(10)
                    }

                    // Legend Grid
                    VStack(spacing: 10) {
                        ForEach(chartData) { item in
                            HStack(spacing: 10) {
                                Circle()
                                    .fill(item.color)
                                    .frame(width: 12, height: 12)

                                Image(systemName: item.category.symbol)
                                    .font(.caption.bold())
                                    .foregroundStyle(.secondary)

                                Text(item.category.rawValue)
                                    .font(.subheadline)
                                    .lineLimit(1)

                                Spacer()

                                Text("\(String(format: "%.1f", item.percentage))%")
                                    .font(.caption.bold())
                                    .foregroundStyle(.secondary)

                                Text(item.totalInCents.currencyText)
                                    .font(.subheadline.weight(.semibold))
                            }
                            .padding(.vertical, 3)

                            if item.id != chartData.last?.id {
                                Divider()
                            }
                        }
                    }
                }
            }
        }
        .appCard(colorScheme: colorScheme)
    }
}
