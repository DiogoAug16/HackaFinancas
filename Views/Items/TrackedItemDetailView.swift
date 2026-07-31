import Foundation
import SwiftData
import SwiftUI

struct TrackedItemDetailView: View {
    private enum PendingDeletion {
        case item
        case usage(UsageRecord)
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext)
    private var modelContext
    @Environment(\.colorScheme)
    private var colorScheme

    @Bindable var item: TrackedItem

    @State private var showingEdit = false
    @State private var showingUsageForm = false
    @State private var showingStatusEditor =
        false
    @State private var pendingDeletion:
        PendingDeletion?
    @State private var operationError: String?

    private let locale =
        Locale(identifier: "pt_BR")

    private var sortedUsages: [UsageRecord] {
        item.usages.sorted {
            if $0.usedAt == $1.usedAt {
                return $0.createdAt
                    > $1.createdAt
            }

            return $0.usedAt > $1.usedAt
        }
    }

    var body: some View {
        ScrollView {
            VStack(
                alignment: .leading,
                spacing: 18
            ) {
                hero
                metrics
                informationSection

                if item.goalValueInCents != nil {
                    goalSection
                }

                if !item.notes.isEmpty {
                    notesSection
                }

                usageSection
                actionsSection
            }
            .padding(20)
            .padding(.bottom, 24)
        }
        .background(
            AppStyle.background(colorScheme)
                .ignoresSafeArea()
        )
        .navigationTitle(item.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(
                placement: .topBarTrailing
            ) {
                Button("Editar") {
                    showingEdit = true
                }
            }
        }
        .sheet(isPresented: $showingEdit) {
            TrackedItemFormView(item: item)
        }
        .sheet(isPresented: $showingUsageForm) {
            RegisterUsageView(item: item)
        }
        .sheet(
            isPresented: $showingStatusEditor
        ) {
            TrackedItemStatusEditorView(
                item: item
            )
        }
        .confirmationDialog(
            deletionTitle,
            isPresented: Binding(
                get: {
                    pendingDeletion != nil
                },
                set: { isPresented in
                    if !isPresented {
                        pendingDeletion = nil
                    }
                }
            ),
            titleVisibility: .visible
        ) {
            Button(
                deletionButtonTitle,
                role: .destructive
            ) {
                performPendingDeletion()
            }

            Button(
                "Cancelar",
                role: .cancel
            ) {
                pendingDeletion = nil
            }
        } message: {
            Text(deletionMessage)
        }
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
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 15) {
                AppVisual(
                    item: item,
                    size: 76,
                    cornerRadius: 20,
                    symbolForeground: .white,
                    symbolBackground:
                        .white.opacity(0.16)
                )

                VStack(
                    alignment: .leading,
                    spacing: 6
                ) {
                    Text(item.name)
                        .font(
                            .system(
                                .title2,
                                design: .rounded,
                                weight: .semibold
                            )
                        )
                        .lineLimit(2)

                    Label(
                        item.status.title,
                        systemImage:
                            item.status.symbol
                    )
                    .font(
                        .caption.weight(.semibold)
                    )
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        .white.opacity(0.16),
                        in: Capsule()
                    )
                }

                Spacer(minLength: 4)

