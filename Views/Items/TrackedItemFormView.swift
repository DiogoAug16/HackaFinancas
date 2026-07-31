import Foundation
import SwiftData
import SwiftUI

struct TrackedItemFormView: View {
    private enum AcquisitionKind:
        String,
        CaseIterable,
        Identifiable {
        case purchase = "Compra"
        case gift = "Presente"

        var id: String {
            rawValue
        }

        var symbol: String {
            switch self {
            case .purchase:
                "bag.fill"

            case .gift:
                "gift.fill"
            }
        }
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext)
    private var modelContext

    private let item: TrackedItem?
    private let sourceExpense: Expense?

    @State private var name: String
    @State private var amountText: String
    @State private var acquiredAt: Date
    @State private var category: ItemCategory
    @State private var notes: String
    @State private var acquisitionKind:
        AcquisitionKind
    @State private var trackingMode:
        ItemTrackingMode
    @State private var isFavorite: Bool
    @State private var createExpense: Bool
    @State private var goalEnabled: Bool
    @State private var goalValueText: String
    @State private var goalPeriod:
        ItemCostPeriod
    @State private var customSymbolName:
        String?
    @State private var imageData: Data?
    @State private var didChangeRepresentation =
        false
    @State private var isProcessingPhoto = false
    @State private var isSaving = false
    @State private var saveError: String?

    private let locale =
        Locale(identifier: "pt_BR")

    init(
        item: TrackedItem? = nil,
        sourceExpense: Expense? = nil
    ) {
        self.item = item
        self.sourceExpense = sourceExpense

        let initialName =
            item?.name
            ?? sourceExpense?.title
            ?? ""
        let initialValue =
            item?.acquisitionValueInCents
            ?? sourceExpense?.amountInCents
            ?? 0
        let initialDate =
            item?.acquiredAt
            ?? sourceExpense?.date
            ?? .now
        let initialCategory =
            item?.category
            ?? sourceExpense.map {
                Self.itemCategory(
                    for: $0.category
                )
            }
            ?? .other
        let initialNotes =
            item?.notes
            ?? sourceExpense?.notes
            ?? ""
        let initialImageIdentifier =
            item?.imageIdentifier
            ?? sourceExpense?.imageIdentifier
        let initialGoalValue =
            item?.goalValueInCents

        _name = State(
            initialValue: initialName
        )
        _amountText = State(
            initialValue:
                Self.amountInputText(
                    from: initialValue
                )
        )
        _acquiredAt = State(
            initialValue: initialDate
        )
        _category = State(
            initialValue: initialCategory
        )
        _notes = State(
            initialValue: initialNotes
        )
        _acquisitionKind = State(
            initialValue:
                item?.isGift == true
                    ? .gift
                    : .purchase
        )
        _trackingMode = State(
            initialValue:
                item?.trackingMode
                ?? .time
        )
        _isFavorite = State(
            initialValue:
                item?.isFavorite
                ?? false
        )
        _createExpense = State(
            initialValue:
                item == nil
                && sourceExpense == nil
        )
        _goalEnabled = State(
            initialValue:
                initialGoalValue != nil
        )
        _goalValueText = State(
            initialValue:
                initialGoalValue.map {
                    Self.amountInputText(
                        from: $0
                    )
                } ?? ""
        )
        _goalPeriod = State(
            initialValue:
                item?.goalPeriod
                ?? .day
        )
        _customSymbolName = State(
            initialValue:
                item?.customSymbolName
                ?? sourceExpense?
                    .customSymbolName
        )
        _imageData = State(
            initialValue:
                ExpenseImageStore.shared.data(
                    for:
                        initialImageIdentifier
                )
        )
    }

    private var normalizedName: String {
        name.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
    }

    private var parsedAmountInCents: Int? {
        Self.parseAmount(
            amountText,
            locale: locale
        )
    }

