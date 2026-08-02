import SwiftData
import SwiftUI

struct ExpenseDetailView: View {
    private enum EditScope: Equatable {
        case single
        case future
        case series
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @Query private var trackedItems: [TrackedItem]

    let expense: Expense

    @State private var title: String
    @State private var amountText: String
    @State private var date: Date
    @State private var category: ExpenseCategory
    @State private var notes: String
    @State private var customSymbolName: String?
    @State private var imageData: Data?
    @State private var originalImageData: Data?
    @State private var isLoadingStoredImage: Bool
    @State private var imageLoadGeneration =
        UUID()
    @State private var isProcessingPhoto = false
    @State private var didChangeRepresentation =
        false

    @State private var isEditing = false
    @State private var showingItemTrackingForm = false
    @State private var showingEditScope = false
    @State private var showingDeleteConfirmation = false
    @State private var errorTitle =
        "Não foi possível salvar o gasto"
    @State private var saveError: String?

    private let locale = Locale(identifier: "pt_BR")

    init(expense: Expense) {
        self.expense = expense

        _title = State(initialValue: expense.title)
        _amountText = State(
            initialValue: CurrencyFormatter.amountInputText(
                from: expense.amountInCents
            )
        )
        _date = State(initialValue: expense.date)
        _category = State(initialValue: expense.category)
        _notes = State(initialValue: expense.notes)
        _customSymbolName = State(
            initialValue: expense.customSymbolName
        )
        _imageData = State(initialValue: nil)
        _originalImageData = State(initialValue: nil)
        _isLoadingStoredImage = State(
            initialValue:
                expense.imageIdentifier != nil
        )
    }

    private var amountInCents: Int? {
        CurrencyFormatter.parseAmount(amountText)
    }

    private var canSave: Bool {
        let normalizedTitle = title.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        return !normalizedTitle.isEmpty
            && (amountInCents ?? 0) > 0
            && isDateWithinSeries
            && !isProcessingPhoto
    }

    private var isDateWithinSeries: Bool {
        guard expense.recurrence.isRecurring,
              let endDate = expense.endDate
        else {
            return true
        }

        return Calendar.current.compare(
            date,
            to: endDate,
            toGranularity: .day
        ) != .orderedDescending
    }

    private var displayedTitle: String {
        if isEditing {
            let normalizedTitle = title.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

            return normalizedTitle.isEmpty
                ? "Novo gasto"
                : normalizedTitle
        }

        return expense.title
    }

    private var displayedAmountInCents: Int {
        if isEditing {
            return amountInCents
                ?? expense.amountInCents
        }

        return expense.amountInCents
    }

    private var displayedCategory: ExpenseCategory {
        isEditing ? category : expense.category
    }

    private var linkedItem: TrackedItem? {
        trackedItems.first {
            $0.sourceExpenseID == expense.id
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                heroCard

                if isEditing {
                    editSection
                } else {
                    informationSection
                    notesSection
                    itemTrackingSection
                    deleteButton
                }
            }
            .padding(20)
            .padding(.bottom, 24)
        }
        .background(
            AppStyle.background(colorScheme)
                .ignoresSafeArea()
        )
        .navigationTitle(
            isEditing
                ? "Editar gasto"
                : "Detalhes"
        )
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(
                placement: .topBarTrailing
            ) {
                if isEditing {
                    Button("Cancelar") {
                        cancelEditing()
                    }

                    Button("Salvar") {
                        requestSave()
                    }
                    .fontWeight(.semibold)
                    .disabled(!canSave)
                } else {
                    Button {
                        withAnimation(
                            .easeInOut(duration: 0.2)
                        ) {
                            isEditing = true
                        }
                    } label: {
                        if isLoadingStoredImage {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text("Editar")
                        }
                    }
                    .disabled(isLoadingStoredImage)
                    .accessibilityLabel(
                        isLoadingStoredImage
                            ? "Carregando imagem"
                            : "Editar"
                    )
                }
            }
        }
        .task(id: expense.imageIdentifier) {
            await loadStoredImage()
        }
        .sheet(
            isPresented: $showingItemTrackingForm
        ) {
            TrackedItemFormView(
                sourceExpense: expense
            )
        }
        .confirmationDialog(
            "Aplicar alterações à recorrência?",
            isPresented: $showingEditScope,
            titleVisibility: .visible
        ) {
            Button("Somente este lançamento") {
                save(scope: .single)
            }

            Button("Este e os próximos") {
                save(scope: .future)
            }

            Button("Série inteira") {
                save(scope: .series)
            }

            Button(
                "Cancelar",
                role: .cancel
            ) {}
        } message: {
            Text(
                "Título, valor, categoria, observação e representação seguem o escopo escolhido. A data altera somente este lançamento."
            )
        }
        .confirmationDialog(
            "Excluir este gasto?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            if expense.seriesID == nil {
                Button(
                    "Excluir gasto",
                    role: .destructive
                ) {
                    deleteExpense()
                }
            } else {
                Button(
                    "Excluir somente este lançamento",
                    role: .destructive
                ) {
                    deleteExpense()
                }

                Button(
                    "Excluir a série inteira",
                    role: .destructive
                ) {
                    deleteSeries()
                }
            }