                if item.isFavorite {
                    Image(systemName: "heart.fill")
                        .font(.title3)
                        .foregroundStyle(
                            Color.white
                        )
                        .accessibilityLabel(
                            "Favorito"
                        )
                }
            }

            Divider()
                .overlay(.white.opacity(0.25))

            VStack(alignment: .leading, spacing: 4) {
                Text(primaryCostTitle)
                    .font(.caption)
                    .foregroundStyle(
                        .white.opacity(0.82)
                    )

                if let primaryCost =
                    item.primaryCostInCents {
                    Text(primaryCost.currencyText)
                        .font(
                            .system(
                                size: 38,
                                weight: .semibold,
                                design: .rounded
                            )
                        )
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Text(primaryCostSuffix)
                        .font(.caption)
                        .foregroundStyle(
                            .white.opacity(0.82)
                        )
                } else {
                    Text("Sem usos ainda")
                        .font(
                            .system(
                                .title2,
                                design: .rounded,
                                weight: .semibold
                            )
                        )

                    Text(
                        "Registre um uso para calcular a média."
                    )
                    .font(.caption)
                    .foregroundStyle(
                        .white.opacity(0.82)
                    )
                }
            }
        }
        .foregroundStyle(.white)
        .padding(20)
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

    private var metrics: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ],
            spacing: 12
        ) {
            metricCard(
                title: item.isGift
                    ? "Valor estimado"
                    : "Valor pago",
                value:
                    item.acquisitionValueInCents
                    .currencyText,
                symbol: item.isGift
                    ? "gift.fill"
                    : "banknote.fill"
            )

            metricCard(
                title: "Tempo com você",
                value: ownershipText,
                symbol: "calendar"
            )

            metricCard(
                title: "Custo por dia",
                value:
                    item.costInCents(for: .day)
                    .currencyText,
                symbol: "sun.max.fill"
            )

            metricCard(
                title: "Custo por uso",
                value: costPerUseText,
                symbol: "checkmark.circle.fill"
            )
        }
    }

    private func metricCard(
        title: String,
        value: String,
        symbol: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Image(systemName: symbol)
                .font(.subheadline.bold())
                .foregroundStyle(
                    AppStyle.accentForeground(
                        colorScheme
                    )
                )
                .frame(width: 36, height: 36)
                .background(
                    AppStyle.mint.opacity(0.12),
                    in: RoundedRectangle(
                        cornerRadius: 11,
                        style: .continuous
                    )
                )

            Text(value)
                .font(
                    .system(
                        .headline,
                        design: .rounded,
                        weight: .semibold
                    )
                )
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .appCard(
            colorScheme: colorScheme,
            padding: 14
        )
    }

    private var informationSection: some View {
        sectionCard(title: "Sobre o item") {
            VStack(spacing: 0) {
                informationRow(
                    title: "Categoria",
                    value: item.category.title,
                    symbol: item.category.symbol
                )

                rowDivider

                informationRow(
                    title: "Adquirido em",
                    value: item.acquiredAt.formatted(
                        .dateTime
                            .day()
                            .month(.wide)
                            .year()
                            .locale(locale)
                    ),
                    symbol: "calendar"
                )

                rowDivider

                Button {
                    showingStatusEditor = true
                } label: {
                    HStack(spacing: 12) {
                        Image(
                            systemName:
                                item.status.symbol
                        )
                        .foregroundStyle(
                            AppStyle
                                .accentForeground(
                                    colorScheme
                                )
                        )
                        .frame(width: 28)

                        VStack(
                            alignment: .leading,
                            spacing: 3
                        ) {
                            Text("Situação")
                                .font(.caption)
                                .foregroundStyle(
                                    .secondary
                                )

                            Text(item.status.title)
                                .font(
                                    .subheadline
                                        .weight(
                                            .semibold
                                        )
                                )
                        }

                        Spacer()

                        Image(
                            systemName:
                                "chevron.right"
                        )
                        .font(.caption.bold())
                        .foregroundStyle(.tertiary)
                    }
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if item.sourceExpenseID != nil {
                    rowDivider

                    informationRow(
                        title: "Registro financeiro",
                        value: "Vinculado aos gastos",
                        symbol: "link"
                    )
                }

                if item.status == .sold,
                   let resaleValue =
                    item.resaleValueInCents {
                    rowDivider

                    informationRow(
                        title: "Valor da venda",
                        value:
                            resaleValue.currencyText,
                        symbol: "banknote.fill"
                    )
                }
            }
        }
    }

    private var goalSection: some View {
        sectionCard(title: "Meta") {
            HStack(alignment: .top, spacing: 13) {
                Image(
                    systemName:
                        goalReached
                            ? "checkmark.seal.fill"
                            : "target"
                )
                .font(.title3)
                .foregroundStyle(
                    goalReached
                        ? AppStyle
                            .accentForeground(
                                colorScheme
                            )
                        : AppStyle.gold
                )
                .frame(width: 42, height: 42)
                .background(
                    (
                        goalReached
                            ? AppStyle.mint
                            : AppStyle.gold
                    )
                    .opacity(0.12),
                    in: RoundedRectangle(
                        cornerRadius: 13,
                        style: .continuous
                    )
                )

                VStack(alignment: .leading, spacing: 5) {
                    Text(
                        goalReached
                            ? "Meta alcançada"
                            : "Meta em andamento"
                    )
                    .font(.headline)

                    Text(goalDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(
                            horizontal: false,
                            vertical: true
                        )
                }
            }
        }
    }

    private var notesSection: some View {
        sectionCard(title: "Observações") {
            Text(item.notes)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(
                    maxWidth: .infinity,
                    alignment: .leading
                )
        }
    }

    private var usageSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Histórico de usos")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                Spacer()

                if item.status.isActive {
                    Button {
                        showingUsageForm = true
                    } label: {
                        Label(
                            "Registrar",
                            systemImage: "plus"
                        )
                        .font(
                            .caption.weight(
                                .semibold
                            )
                        )
                    }
                }
            }
            .padding(.horizontal, 4)

            if sortedUsages.isEmpty {
                VStack(spacing: 10) {
                    Image(
                        systemName:
                            "checkmark.circle"
                    )
                    .font(.title2)
                    .foregroundStyle(
                        AppStyle.accentForeground(
                            colorScheme
                        )
                    )

                    Text("Nenhum uso registrado")
                        .font(.headline)

                    Text(
                        item.status.isActive
                            ? "Registre cada uso para descobrir quanto essa compra realmente valeu."
                            : "Este item foi encerrado sem usos registrados."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(
                        .center
                    )
                }
                .frame(
                    maxWidth: .infinity,
                    minHeight: 150
                )
                .appCard(
                    colorScheme: colorScheme
                )
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(sortedUsages) {
                        usage in
                        usageRow(usage)

                        if usage.id
                            != sortedUsages.last?.id {
                            Divider()
                                .padding(
                                    .leading,
                                    50
                                )
                        }
                    }
                }
                .appCard(
                    colorScheme: colorScheme,
                    padding: 14
                )
            }
        }
    }

    private func usageRow(
        _ usage: UsageRecord
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(
                systemName:
                    "checkmark.circle.fill"
            )
            .font(.subheadline.bold())
            .foregroundStyle(
                AppStyle.accentForeground(
                    colorScheme
                )
            )
            .frame(width: 36, height: 36)
            .background(
                AppStyle.mint.opacity(0.12),
                in: Circle()
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(
                    usage.usedAt.formatted(
                        .dateTime
                            .day()
                            .month(.wide)
                            .year()
                            .locale(locale)
                    )
                )
                .font(
                    .subheadline.weight(
                        .semibold
                    )
                )

                if !usage.notes.isEmpty {
                    Text(usage.notes)
                        .font(.caption)
                        .foregroundStyle(
                            .secondary
                        )
                }
            }

            Spacer(minLength: 8)

            Menu {
                Button(
                    role: .destructive
                ) {
                    pendingDeletion =
                        .usage(usage)
                } label: {
                    Label(
                        "Excluir uso",
                        systemImage: "trash"
                    )
                }
            } label: {
                Image(
                    systemName: "ellipsis"
                )
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
            }
            .accessibilityLabel(
                "Opções do uso"
            )
        }
        .padding(.vertical, 8)
    }

    private var actionsSection: some View {
        VStack(spacing: 12) {
            if item.status.isActive {
                Button {
                    showingUsageForm = true
                } label: {
                    Label(
                        "Registrar um uso",
                        systemImage:
                            "checkmark.circle.fill"
                    )
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        AppStyle.mintStrong,
                        in: RoundedRectangle(
                            cornerRadius:
                                AppStyle
                                    .controlRadius,
                            style: .continuous
                        )
                    )
                }
                .buttonStyle(.plain)
            }

            Button(role: .destructive) {
                pendingDeletion = .item
            } label: {
                Label(
                    "Excluir item",
                    systemImage: "trash"
                )
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    Color.red.opacity(0.11),
                    in: RoundedRectangle(
                        cornerRadius:
                            AppStyle.controlRadius,
                        style: .continuous
                    )
                )
            }
            .buttonStyle(.plain)
        }
    }

    private func sectionCard<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal, 4)

            content()
                .appCard(
                    colorScheme: colorScheme
                )
        }
    }

    private func informationRow(
        title: String,
        value: String,
        symbol: String
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(
                    AppStyle.accentForeground(
                        colorScheme
                    )
                )
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(value)
                    .font(
                        .subheadline.weight(
                            .semibold
                        )
                    )
            }

            Spacer()
        }
        .frame(minHeight: 44)
    }

    private var rowDivider: some View {
        Divider()
            .padding(.leading, 40)
            .padding(.vertical, 8)
    }

    private var primaryCostTitle: String {
        item.trackingMode == .usage
            ? "Custo médio"
            : "Custo de posse"
    }

    private var primaryCostSuffix: String {
        item.trackingMode == .usage
            ? "por uso registrado"
            : "por dia com você"
    }

    private var ownershipText: String {
        let days = item.daysOwned

        if days < 31 {
            return days == 1
                ? "1 dia"
                : "\(days) dias"
        }

        if days < 365 {
            let months = max(1, days / 30)
            return months == 1
                ? "1 mês"
                : "\(months) meses"
        }

        let years = max(1, days / 365)
        return years == 1
            ? "1 ano"
            : "\(years) anos"
    }

    private var costPerUseText: String {
        item.costPerUseInCents.map {
            $0.currencyText
        } ?? "Sem usos"
    }

    private var currentGoalCost: Int? {
        guard item.goalValueInCents != nil else {
            return nil
        }

        switch item.trackingMode {
        case .time:
            return item.costInCents(
                for: item.goalPeriod ?? .day
            )

        case .usage:
            return item.costPerUseInCents
        }
    }

    private var goalReached: Bool {
        guard
            let goal = item.goalValueInCents,
            let currentGoalCost
        else {
            return false
        }

        return currentGoalCost <= goal
    }

    private var goalDescription: String {
        guard let goal =
            item.goalValueInCents
        else {
            return ""
        }

        let targetDescription =
            item.trackingMode == .usage
                ? "\(goal.currencyText) por uso"
                : "\(goal.currencyText) por \((item.goalPeriod ?? .day).shortTitle)"

        guard let currentGoalCost else {
            return "Meta de \(targetDescription). Registre um uso para começar a medir."
        }

        let currentDescription =
            item.trackingMode == .usage
                ? "\(currentGoalCost.currencyText) por uso"
                : "\(currentGoalCost.currencyText) por \((item.goalPeriod ?? .day).shortTitle)"

        return "Atual: \(currentDescription). Meta: até \(targetDescription)."
    }

    private var deletionTitle: String {
        switch pendingDeletion {
        case .item:
            "Excluir este item?"

        case .usage:
            "Excluir este uso?"

        case nil:
            ""
        }
    }

    private var deletionButtonTitle: String {
        switch pendingDeletion {
        case .item:
            "Excluir item e histórico"

        case .usage:
            "Excluir uso"

        case nil:
            "Excluir"
        }
    }

    private var deletionMessage: String {
        switch pendingDeletion {
        case .item:
            "Os usos também serão apagados. O gasto vinculado será mantido."

        case .usage:
            "O custo médio por uso será recalculado."

        case nil:
            ""
        }
    }

    private func performPendingDeletion() {
        guard let pendingDeletion else {
            return
        }

        self.pendingDeletion = nil

        switch pendingDeletion {
        case .item:
            deleteItem()

        case let .usage(usage):
            deleteUsage(usage)
        }
    }

    private func deleteUsage(
        _ usage: UsageRecord
    ) {
        modelContext.delete(usage)

        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            operationError =
                error.localizedDescription
        }
    }

    private func deleteItem() {
        let imageIdentifier =
            item.imageIdentifier
        modelContext.delete(item)

        do {
            try modelContext.save()
            AppImageReferenceService
                .deleteIfUnreferenced(
                    identifier:
                        imageIdentifier,
                    in: modelContext
                )
            dismiss()
        } catch {
            modelContext.rollback()
            operationError =
                error.localizedDescription
        }
    }
}