    private var acquisitionValueInCents:
        Int? {
        if acquisitionKind == .gift,
           amountText.trimmingCharacters(
               in: .whitespacesAndNewlines
           ).isEmpty {
            return 0
        }

        return parsedAmountInCents
    }

    private var parsedGoalValueInCents:
        Int? {
        Self.parseAmount(
            goalValueText,
            locale: locale
        )
    }

    private var isLinkedToExpense: Bool {
        sourceExpense != nil
            || item?.sourceExpenseID != nil
    }

    private var canSave: Bool {
        guard
            !normalizedName.isEmpty,
            let acquisitionValueInCents,
            acquisitionValueInCents >= 0,
            isAcquisitionDateValid,
            !isProcessingPhoto,
            !isSaving
        else {
            return false
        }

        if acquisitionKind == .purchase,
           acquisitionValueInCents == 0 {
            return false
        }

        if goalEnabled {
            return (parsedGoalValueInCents ?? 0)
                > 0
        }

        return true
    }

    private var isAcquisitionDateValid: Bool {
        let calendar = Calendar.current

        guard calendar.compare(
            acquiredAt,
            to: .now,
            toGranularity: .day
        ) != .orderedDescending
        else {
            return false
        }

        guard let item else {
            return true
        }

        let limitingDates =
            item.usages.map(\.usedAt)
            + [item.retiredAt]
                .compactMap { $0 }

        guard let firstRecordedDate =
            limitingDates.min()
        else {
            return true
        }

        return calendar.compare(
            acquiredAt,
            to: firstRecordedDate,
            toGranularity: .day
        ) != .orderedDescending
    }

