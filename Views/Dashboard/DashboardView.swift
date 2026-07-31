import SwiftData
import SwiftUI

private struct CategoryTotal: Identifiable {
    let category: ExpenseCategory
    let totalInCents: Int

    var id: ExpenseCategory {
        category
    }
}

struct DashboardView: View {
    private enum SummaryMode: String, CaseIterable, Identifiable {
        case finances
        case consumption

        var id: String {
            rawValue
        }

        var title: String {
            switch self {
            case .finances:
                return "Finanças"

            case .consumption:
                return "Consumo"
            }
        }
    }

    @Environment(\.colorScheme) private var colorScheme

    @Query(
        sort: \Expense.date,
        order: .reverse
    )
    private var expenses: [Expense]

    @Query(
        sort: \IncomeEntry.date,
        order: .reverse
    )
    private var incomeEntries: [IncomeEntry]

    @State private var selectedReferenceDate = Date()
    @State private var selectedPeriod: ExpenseReportPeriod = .month
    @State private var summaryMode: SummaryMode = .finances

    let onSettings: () -> Void

    init(
        onSettings: @escaping () -> Void = {}
    ) {
        self.onSettings = onSettings
    }

    private let locale = Locale(
        identifier: "pt_BR"
    )
    private let calendar = Calendar.current

    private var periodExpenses: [Expense] {
        ExpenseSummary.expenses(
            from: expenses,
            in: selectedPeriod,
            containing: selectedReferenceDate,
            calendar: calendar
        )
    }

    private var reportedExpenses: [Expense] {
        guard !isFuturePeriod else {
            return periodExpenses
        }

        return periodExpenses.filter {
            calendar.compare(
                $0.date,
                to: Date.now,
                toGranularity: .day
            ) != .orderedDescending
        }
    }

    private var scheduledExpenses: [Expense] {
        guard isCurrentPeriod else {
            return []
        }

        return periodExpenses.filter {
            calendar.compare(
                $0.date,
                to: Date.now,
                toGranularity: .day
            ) == .orderedDescending
        }
    }

    private var scheduledTotalInCents: Int {
        ExpenseSummary.totalInCents(
            scheduledExpenses
        )
    }

    private var totalInCents: Int {
        ExpenseSummary.totalInCents(
            reportedExpenses
        )
    }

    private var scheduledIncomeEntries:
        [IncomeEntry] {
        IncomeSummary.entries(
            from: incomeEntries,
            in: selectedPeriod,
            containing: selectedReferenceDate,
            calendar: calendar
        )
    }

    private var receivedIncomeEntries:
        [IncomeEntry] {
        IncomeSummary.received(
            from: incomeEntries,
            in: selectedPeriod,
            containing: selectedReferenceDate,
            calendar: calendar
        )
    }

    private var receivableIncomeEntries:
        [IncomeEntry] {
        IncomeSummary.receivable(
            from: scheduledIncomeEntries
        )
    }

    private var receivedIncomeTotalInCents: Int {
        IncomeSummary.totalInCents(
            receivedIncomeEntries
        )
    }

    private var receivableIncomeTotalInCents: Int {
        IncomeSummary.totalInCents(
            receivableIncomeEntries
        )
    }

    private var consideredIncomeTotalInCents: Int {
        isFuturePeriod
            ? receivableIncomeTotalInCents
            : receivedIncomeTotalInCents
    }

    private var balanceInCents: Int {
        consideredIncomeTotalInCents
            - totalInCents
    }

    private var categoryTotals: [CategoryTotal] {
        ExpenseSummary
            .totalByCategory(
                reportedExpenses
            )
            .map { item in
                CategoryTotal(
                    category: item.category,
                    totalInCents: item.totalInCents
                )
            }
    }

    private var periodTitle: String {
        selectedPeriod.formattedTitle(
            containing: selectedReferenceDate,
            calendar: calendar,
            locale: locale
        )
    }

    private var selectedInterval: DateInterval? {
        ExpenseSummary.dateInterval(
            for: selectedPeriod,
            containing: selectedReferenceDate,
            calendar: calendar
        )
    }