            Button(
                "Cancelar",
                role: .cancel
            ) {}
        } message: {
            Text(
                expense.seriesID == nil
                    ? "Essa ação não poderá ser desfeita."
                    : "Você pode remover apenas esta data ou todos os lançamentos da série."
            )
        }
        .alert(
            errorTitle,
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
            Button(
                "OK",
                role: .cancel
            ) {}
        } message: {
            Text(saveError ?? "")
        }
    }

    private var heroCard: some View {
        VStack(spacing: 13) {
            if isEditing {
                AppVisual(
                    imageData: imageData,
                    symbolName:
                        customSymbolName
                            ?? displayedCategory.symbol,
                    size: 62,
                    cornerRadius: 19,
                    symbolForeground: .white,
                    symbolBackground:
                        Color.white.opacity(0.18)
                )
            } else {
                AppVisual(
                    expense: expense,
                    size: 62,
                    cornerRadius: 19,
                    symbolForeground: .white,
                    symbolBackground:
                        Color.white.opacity(0.18)
                )
            }

            Text(
                displayedAmountInCents.currencyText
            )
            .font(
                .system(
                    size: 39,
                    weight: .semibold,
                    design: .rounded
                )
            )
            .lineLimit(1)
            .minimumScaleFactor(0.65)

            Text(displayedTitle)
                .font(.headline)
                .lineLimit(2)
                .multilineTextAlignment(.center)

            Label(
                displayedCategory.rawValue,
                systemImage: displayedCategory.symbol
            )
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                Color.white.opacity(0.17),
                in: Capsule()
            )
        }
        .foregroundStyle(.white)
        .frame(
            maxWidth: .infinity
        )
        .padding(.vertical, 26)
        .padding(.horizontal, 20)
        .background(
            AppStyle.mintStrong.gradient,
            in: RoundedRectangle(
                cornerRadius: AppStyle.heroRadius,
                style: .continuous
            )
        )
        .shadow(
            color: AppStyle.mint.opacity(0.25),
            radius: 15,
            y: 8
        )
    }

    private var informationSection: some View {
        VStack(spacing: 0) {
            informationRow(
                title: "Data",
                value: formattedDate,
                systemImage: "calendar"
            )

            Divider()
                .padding(.leading, 50)

            if isFutureExpense {
                informationRow(
                    title: "Situação",
                    value: "Lançamento programado",
                    systemImage: "calendar.badge.clock"
                )

                Divider()
                    .padding(.leading, 50)
            }

            informationRow(
                title: "Categoria",
                value: expense.category.rawValue,
                systemImage: expense.category.symbol
            )

            Divider()
                .padding(.leading, 50)

            informationRow(
                title: "Periodicidade",
                value: expense.recurrence.summaryText,
                systemImage: expense.recurrence.symbol
            )

            if let endDate = expense.endDate,
               expense.recurrence.isRecurring {
                Divider()
                    .padding(.leading, 50)

                informationRow(
                    title: "Série programada até",
                    value: endDate.formatted(
                        .dateTime
                            .day()
                            .month(.abbreviated)
                            .year()
                            .locale(locale)
                    ),
                    systemImage: "calendar.badge.checkmark"
                )
            }

            Divider()
                .padding(.leading, 50)

            informationRow(
                title: "Criado em",
                value: expense.createdAt.shortDateText,
                systemImage: "clock"
            )
        }
        .appCard(
            colorScheme: colorScheme,
            padding: 4
        )
    }

    private func informationRow(
        title: String,
        value: String,
        systemImage: String
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
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

            VStack(
                alignment: .leading,
                spacing: 3
            ) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(value)
                    .font(.subheadline.weight(.semibold))
            }

            Spacer()
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 10)
    }

    private var notesSection: some View {
        VStack(
            alignment: .leading,
            spacing: 10
        ) {
            Label(
                "Observação",
                systemImage: "text.alignleft"
            )
            .font(.headline)

            Text(
                expense.notes.isEmpty
                    ? "Nenhuma observação registrada."
                    : expense.notes
            )
            .font(.subheadline)
            .foregroundStyle(
                expense.notes.isEmpty
                    ? Color.secondary
                    : Color.primary
            )
            .frame(
                maxWidth: .infinity,
                alignment: .leading
            )
        }
        .appCard(
            colorScheme: colorScheme
        )
    }

    @ViewBuilder
    private var itemTrackingSection: some View {
        if let linkedItem {
            NavigationLink {
                TrackedItemDetailView(
                    item: linkedItem
                )
            } label: {
                HStack(spacing: 13) {
                    AppVisual(
                        item: linkedItem,
                        size: 48,
                        cornerRadius: 13
                    )

                    VStack(
                        alignment: .leading,
                        spacing: 4
                    ) {
                        Text("Item acompanhado")
                            .font(.caption)
                            .foregroundStyle(
                                .secondary
                            )

                        Text(linkedItem.name)
                            .font(.headline)
                            .foregroundStyle(
                                .primary
                            )
                            .lineLimit(1)

                        Text(
                            linkedItem.primaryCostInCents
                                .map {
                                    "\($0.currencyText) \(linkedItem.trackingMode.unitSuffix)"
                                }
                                ?? "Registre um uso para calcular"
                        )
                        .font(.caption)
                        .foregroundStyle(
                            .secondary
                        )
                    }

                    Spacer(minLength: 8)

                    Image(
                        systemName: "chevron.right"
                    )
                    .font(.caption.bold())
                    .foregroundStyle(.tertiary)
                }
                .appCard(
                    colorScheme: colorScheme
                )
            }
            .buttonStyle(.plain)
        } else if !expense.recurrence.isRecurring,
                  !isFutureExpense {
            Button {
                showingItemTrackingForm = true
            } label: {
                HStack(spacing: 13) {
                    Image(
                        systemName:
                            "arrow.triangle.2.circlepath.circle.fill"
                    )
                    .font(.title2)
                    .foregroundStyle(
                        AppStyle.accentForeground(
                            colorScheme
                        )
                    )
                    .frame(width: 44, height: 44)
                    .background(
                        AppStyle.mint.opacity(0.12),
                        in: RoundedRectangle(
                            cornerRadius: 12,
                            style: .continuous
                        )
                    )

                    VStack(
                        alignment: .leading,
                        spacing: 3
                    ) {
                        Text("Acompanhar como item")
                            .font(.headline)
                            .foregroundStyle(.primary)

                        Text(
                            "Descubra o custo por dia ou por uso."
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 8)

                    Image(
                        systemName: "plus.circle.fill"
                    )
                    .foregroundStyle(
                        AppStyle.accentForeground(
                            colorScheme
                        )
                    )
                }
                .appCard(
                    colorScheme: colorScheme
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var editSection: some View {
        VStack(spacing: 16) {
            editField(
                title: "Descrição",
                systemImage: "text.cursor"
            ) {
                TextField(
                    "Descrição do gasto",
                    text: $title
                )
                .textInputAutocapitalization(
                    .sentences
                )
            }

            Divider()

            editField(
                title: "Valor",
                systemImage: "brazilianrealsign.circle"
            ) {
                HStack(spacing: 6) {
                    Text("R$")
                        .foregroundStyle(.secondary)

                    TextField(
                        "0,00",
                        text: $amountText
                    )
                    .keyboardType(.decimalPad)
                }
            }

            Divider()

            editField(
                title: "Data",
                systemImage: "calendar"
            ) {
                VStack(
                    alignment: .trailing,
                    spacing: 4
                ) {
                    DatePicker(
                        "",
                        selection: $date,
                        displayedComponents: .date
                    )
                    .labelsHidden()

                    if !isDateWithinSeries {
                        Text(
                            "Escolha uma data dentro da série."
                        )
                        .font(.caption2)
                        .foregroundStyle(.red)
                    }
                }
            }

            Divider()

            editField(
                title: "Categoria",
                systemImage: category.symbol
            ) {
                Picker(
                    "Categoria",
                    selection: $category
                ) {
                    ForEach(
                        ExpenseCategory.allCases
                    ) { category in
                        Label(
                            category.rawValue,
                            systemImage: category.symbol
                        )
                        .tag(category)
                    }
                }
                .pickerStyle(.menu)
            }

            Divider()

            VStack(
                alignment: .leading,
                spacing: 12
            ) {
                Label(
                    "Representação",
                    systemImage: "photo.on.rectangle"
                )
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(
                    AppStyle.accentForeground(
                        colorScheme
                    )
                )

                ExpenseVisualPicker(
                    customSymbolName:
                        $customSymbolName,
                    imageData: $imageData,
                    isProcessingPhoto:
                        $isProcessingPhoto,
                    category: category,
                    onRepresentationChange: {
                        didChangeRepresentation =
                            true
                    }
                )
            }

            Divider()

            VStack(
                alignment: .leading,
                spacing: 10
            ) {
                Label(
                    "Observação",
                    systemImage: "text.alignleft"
                )
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(
                    AppStyle.accentForeground(
                        colorScheme
                    )
                )

                TextField(
                    "Observação opcional",
                    text: $notes,
                    axis: .vertical
                )
                .lineLimit(3...6)
            }
        }
        .appCard(
            colorScheme: colorScheme
        )
    }

    private func editField<Content: View>(
        title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
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

            VStack(
                alignment: .leading,
                spacing: 5
            ) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                content()
            }

            Spacer()
        }
    }

    private var deleteButton: some View {
        Button(
            role: .destructive
        ) {
            showingDeleteConfirmation = true
        } label: {
            Label(
                "Excluir gasto",
                systemImage: "trash"
            )
            .font(.headline)
            .frame(
                maxWidth: .infinity
            )
            .padding(.vertical, 14)
            .background(
                Color.red.opacity(0.11),
                in: RoundedRectangle(
                    cornerRadius: AppStyle.controlRadius,
                    style: .continuous
                )
            )
        }
        .buttonStyle(.plain)
    }

    private var formattedDate: String {
        expense.date
            .formatted(
                .dateTime
                    .day()
                    .month(.wide)
                    .year()
                    .locale(locale)
            )
    }

    private var isFutureExpense: Bool {
        Calendar.current.compare(
            expense.date,
            to: Date.now,
            toGranularity: .day
        ) == .orderedDescending
    }

    private func requestSave() {
        if expense.seriesID == nil {
            save(scope: .single)
        } else {
            showingEditScope = true
        }
    }

    private func save(
        scope: EditScope
    ) {
        guard let amountInCents,
              amountInCents > 0,
              isDateWithinSeries,
              !isProcessingPhoto
        else {
            return
        }

        let previousImageIdentifier =
            expense.imageIdentifier
        var newImageIdentifier =
            previousImageIdentifier
        var createdImageIdentifier: String?

        Task {
            do {
            let targetExpenses =
                try expensesToEdit(
                    scope: scope,
                    originalDate: expense.date
                )
            let previousImageIdentifiers = Set(
                targetExpenses.compactMap(
                    \.imageIdentifier
                )
            )

            if didChangeRepresentation {
                if let imageData {
                    createdImageIdentifier =
                        try ExpenseImageStore.shared.save(
                            imageData
                        )
                    newImageIdentifier =
                        createdImageIdentifier
                } else {
                    newImageIdentifier = nil
                }
            }

            let normalizedTitle =
                title.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
            let normalizedNotes =
                notes.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

            for targetExpense in targetExpenses {
                targetExpense.title = normalizedTitle
                targetExpense.amountInCents =
                    amountInCents
                targetExpense.category = category
                targetExpense.notes = normalizedNotes
                if didChangeRepresentation {
                    targetExpense
                        .customSymbolName =
                            customSymbolName
                    targetExpense
                        .imageIdentifier =
                            newImageIdentifier
                }

                if targetExpense.id == expense.id {
                    targetExpense.date = date
                }

                try await CloudantStore.shared.save(
                    targetExpense
                )
            }

            try modelContext.save()

            if didChangeRepresentation {
                for imageIdentifier
                    in previousImageIdentifiers
                    where imageIdentifier
                        != newImageIdentifier {
                    removeImageIfUnreferenced(
                        imageIdentifier
                    )
                }

                originalImageData = imageData
            }

            didChangeRepresentation = false

            withAnimation(
                .easeInOut(duration: 0.2)
            ) {
                isEditing = false
            }
            } catch {
                modelContext.rollback()
                ExpenseImageStore.shared.delete(
                    createdImageIdentifier
                )
                errorTitle =
                    "Não foi possível salvar o gasto"
                saveError = error.localizedDescription
                resetDraft()
            }
        }
    }

    private func expensesToEdit(
        scope: EditScope,
        originalDate: Date
    ) throws -> [Expense] {
        guard scope != .single,
              let seriesID = expense.seriesID
        else {
            return [expense]
        }

        let descriptor = FetchDescriptor<Expense>()
        let seriesExpenses = try modelContext
            .fetch(descriptor)
            .filter {
                $0.seriesID == seriesID
            }

        switch scope {
        case .single:
            return [expense]

        case .future:
            return seriesExpenses.filter {
                $0.date >= originalDate
            }

        case .series:
            return seriesExpenses
        }
    }

    private func cancelEditing() {
        resetDraft()

        withAnimation(
            .easeInOut(duration: 0.2)
        ) {
            isEditing = false
        }
    }

    private func resetDraft() {
        title = expense.title
        amountText = CurrencyFormatter.amountInputText(
            from: expense.amountInCents
        )
        date = expense.date
        category = expense.category
        notes = expense.notes
        customSymbolName = expense.customSymbolName
        imageData = originalImageData
        didChangeRepresentation = false
    }

    @MainActor
    private func loadStoredImage() async {
        let generation = UUID()
        imageLoadGeneration = generation
        isLoadingStoredImage =
            expense.imageIdentifier != nil

        defer {
            if generation == imageLoadGeneration {
                isLoadingStoredImage = false
            }
        }

        guard let imageIdentifier =
            expense.imageIdentifier
        else {
            originalImageData = nil

            if !didChangeRepresentation {
                imageData = nil
            }
            return
        }

        let storedImageData = await ExpenseImageStore
            .shared
            .loadData(
                for: imageIdentifier
            )

        guard !Task.isCancelled,
              generation == imageLoadGeneration
        else {
            return
        }

        originalImageData = storedImageData

        if !didChangeRepresentation {
            imageData = storedImageData
        }
    }

    private func deleteExpense() {
        let imageIdentifier =
            expense.imageIdentifier

        Task {
            do {
                let unlinkedItems = try TrackedItemLinkService
                    .unlinkItems(
                        linkedTo: [expense.id],
                        in: modelContext
                    )
                for item in unlinkedItems {
                    try await CloudantStore.shared.save(item)
                }
                try await CloudantStore.shared.delete(expense)
                modelContext.delete(expense)
                try modelContext.save()
                removeImageIfUnreferenced(
                    imageIdentifier
                )
                dismiss()
            } catch {
                modelContext.rollback()
                errorTitle =
                    "Não foi possível excluir o gasto"
                saveError = error.localizedDescription
            }
        }
    }

    private func deleteSeries() {
        guard let seriesID = expense.seriesID else {
            deleteExpense()
            return
        }

        Task {
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
                let unlinkedItems = try TrackedItemLinkService
                    .unlinkItems(
                        linkedTo: expenseIDs,
                        in: modelContext
                    )

                for item in unlinkedItems {
                    try await CloudantStore.shared.save(item)
                }
                for seriesExpense in seriesExpenses {
                    try await CloudantStore.shared.delete(
                        seriesExpense
                    )
                    modelContext.delete(seriesExpense)
                }

                try modelContext.save()

                for imageIdentifier in imageIdentifiers {
                    removeImageIfUnreferenced(imageIdentifier)
                }

                dismiss()
            } catch {
                modelContext.rollback()
                errorTitle =
                    "Não foi possível excluir a série"
                saveError = error.localizedDescription
            }
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
}

#Preview {
    let configuration = ModelConfiguration(
        isStoredInMemoryOnly: true
    )

    let container = try! ModelContainer(
        for: Expense.self,
        TrackedItem.self,
        UsageRecord.self,
        configurations: configuration
    )

    let expense = Expense(
        title: "Almoço",
        amountInCents: 3590,
        date: .now,
        category: .food,
        notes: "Almoço durante o trabalho."
    )

    container.mainContext.insert(expense)

    return NavigationStack {
        ExpenseDetailView(
            expense: expense
        )
    }
    .modelContainer(container)
}
