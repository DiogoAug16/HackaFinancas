import SwiftData
import SwiftUI

struct IncomeListView: View {
    private enum StatusFilter:
        String,
        CaseIterable,
        Identifiable {
        case all
        case received
        case receivable

        var id: String {
            rawValue
        }

        var title: String {
            switch self {
            case .all:
                "Todas"

            case .received:
                "Recebidas"

            case .receivable:
                "A receber"
            }
        }

        var symbol: String {
            switch self {
            case .all:
                "square.grid.2x2.fill"

            case .received:
                "checkmark.circle.fill"

            case .receivable:
                "clock.fill"
            }
        }
    }

    @Environment(\.modelContext)
    private var modelContext
    @Environment(\.colorScheme)
    private var colorScheme

    @Query(
        sort: \IncomeEntry.date,
        order: .reverse
    )
    private var entries: [IncomeEntry]

    @State private var selectedMonth = Date()
    @State private var searchText = ""
    @State private var selectedCategory:
        IncomeCategory?
    @State private var selectedStatus:
        StatusFilter = .all
    @State private var pendingSeriesDeletion:
        IncomeEntry?
    @State private var operationError: String?

    let onSettings: () -> Void

    init(
        onSettings: @escaping () -> Void = {}
    ) {
        self.onSettings = onSettings
    }

    private var monthEntries: [IncomeEntry] {
        IncomeSummary.cashFlowEntries(
            from: entries,
            in: .month,
            containing: selectedMonth
        )
    }

    private var visibleEntries: [IncomeEntry] {
        let normalizedSearch =
            searchText.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        return monthEntries
            .filter { entry in
                let matchesSearch =
                    normalizedSearch.isEmpty
                    || entry.title
                        .localizedCaseInsensitiveContains(
                            normalizedSearch
                        )
                    || entry.category.title
                        .localizedCaseInsensitiveContains(
                            normalizedSearch
                        )
                    || entry.notes
                        .localizedCaseInsensitiveContains(
                            normalizedSearch
                        )

                let matchesCategory =
                    selectedCategory == nil
                    || entry.category
                        == selectedCategory

                let matchesStatus: Bool

                switch selectedStatus {
                case .all:
                    matchesStatus = true

                case .received:
                    matchesStatus =
                        entry.isReceived

                case .receivable:
                    matchesStatus =
                        !entry.isReceived
                }

                return matchesSearch
                    && matchesCategory
                    && matchesStatus
            }
            .sorted {
                IncomeSummary.cashFlowDate(
                    for: $0
                ) > IncomeSummary.cashFlowDate(
                    for: $1
                )
            }
    }

    private var receivedTotalInCents: Int {
        IncomeSummary.receivedTotalInCents(
            monthEntries
        )
    }

    private var receivableTotalInCents: Int {
        IncomeSummary.receivableTotalInCents(
            monthEntries
        )
    }

    private var currentMonthTitle: String {
        selectedMonth
            .formatted(
                .dateTime
                    .month(.wide)
                    .year()
                    .locale(
                        Locale(
                            identifier: "pt_BR"
                        )
                    )
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
                    spacing: 16
                ) {
                    header
                    monthSelector
                    totalsSection
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
                    if let pendingSeriesDeletion {
                        deleteSeries(
                            containing:
                                pendingSeriesDeletion
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
                    "Todas as entradas dessa recorrência serão removidas."
                )
            }
        }
    }

