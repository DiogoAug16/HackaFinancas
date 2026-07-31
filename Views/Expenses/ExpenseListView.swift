import SwiftData
import SwiftUI

struct ExpenseListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme

    @Query(
        sort: \Expense.date,
        order: .reverse
    )
    private var expenses: [Expense]

    @State private var searchText = ""
    @State private var selectedCategory: ExpenseCategory?
    @State private var selectedMonth = Date()
    @State private var operationError: String?
    @State private var pendingSeriesDeletion: Expense?

    let onSettings: () -> Void

    init(
        onSettings: @escaping () -> Void = {}
    ) {
        self.onSettings = onSettings
    }

    private var currentMonthExpenses: [Expense] {
        expenses.filter {
            Calendar.current.isDate(
                $0.date,
                equalTo: selectedMonth,
                toGranularity: .month
            )
        }
    }

    private var visibleExpenses: [Expense] {
        currentMonthExpenses.filter { expense in
            let normalizedSearch = searchText.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

            let matchesSearch =
                normalizedSearch.isEmpty
                || expense.title.localizedCaseInsensitiveContains(
                    normalizedSearch
                )
                || expense.category.rawValue.localizedCaseInsensitiveContains(
                    normalizedSearch
                )

            let matchesCategory =
                selectedCategory == nil
                || expense.category == selectedCategory

            return matchesSearch && matchesCategory
        }
    }

    private var totalInCents: Int {
        ExpenseSummary.totalInCents(
            currentMonthExpenses
        )
    }

    private var currentMonthTitle: String {
        selectedMonth
            .formatted(
                .dateTime
                    .month(.wide)
                    .year()
                    .locale(Locale(identifier: "pt_BR"))
            )
            .capitalized(
                with: Locale(identifier: "pt_BR")
            )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(
                    alignment: .leading,
                    spacing: 18
                ) {
                    header
                    monthSelector
                    searchBar
                    filters
                    resultInformation
                    content
                }
                .padding(20)
                .padding(.bottom, 12)
            }
            .background(
                AppStyle.background(colorScheme)
                    .ignoresSafeArea()
            )
            .toolbar(.hidden, for: .navigationBar)
            .alert(
                "Não foi possível concluir a ação",
                isPresented: Binding(
                    get: {
                        operationError != nil
                    },
                    set: { isPresented in
                        if !isPresented {
                            operationError = nil
                        }
                    }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(operationError ?? "")
            }
            .confirmationDialog(
                "Excluir a série inteira?",
                isPresented: Binding(
                    get: {
                        pendingSeriesDeletion != nil
                    },
                    set: { isPresented in
                        if !isPresented {
                            pendingSeriesDeletion = nil
                        }
                    }
                ),
                titleVisibility: .visible
            ) {
                Button(
                    "Excluir todos os lançamentos",
                    role: .destructive
                ) {
                    if let expense =
                        pendingSeriesDeletion {
                        deleteSeries(
                            containing: expense
                        )
                    }

                    pendingSeriesDeletion = nil
                }

                Button(
                    "Cancelar",
                    role: .cancel
                ) {
                    pendingSeriesDeletion = nil
                }
            } message: {
                Text(
                    "Todos os lançamentos dessa recorrência serão removidos."
                )
            }
        }
    }

    private var header: some View {
        AppHeader(
            title: "Meus gastos",
            subtitle:
                "\(totalInCents.currencyText) em \(currentMonthTitle.lowercased())",
            onSettings: onSettings
        )
    }

    private var monthSelector: some View {
        HStack {
            monthButton(
                systemImage: "chevron.left",
                accessibilityLabel: "Mês anterior"
            ) {
                changeMonth(by: -1)
            }

            Spacer()

            VStack(spacing: 2) {
                Text(currentMonthTitle)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                if Calendar.current.isDate(
                    selectedMonth,
                    equalTo: .now,
                    toGranularity: .month
                ) {
                    Text("mês atual")
                        .font(.caption2)
                        .foregroundStyle(
                            AppStyle.accentForeground(
                                colorScheme
                            )
                        )
                }
            }

            Spacer()

            monthButton(
                systemImage: "chevron.right",
                accessibilityLabel: "Próximo mês"
            ) {
                changeMonth(by: 1)
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

    private func monthButton(
        systemImage: String,
        accessibilityLabel: String,
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
        .accessibilityLabel(accessibilityLabel)
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField(
                "buscar gasto...",
                text: $searchText
            )
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(
                        systemName: "xmark.circle.fill"
                    )
                }
                .foregroundStyle(.secondary)
                .buttonStyle(.plain)
                .accessibilityLabel("Limpar busca")
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 48)
        .background(
            AppStyle.surface(colorScheme),
            in: RoundedRectangle(
                cornerRadius: AppStyle.controlRadius,
                style: .continuous
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: AppStyle.controlRadius,
                style: .continuous
            )
            .stroke(
                AppStyle.border(colorScheme),
                lineWidth: 1
            )
        }
    }

    private var filters: some View {
        ScrollView(
            .horizontal,
            showsIndicators: false
        ) {
            HStack(spacing: 8) {
                filterButton(
                    title: "Todos",
                    symbol: "square.grid.2x2",
                    category: nil
                )

                ForEach(
                    ExpenseCategory.allCases
                ) { category in
                    filterButton(
                        title: category.rawValue,
                        symbol: category.symbol,
                        category: category
                    )
                }
            }
        }
    }

    private func filterButton(
        title: String,
        symbol: String,
        category: ExpenseCategory?
    ) -> some View {
        let isSelected = selectedCategory == category

        return Button {
            withAnimation(
                .easeInOut(duration: 0.18)
            ) {
                selectedCategory = category
            }
        } label: {
            Label(
                title,
                systemImage: symbol
            )
            .font(.caption.weight(.semibold))
            .foregroundStyle(
                isSelected
                    ? Color.white
                    : Color.secondary
            )
            .padding(.horizontal, 13)
            .padding(.vertical, 9)
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
                            AppStyle.border(colorScheme),
                            lineWidth: 1
                        )
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var resultInformation: some View {
        HStack {
            Text("Gastos do mês")
                .font(.headline)

            Spacer()

            Text(
                "\(visibleExpenses.count) de \(currentMonthExpenses.count)"
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var content: some View {
        if expenses.isEmpty {
            emptyState(
                title: "Seu controle começa aqui",
                description: "Toque no botão + para cadastrar o primeiro gasto."
            )
        } else if currentMonthExpenses.isEmpty {
            emptyState(
                title: "Nenhum gasto neste mês",
                description: "Navegue por outros meses ou toque em + para adicionar."
            )
        } else if visibleExpenses.isEmpty {
            emptyState(
                title: "Nenhum gasto encontrado",
                description: "Altere a busca ou selecione outra categoria."
            )
        } else {
            LazyVStack(spacing: 12) {
                ForEach(visibleExpenses) { expense in
                    NavigationLink {
                        ExpenseDetailView(
                            expense: expense
                        )
                    } label: {
                        ExpenseCard(
                            expense: expense
                        )
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(
                            role: .destructive
                        ) {
                            delete(expense)
                        } label: {
                            Label(
                                expense.seriesID == nil
                                    ? "Excluir gasto"
                                    : "Excluir este lançamento",
                                systemImage: "trash"
                            )
                        }

                        if expense.seriesID != nil {
                            Button(
                                role: .destructive
                            ) {
                                pendingSeriesDeletion =
                                    expense
                            } label: {
                                Label(
                                    "Excluir série inteira",
                                    systemImage:
                                        "trash.slash"
                                )
                            }
                        }
                    }
                }
            }
        }
    }

    private func emptyState(
        title: String,
        description: String
    ) -> some View {
        VStack(spacing: 14) {
            BrandLogo(
                variant: .playful,
                size: 155
            )

            Text(title)
                .font(.title3.bold())
                .multilineTextAlignment(.center)

            Text(description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(
            maxWidth: .infinity,
            minHeight: 350
        )
        .padding(.horizontal, 25)
    }

    private func delete(
        _ expense: Expense
    ) {
        let imageIdentifier =
            expense.imageIdentifier

        do {
            try TrackedItemLinkService
                .unlinkItems(
                    linkedTo: [expense.id],
                    in: modelContext
                )
            modelContext.delete(expense)
            try modelContext.save()
            removeImageIfUnreferenced(
                imageIdentifier
            )
        } catch {
            modelContext.rollback()
            operationError = error.localizedDescription
        }
    }

    private func deleteSeries(
        containing expense: Expense
    ) {
        guard let seriesID = expense.seriesID else {
            delete(expense)
            return
        }

        do {
            let descriptor = FetchDescriptor<Expense>()
            let seriesExpenses = try modelContext
                .fetch(descriptor)
                .filter {
                    $0.seriesID == seriesID
                }
            let imageIdentifiers = Set(
                seriesExpenses.compactMap(
                    \.imageIdentifier
                )
            )
            let expenseIDs = Set(
                seriesExpenses.map(\.id)
            )

            try TrackedItemLinkService
                .unlinkItems(
                    linkedTo: expenseIDs,
                    in: modelContext
                )

            for seriesExpense in seriesExpenses {
                modelContext.delete(seriesExpense)
            }

            try modelContext.save()

            for imageIdentifier
                in imageIdentifiers {
                removeImageIfUnreferenced(
                    imageIdentifier
                )
            }
        } catch {
            modelContext.rollback()
            operationError = error.localizedDescription
        }
    }

    private func removeImageIfUnreferenced(
        _ imageIdentifier: String?
    ) {
        AppImageReferenceService
            .deleteIfUnreferenced(
                identifier: imageIdentifier,
                in: modelContext
            )
    }

    private func changeMonth(
        by value: Int
    ) {
        guard let newMonth = Calendar.current.date(
            byAdding: .month,
            value: value,
            to: selectedMonth
        ) else {
            return
        }

        withAnimation(
            .easeInOut(duration: 0.2)
        ) {
            selectedMonth = newMonth
        }
    }
}