    private var isCurrentPeriod: Bool {
        guard let selectedInterval else {
            return false
        }

        let now = Date.now

        return now >= selectedInterval.start
            && now < selectedInterval.end
    }

    private var isFuturePeriod: Bool {
        guard let selectedInterval else {
            return false
        }

        return selectedInterval.start > Date.now
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(
                    alignment: .leading,
                    spacing: 18
                ) {
                    header
                    summaryModePicker

                    if summaryMode == .finances {
                        periodPicker
                        periodNavigation
                        totalCard
                        cashFlowCard
                        DonutChartView(
                            expenses: expenses,
                            selectedPeriod: $selectedPeriod
                        )
                        PredictiveProjectionCard(
                            expenses: expenses
                        )
                        metrics
                        categorySection
                    } else {
                        ConsumptionSummaryContent()
                    }
                }
                .padding(20)
                .padding(.bottom, 12)
            }
            .background(
                AppStyle.background(colorScheme)
                    .ignoresSafeArea()
            )
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var header: some View {
        AppHeader(
            title: "Resumo",
            subtitle:
                summaryMode == .finances
                    ? "acompanhe entradas, gastos e saldo"
                    : "entenda o valor de uso das suas compras",
            onSettings: onSettings
        )
    }

    private var summaryModePicker: some View {
        Picker(
            "Tipo de resumo",
            selection: $summaryMode
        ) {
            ForEach(SummaryMode.allCases) { mode in
                Text(mode.title)
                    .tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityLabel("Tipo de resumo")
    }

    private var periodPicker: some View {
        HStack(spacing: 8) {
            ForEach(
                ExpenseReportPeriod.allCases
            ) { period in
                periodButton(period)
            }
        }
    }

    private func periodButton(
        _ period: ExpenseReportPeriod
    ) -> some View {
        let isSelected = selectedPeriod == period

        return Button {
            withAnimation(
                .easeInOut(duration: 0.18)
            ) {
                selectedPeriod = period
            }
        } label: {
            Text(period.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(
                    isSelected
                        ? Color.white
                        : Color.secondary
                )
                .frame(
                    maxWidth: .infinity,
                    minHeight: 44
                )
                .background(
                    isSelected
                        ? AppStyle.mintStrong
                        : AppStyle.surface(colorScheme),
                    in: Capsule()
                )
                .overlay {
                    if !isSelected {
                        Capsule()
                            .stroke(
                                AppStyle.border(
                                    colorScheme
                                ),
                                lineWidth: 1
                            )
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            "Período: \(period.title)"
        )
        .accessibilityAddTraits(
            isSelected ? .isSelected : []
        )
    }

    private var periodNavigation: some View {
        HStack {
            navigationButton(
                systemImage: "chevron.left",
                label:
                    selectedPeriod
                    .previousPeriodAccessibilityLabel
            ) {
                changePeriod(by: -1)
            }

            Spacer()

            VStack(spacing: 2) {
                Text(periodTitle)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                if isCurrentPeriod {
                    Text(
                        selectedPeriod
                            .currentPeriodText
                    )
                        .font(.caption2)
                        .foregroundStyle(
                            AppStyle.accentForeground(
                                colorScheme
                            )
                        )
                }
            }

            Spacer()

            navigationButton(
                systemImage: "chevron.right",
                label:
                    selectedPeriod
                    .nextPeriodAccessibilityLabel
            ) {
                changePeriod(by: 1)
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 54)
        .background(
            AppStyle.surface(colorScheme),
            in: RoundedRectangle(
                cornerRadius: 16,
                style: .continuous
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: 16,
                style: .continuous
            )
            .stroke(
                AppStyle.border(colorScheme),
                lineWidth: 1
            )
        }
    }

    private func navigationButton(
        systemImage: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.subheadline.bold())
                .foregroundStyle(
                    AppStyle.accentForeground(
                        colorScheme
                    )
                )
                .frame(width: 44, height: 44)
                .background(
                    AppStyle.mint.opacity(0.12),
                    in: Circle()
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private var totalCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(totalCardEyebrow)
                .font(.subheadline)
                .foregroundStyle(
                    .white.opacity(0.88)
                )

            Text(totalInCents.currencyText)
                .font(
                    .system(
                        size: 44,
                        weight: .semibold,
                        design: .rounded
                    )
                )
                .minimumScaleFactor(0.65)
                .lineLimit(1)

            Text("em \(periodTitle.lowercased())")
                .font(.headline)

            Text(expenseCountText)
                .font(.caption)
                .foregroundStyle(
                    .white.opacity(0.82)
                )
                .padding(.top, 3)

            if !scheduledExpenses.isEmpty {
                Text(scheduledExpenseText)
                    .font(.caption2)
                    .foregroundStyle(
                        .white.opacity(0.78)
                    )
            }
        }
        .foregroundStyle(.white)
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .padding(22)
        .background(
            AppStyle.mintStrong.gradient,
            in: RoundedRectangle(
                cornerRadius: AppStyle.heroRadius,
                style: .continuous
            )
        )
        .shadow(
            color: AppStyle.mint.opacity(0.25),
            radius: 14,
            y: 8
        )
    }

    private var expenseCountText: String {
        let status = isFuturePeriod
            ? "programado"
            : "registrado"

        switch reportedExpenses.count {
        case 0:
            return "nenhum lançamento \(status)"

        case 1:
            return "1 lançamento \(status)"

        default:
            return "\(reportedExpenses.count) lançamentos \(status)s"
        }
    }

    private var cashFlowCard: some View {
        VStack(
            alignment: .leading,
            spacing: 15
        ) {
            HStack {
                Label(
                    isFuturePeriod
                        ? "Previsão financeira"
                        : "Fluxo financeiro",
                    systemImage:
                        "arrow.left.arrow.right.circle.fill"
                )
                .font(.headline)

                Spacer()

                Text(periodTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            HStack(spacing: 10) {
                cashFlowMetric(
                    title: isFuturePeriod
                        ? "previsto"
                        : "recebido",
                    value:
                        consideredIncomeTotalInCents,
                    symbol:
                        "arrow.down.circle.fill",
                    color:
                        AppStyle.accentForeground(
                            colorScheme
                        )
                )

                cashFlowMetric(
                    title: "gasto",
                    value: totalInCents,
                    symbol:
                        "arrow.up.circle.fill",
                    color:
                        AppStyle.warningForeground(
                            colorScheme
                        )
                )

                cashFlowMetric(
                    title: isFuturePeriod
                        ? "saldo previsto"
                        : "saldo",
                    value: balanceInCents,
                    symbol:
                        balanceInCents >= 0
                            ? "equal.circle.fill"
                            : "exclamationmark.circle.fill",
                    color:
                        balanceInCents >= 0
                            ? AppStyle
                                .accentForeground(
                                    colorScheme
                                )
                            : AppStyle
                                .warningForeground(
                                    colorScheme
                                )
                )
            }

            if receivableIncomeTotalInCents > 0 {
                Label(
                    receivableIncomeDescription,
                    systemImage: "clock.fill"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .appCard(
            colorScheme: colorScheme
        )
        .accessibilityElement(
            children: .combine
        )
    }

    private func cashFlowMetric(
        title: String,
        value: Int,
        symbol: String,
        color: Color
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: 5
        ) {
            Image(systemName: symbol)
                .font(.caption.bold())
                .foregroundStyle(color)

            Text(value.currencyText)
                .font(
                    .system(
                        .subheadline,
                        design: .rounded,
                        weight: .semibold
                    )
                )
                .lineLimit(1)
                .minimumScaleFactor(0.58)

            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
    }

    private var receivableIncomeDescription:
        String {
        let amount =
            receivableIncomeTotalInCents
                .currencyText

        if isFuturePeriod {
            return "\(amount) a receber já entra nesta previsão."
        }

        return "\(amount) a receber não entra no saldo disponível."
    }

    private var totalCardEyebrow: String {
        if isFuturePeriod {
            return "gasto previsto"
        }

        if isCurrentPeriod {
            return "você gastou até hoje"
        }

        return "você gastou"
    }

    private var scheduledExpenseText: String {
        let count = scheduledExpenses.count

        if count == 1 {
            return "\(scheduledTotalInCents.currencyText) em 1 lançamento futuro não entra neste total"
        }

        return "\(scheduledTotalInCents.currencyText) em \(count) lançamentos futuros não entram neste total"
    }

    private var metrics: some View {
        HStack(spacing: 12) {
            metric(
                title: "lançamentos",
                value: "\(reportedExpenses.count)",
                symbol: "list.bullet.rectangle"
            )

            metric(
                title: "categorias",
                value: "\(categoryTotals.count)",
                symbol: "square.grid.2x2"
            )
        }
    }

    private func metric(
        title: String,
        value: String,
        symbol: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: symbol)
                .font(.subheadline.bold())
                .foregroundStyle(
                    AppStyle.accentForeground(
                        colorScheme
                    )
                )

            Text(value)
                .font(
                    .system(
                        .title2,
                        design: .rounded,
                        weight: .semibold
                    )
                )

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .appCard(
            colorScheme: colorScheme
        )
    }

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Por categoria")
                    .font(.headline)

                Spacer()

                if !categoryTotals.isEmpty {
                    Text("\(categoryTotals.count)")
                        .font(.caption.bold())
                        .foregroundStyle(
                            AppStyle.accentForeground(
                                colorScheme
                            )
                        )
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(
                            AppStyle.mint.opacity(0.12),
                            in: Capsule()
                        )
                }
            }

            if categoryTotals.isEmpty {
                VStack(spacing: 11) {
                    BrandLogo(
                        variant: .playful,
                        size: 125
                    )

                    Text("Nenhum gasto neste período")
                        .font(.subheadline.bold())

                    Text(
                        "Os totais por categoria aparecerão aqui."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                }
                .frame(
                    maxWidth: .infinity
                )
                .padding(.vertical, 8)
            } else {
                VStack(spacing: 0) {
                    ForEach(
                        Array(
                            categoryTotals.enumerated()
                        ),
                        id: \.element.id
                    ) { index, item in
                        categoryRow(item)

                        if index
                            < categoryTotals.count - 1 {
                            Divider()
                                .padding(
                                    .leading,
                                    50
                                )
                        }
                    }
                }
            }
        }
        .appCard(
            colorScheme: colorScheme
        )
    }

    private func categoryRow(
        _ item: CategoryTotal
    ) -> some View {
        HStack(spacing: 12) {
            Image(
                systemName: item.category.symbol
            )
            .font(.subheadline.bold())
            .foregroundStyle(
                AppStyle.accentForeground(
                    colorScheme
                )
            )
            .frame(width: 38, height: 38)
            .background(
                AppStyle.mint.opacity(0.12),
                in: RoundedRectangle(
                    cornerRadius: 11,
                    style: .continuous
                )
            )

            Text(item.category.rawValue)
                .font(.subheadline)

            Spacer()

            Text(
                item.totalInCents.currencyText
            )
            .font(
                .system(
                    .subheadline,
                    design: .rounded,
                    weight: .semibold
                )
            )
            .foregroundStyle(
                AppStyle.accentForeground(
                    colorScheme
                )
            )
        }
        .padding(.vertical, 10)
    }

    private func changePeriod(
        by value: Int
    ) {
        guard let newReferenceDate =
            selectedPeriod.date(
                byAdvancing:
                    selectedReferenceDate,
                value: value,
                calendar: calendar
            )
        else {
            return
        }

        withAnimation(
            .easeInOut(duration: 0.2)
        ) {
            selectedReferenceDate =
                newReferenceDate
        }
    }
}

#Preview {
    let configuration = ModelConfiguration(
        isStoredInMemoryOnly: true
    )
    let container = try! ModelContainer(
        for:
            Expense.self,
            IncomeEntry.self,
            TrackedItem.self,
            UsageRecord.self,
        configurations: configuration
    )

    return DashboardView()
        .modelContainer(container)
}