    private var header: some View {
        AppHeader(
            title: "Entradas",
            subtitle:
                "\(receivedTotalInCents.currencyText) recebidos",
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

    private var totalsSection: some View {
        HStack(spacing: 12) {
            totalCard(
                title: "Recebido",
                value: receivedTotalInCents,
                symbol: "checkmark.circle.fill",
                highlighted: true
            )

            totalCard(
                title: "A receber",
                value: receivableTotalInCents,
                symbol: "clock.fill",
                highlighted: false
            )
        }
    }

    private func totalCard(
        title: String,
        value: Int,
        symbol: String,
        highlighted: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Label(title, systemImage: symbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(
                    highlighted
                        ? AppStyle.accentForeground(
                            colorScheme
                        )
                        : Color.secondary
                )

            Text(value.currencyText)
                .font(
                    .system(
                        .headline,
                        design: .rounded,
                        weight: .semibold
                    )
                )
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .padding(14)
        .background(
            AppStyle.surface(colorScheme),
            in: RoundedRectangle(
                cornerRadius: AppStyle.cardRadius,
                style: .continuous
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: AppStyle.cardRadius,
                style: .continuous
            )
            .stroke(
                AppStyle.border(colorScheme),
                lineWidth: 1
            )
        }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField(
                "buscar entrada...",
                text: $searchText
            )
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(
                        systemName:
                            "xmark.circle.fill"
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
                cornerRadius:
                    AppStyle.controlRadius,
                style: .continuous
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius:
                    AppStyle.controlRadius,
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
                ForEach(StatusFilter.allCases) {
                    status in
                    filterButton(
                        title: status.title,
                        symbol: status.symbol,
                        isSelected:
                            selectedStatus == status
                    ) {
                        withAnimation(
                            .easeInOut(
                                duration: 0.18
                            )
                        ) {
                            selectedStatus = status
                        }
                    }
                }

                Rectangle()
                    .fill(
                        AppStyle.border(
                            colorScheme
                        )
                    )
                    .frame(width: 1, height: 26)
                    .padding(.horizontal, 2)
                    .accessibilityHidden(true)

                filterButton(
                    title: "Categorias",
                    symbol: "tag.fill",
                    isSelected:
                        selectedCategory == nil
                ) {
                    withAnimation(
                        .easeInOut(duration: 0.18)
                    ) {
                        selectedCategory = nil
                    }
                }

                ForEach(IncomeCategory.allCases) {
                    category in
                    filterButton(
                        title: category.title,
                        symbol: category.symbol,
                        isSelected:
                            selectedCategory
                                == category
                    ) {
                        withAnimation(
                            .easeInOut(
                                duration: 0.18
                            )
                        ) {
                            selectedCategory =
                                category
                        }
                    }
                }
            }
        }
        .accessibilityLabel(
            "Filtros por situação e categoria"
        )
    }

    private func filterButton(
        title: String,
        symbol: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
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
                        : AppStyle.surface(
                            colorScheme
                        ),
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
    }

    private var resultInformation: some View {
        HStack {
            Text("Entradas do mês")
                .font(.headline)

            Spacer()

            Text(
                "\(visibleEntries.count) de \(monthEntries.count)"
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var content: some View {
        if entries.isEmpty {
            emptyState(
                title: "Organize o que entra",
                description:
                    "Cadastre renda, bolsas, vendas e outros recebimentos pelo botão +."
            )
        } else if monthEntries.isEmpty {
            emptyState(
                title: "Nenhuma entrada neste mês",
                description:
                    "Navegue por outros meses ou toque em + para adicionar."
            )
        } else if visibleEntries.isEmpty {
            emptyState(
                title: "Nenhuma entrada encontrada",
                description:
                    "Altere a busca ou os filtros para ver outros lançamentos."
            )
        } else {
            LazyVStack(spacing: 12) {
                ForEach(visibleEntries) { entry in
                    NavigationLink {
                        IncomeDetailView(entry: entry)
                    } label: {
                        IncomeCard(entry: entry)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(role: .destructive) {
                            delete(entry)
                        } label: {
                            Label(
                                entry.seriesID == nil
                                    ? "Excluir entrada"
                                    : "Excluir esta ocorrência",
                                systemImage: "trash"
                            )
                        }

                        if entry.seriesID != nil {
                            Button(role: .destructive) {
                                pendingSeriesDeletion =
                                    entry
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
                size: 150
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
            minHeight: 330
        )
        .padding(.horizontal, 24)
    }

    private func delete(
        _ entry: IncomeEntry
    ) {
        Task {
            do {
                try await CloudantStore.shared.delete(entry)
                modelContext.delete(entry)
                try modelContext.save()
            } catch {
                modelContext.rollback()
                operationError = error.localizedDescription
            }
        }
    }

    private func deleteSeries(
        containing entry: IncomeEntry
    ) {
        guard let seriesID = entry.seriesID else {
            delete(entry)
            return
        }

        Task {
            do {
                let descriptor =
                    FetchDescriptor<IncomeEntry>()
                let seriesEntries =
                    try modelContext
                        .fetch(descriptor)
                        .filter {
                            $0.seriesID == seriesID
                        }

                for seriesEntry in seriesEntries {
                    try await CloudantStore.shared.delete(
                        seriesEntry
                    )
                    modelContext.delete(seriesEntry)
                }

                try modelContext.save()
            } catch {
                modelContext.rollback()
                operationError = error.localizedDescription
            }
        }
    }

    private func changeMonth(
        by value: Int
    ) {
        guard let newMonth =
            Calendar.current.date(
                byAdding: .month,
                value: value,
                to: selectedMonth
            )
        else {
            return
        }

        withAnimation(
            .easeInOut(duration: 0.2)
        ) {
            selectedMonth = newMonth
        }
    }
}