    var body: some View {
        NavigationStack {
            Form {
                acquisitionSection
                trackingSection
                representationSection
                notesSection
            }
            .navigationTitle(
                item == nil
                    ? "Novo item"
                    : "Editar item"
            )
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
                "Não foi possível salvar o item",
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

    private var acquisitionSection: some View {
        Section {
            Picker(
                "Origem",
                selection: $acquisitionKind
            ) {
                ForEach(
                    AcquisitionKind.allCases
                ) { kind in
                    Label(
                        kind.rawValue,
                        systemImage: kind.symbol
                    )
                    .tag(kind)
                }
            }
            .pickerStyle(.segmented)
            .disabled(isLinkedToExpense)

            if isLinkedToExpense {
                Label(
                    "Este item já está ligado a um gasto. Editá-lo não criará outro lançamento.",
                    systemImage: "link"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            TextField(
                "Nome do item",
                text: $name
            )
            .textInputAutocapitalization(
                .sentences
            )

            TextField(
                acquisitionKind == .gift
                    ? "Valor estimado (opcional)"
                    : "Valor pago",
                text: $amountText
            )
            .keyboardType(.decimalPad)

            DatePicker(
                acquisitionKind == .gift
                    ? "Data em que recebeu"
                    : "Data da compra",
                selection: $acquiredAt,
                in: ...Date.now,
                displayedComponents: .date
            )

            Picker(
                "Categoria",
                selection: $category
            ) {
                ForEach(ItemCategory.allCases) {
                    category in
                    Label(
                        category.title,
                        systemImage: category.symbol
                    )
                    .tag(category)
                }
            }

            if item == nil,
               sourceExpense == nil,
               acquisitionKind == .purchase {
                Toggle(
                    "Registrar também nos gastos",
                    isOn: $createExpense
                )
            }
        } header: {
            Text("Aquisição")
        } footer: {
            if !isAcquisitionDateValid {
                Text(
                    "A aquisição não pode ficar no futuro nem depois de um uso ou encerramento já registrado."
                )
                .foregroundStyle(.red)
            }

            if item == nil,
               sourceExpense == nil,
               acquisitionKind == .purchase,
               createExpense {
                Text(
                    "A compra será cadastrada uma única vez nos gastos e ficará vinculada a este item."
                )
            } else if acquisitionKind == .gift {
                Text(
                    "Presentes não entram no total gasto. O valor estimado serve apenas para acompanhar o uso."
                )
            }
        }
    }

    private var trackingSection: some View {
        Section("Acompanhamento") {
            Picker(
                "Calcular por",
                selection: $trackingMode
            ) {
                ForEach(
                    ItemTrackingMode.allCases
                ) { mode in
                    Label(
                        mode.title,
                        systemImage: mode.symbol
                    )
                    .tag(mode)
                }
            }
            .pickerStyle(.segmented)

            Text(trackingMode.explanation)
                .font(.caption)
                .foregroundStyle(.secondary)

            Toggle(
                "Marcar como favorito",
                isOn: $isFavorite
            )

            Toggle(
                "Definir uma meta de custo",
                isOn: $goalEnabled
            )

            if goalEnabled {
                TextField(
                    trackingMode == .usage
                        ? "Custo máximo por uso"
                        : "Custo máximo",
                    text: $goalValueText
                )
                .keyboardType(.decimalPad)

                if trackingMode == .time {
                    Picker(
                        "Período da meta",
                        selection: $goalPeriod
                    ) {
                        ForEach(
                            ItemCostPeriod
                                .allCases
                        ) { period in
                            Text(period.title)
                                .tag(period)
                        }
                    }
                }
            }
        }
    }

    private var representationSection:
        some View {
        Section("Representação") {
            TrackedItemVisualPicker(
                customSymbolName:
                    $customSymbolName,
                imageData: $imageData,
                isProcessingPhoto:
                    $isProcessingPhoto,
                category: category
            ) {
                didChangeRepresentation =
                    true
            }
        }
    }

    private var notesSection: some View {
        Section("Observações") {
            TextField(
                "Estado, motivo da compra, garantia...",
                text: $notes,
                axis: .vertical
            )
            .lineLimit(3...7)
        }
    }

    private func save() {
        guard
            canSave,
            let acquisitionValueInCents
        else {
            return
        }

        isSaving = true
        var createdImageIdentifier: String?

        do {
            var linkedExpense =
                try findLinkedExpense()

            if item == nil,
               let linkedExpense,
               try expenseIsAlreadyTracked(
                   linkedExpense.id
               ) {
                throw TrackedItemFormError
                    .expenseAlreadyTracked
            }

            let previousImageIdentifiers =
                Set(
                    [
                        item?.imageIdentifier,
                        linkedExpense?
                            .imageIdentifier
                    ]
                    .compactMap { $0 }
                )

            var finalImageIdentifier =
                item?.imageIdentifier
                ?? linkedExpense?
                    .imageIdentifier

            if didChangeRepresentation {
                if let imageData {
                    let identifier =
                        try ExpenseImageStore
                            .shared
                            .save(imageData)
                    finalImageIdentifier =
                        identifier
                    createdImageIdentifier =
                        identifier
                } else {
                    finalImageIdentifier = nil
                }
            }

            let isGift =
                isLinkedToExpense
                    ? false
                    : acquisitionKind
                        == .gift
            let normalizedNotes =
                notes.trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )
            let goalValueInCents =
                goalEnabled
                    ? parsedGoalValueInCents
                    : nil
            let selectedGoalPeriod:
                ItemCostPeriod? =
                goalEnabled
                && trackingMode == .time
                    ? goalPeriod
                    : nil

            if item == nil,
               sourceExpense == nil,
               !isGift,
               createExpense {
                let expense = Expense(
                    title: normalizedName,
                    amountInCents:
                        acquisitionValueInCents,
                    date: acquiredAt,
                    category:
                        category.expenseCategory,
                    notes: normalizedNotes,
                    customSymbolName:
                        customSymbolName,
                    imageIdentifier:
                        finalImageIdentifier
                )
                modelContext.insert(expense)
                linkedExpense = expense
            } else if item == nil,
                      didChangeRepresentation,
                      let linkedExpense {
                linkedExpense.customSymbolName =
                    customSymbolName
                linkedExpense.imageIdentifier =
                    finalImageIdentifier
            }

            if let item {
                item.name = normalizedName
                item.acquisitionValueInCents =
                    acquisitionValueInCents
                item.acquiredAt = acquiredAt
                item.category = category
                item.notes = normalizedNotes
                item.isGift = isGift
                item.trackingMode =
                    trackingMode
                item.goalValueInCents =
                    goalValueInCents
                item.goalPeriod =
                    selectedGoalPeriod
                item.isFavorite = isFavorite

                if didChangeRepresentation {
                    item.customSymbolName =
                        customSymbolName
                    item.imageIdentifier =
                        finalImageIdentifier
                }
            } else {
                let newItem = TrackedItem(
                    name: normalizedName,
                    acquisitionValueInCents:
                        acquisitionValueInCents,
                    acquiredAt: acquiredAt,
                    category: category,
                    notes: normalizedNotes,
                    isGift: isGift,
                    trackingMode:
                        trackingMode,
                    goalValueInCents:
                        goalValueInCents,
                    goalPeriod:
                        selectedGoalPeriod,
                    isFavorite: isFavorite,
                    customSymbolName:
                        customSymbolName,
                    imageIdentifier:
                        finalImageIdentifier,
                    sourceExpenseID:
                        linkedExpense?.id
                )
                modelContext.insert(newItem)
            }

            try modelContext.save()

            for identifier
                in previousImageIdentifiers
                where identifier
                    != finalImageIdentifier {
                AppImageReferenceService
                    .deleteIfUnreferenced(
                        identifier: identifier,
                        in: modelContext
                    )
            }

            dismiss()
        } catch {
            modelContext.rollback()

            AppImageReferenceService
                .deleteIfUnreferenced(
                    identifier:
                        createdImageIdentifier,
                    in: modelContext
                )

            saveError = error.localizedDescription
            isSaving = false
        }
    }

    private func findLinkedExpense()
        throws -> Expense? {
        if let sourceExpense {
            return sourceExpense
        }

        guard let sourceExpenseID =
            item?.sourceExpenseID
        else {
            return nil
        }

        let descriptor =
            FetchDescriptor<Expense>()

        return try modelContext
            .fetch(descriptor)
            .first {
                $0.id == sourceExpenseID
            }
    }

    private func expenseIsAlreadyTracked(
        _ expenseID: UUID
    ) throws -> Bool {
        try TrackedItemLinkService.firstItem(
            linkedTo: expenseID,
            in: modelContext
        ) != nil
    }

    private static func itemCategory(
        for expenseCategory:
            ExpenseCategory
    ) -> ItemCategory {
        ItemCategory.allCases.first {
            $0.expenseCategory
                == expenseCategory
        } ?? .other
    }

    private static func parseAmount(
        _ text: String,
        locale: Locale
    ) -> Int? {
        let normalized =
            text.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard !normalized.isEmpty else {
            return nil
        }

        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal

        guard let number =
            formatter.number(from: normalized)
        else {
            return nil
        }

        let cents = (
            number.doubleValue * 100
        ).rounded()

        guard
            cents.isFinite,
            cents >= 0,
            cents < Double(Int.max)
        else {
            return nil
        }

        return Int(cents)
    }

    private static func amountInputText(
        from amountInCents: Int
    ) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(
            identifier: "pt_BR"
        )
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2

        let value =
            Double(amountInCents) / 100

        return formatter.string(
            from: NSNumber(value: value)
        ) ?? ""
    }
}

private enum TrackedItemFormError:
    LocalizedError {
    case expenseAlreadyTracked

    var errorDescription: String? {
        switch self {
        case .expenseAlreadyTracked:
            "Esta despesa já está sendo acompanhada como item."
        }
    }
}