private struct TrackedItemStatusEditorView:
    View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext)
    private var modelContext

    @Bindable var item: TrackedItem

    @State private var selectedStatus:
        ItemStatus
    @State private var retiredAt: Date
    @State private var resaleValueText:
        String
    @State private var isSaving = false
    @State private var saveError: String?

    private let locale =
        Locale(identifier: "pt_BR")

    init(item: TrackedItem) {
        self.item = item
        _selectedStatus = State(
            initialValue: item.status
        )
        _retiredAt = State(
            initialValue:
                item.retiredAt ?? .now
        )
        _resaleValueText = State(
            initialValue:
                item.resaleValueInCents.map {
                    CurrencyFormatter.amountInputText(
                        from: $0
                    )
                } ?? ""
        )
    }

    private var parsedResaleValueInCents:
        Int? {
        CurrencyFormatter.parseAmount(resaleValueText)
    }

    private var canSave: Bool {
        guard !isSaving else {
            return false
        }

        if selectedStatus.isActive {
            return true
        }

        if selectedStatus == .sold,
           !resaleValueText
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            .isEmpty {
            return isRetirementDateValid
                && parsedResaleValueInCents
                    != nil
        }

        return isRetirementDateValid
    }

    private var isRetirementDateValid: Bool {
        let calendar = Calendar.current
        let latestRequiredDate =
            item.lastUsageDate.map {
                max($0, item.acquiredAt)
            } ?? item.acquiredAt

        return calendar.compare(
            retiredAt,
            to: latestRequiredDate,
            toGranularity: .day
        ) != .orderedAscending
            && calendar.compare(
                retiredAt,
                to: .now,
                toGranularity: .day
            ) != .orderedDescending
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker(
                        "Situação",
                        selection: $selectedStatus
                    ) {
                        ForEach(
                            ItemStatus.allCases
                        ) { status in
                            Label(
                                status.title,
                                systemImage:
                                    status.symbol
                            )
                            .tag(status)
                        }
                    }
                }

                if !selectedStatus.isActive {
                    Section {
                        DatePicker(
                            dateLabel,
                            selection: $retiredAt,
                            displayedComponents:
                                .date
                        )

                        if selectedStatus == .sold {
                            TextField(
                                "Valor recebido (opcional)",
                                text:
                                    $resaleValueText
                            )
                            .keyboardType(.decimalPad)
                        }
                    } footer: {
                        if !isRetirementDateValid {
                            Text(
                                "O encerramento não pode ficar antes da aquisição ou do último uso."
                            )
                            .foregroundStyle(.red)
                        } else {
                            Text(
                                "O custo de posse para de contar nesta data."
                            )
                        }
                    }
                }
            }
            .navigationTitle("Situação do item")
            .navigationBarTitleDisplayMode(
                .inline
            )
            .toolbar {
                ToolbarItem(
                    placement: .cancellationAction
                ) {
                    Button("Cancelar") {
                        dismiss()
                    }
                    .disabled(isSaving)
                }

                ToolbarItem(
                    placement: .confirmationAction
                ) {
                    Button {
                        save()
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Salvar")
                        }
                    }
                    .disabled(!canSave)
                }
            }
            .alert(
                "Não foi possível alterar a situação",
                isPresented: Binding(
                    get: {
                        saveError != nil
                    },
                    set: { isPresented in
                        if !isPresented {
                            saveError = nil
                        }
                    }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(saveError ?? "")
            }
        }
    }

    private var dateLabel: String {
        switch selectedStatus {
        case .active:
            "Data"

        case .sold:
            "Data da venda"

        case .donated:
            "Data da doação"

        case .discarded:
            "Data do descarte"
        }
    }

    private func save() {
        guard canSave else {
            return
        }

        isSaving = true
        item.status = selectedStatus

        if selectedStatus.isActive {
            item.retiredAt = nil
            item.resaleValueInCents = nil
        } else {
            item.retiredAt = retiredAt
            item.resaleValueInCents =
                selectedStatus == .sold
                    ? parsedResaleValueInCents
                    : nil
        }

        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            saveError = error.localizedDescription
            isSaving = false
        }
    }
}
