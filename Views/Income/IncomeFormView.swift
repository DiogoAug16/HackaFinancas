import SwiftData
import SwiftUI

struct IncomeFormView: View {
    private enum EditScope: Equatable {
        case single
        case future
        case series
    }

    @Environment(\.dismiss)
    private var dismiss
    @Environment(\.modelContext)
    private var modelContext

    private let entry: IncomeEntry?

    @State private var title: String
    @State private var amountText: String
    @State private var date: Date
    @State private var category: IncomeCategory
    @State private var notes: String
    @State private var recurrence: FinancialRecurrence
    @State private var recurrenceEndDate: Date
    @State private var isReceived: Bool
    @State private var receivedAt: Date
    @State private var isSaving = false
    @State private var saveError: String?
    @State private var showingEditScope = false

    private let locale =
        Locale(identifier: "pt_BR")

    init(entry: IncomeEntry? = nil) {
        self.entry = entry

        _title = State(
            initialValue: entry?.title ?? ""
        )
        _amountText = State(
            initialValue: entry.map {
                CurrencyFormatter.amountInputText(
                    from: $0.amountInCents
                )
            } ?? ""
        )
        _date = State(
            initialValue: entry?.date ?? .now
        )
        _category = State(
            initialValue:
                entry?.category ?? .other
        )
        _notes = State(
            initialValue: entry?.notes ?? ""
        )
        _recurrence = State(
            initialValue:
                entry?.recurrence ?? .once
        )

        let initialDate = entry?.date ?? .now
        let initialRecurrence =
            entry?.recurrence ?? .once
        _recurrenceEndDate = State(
            initialValue:
                entry?.endDate
                ?? initialRecurrence
                    .suggestedEndDate(
                        from: initialDate
                    )
        )
        _isReceived = State(
            initialValue:
                entry?.isReceived ?? false
        )
        _receivedAt = State(
            initialValue:
                entry?.receivedAt ?? .now
        )
    }

    private var normalizedTitle: String {
        title.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
    }

    private var amountInCents: Int? {
        CurrencyFormatter.parseAmount(amountText)
    }

    private var recurrenceDates: [Date] {
        if entry != nil {
            return [date]
        }

        return recurrence.occurrenceDates(
            from: date,
            through: recurrence.isRecurring
                ? recurrenceEndDate
                : nil,
            maxCount:
                RecurrenceService
                    .defaultOccurrenceLimit
        )
    }

    private var canSave: Bool {
        !normalizedTitle.isEmpty
            && (amountInCents ?? 0) > 0
            && !recurrenceDates.isEmpty
            && isDateWithinSeries
            && !isSaving
    }

    private var isDateWithinSeries: Bool {
        guard entry?.recurrence.isRecurring == true,
              let endDate = entry?.endDate
        else {
            return true
        }

        return Calendar.current.compare(
            date,
            to: endDate,
            toGranularity: .day
        ) != .orderedDescending
    }

    private var recurrenceSelection:
        Binding<FinancialRecurrence> {
        Binding(
            get: {
                recurrence
            },
            set: { newValue in
                recurrence = newValue
                updateRecurrenceEndDate(
                    useSuggestion: true
                )
            }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                entrySection
                statusSection
                recurrenceSection
                notesSection
            }
            .navigationTitle(
                entry == nil
                    ? "Nova entrada"
                    : "Editar entrada"
            )
            .navigationBarTitleDisplayMode(.inline)
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
                        requestSave()
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
            .onChange(
                of: date
            ) { oldDate, newDate in
                updateRecurrenceEndDate(
                    useSuggestion: false
                )

                guard entry == nil,
                      isReceived,
                      Calendar.current.isDate(
                        receivedAt,
                        inSameDayAs:
                            suggestedReceivedDate(
                                for: oldDate
                            )
                      )
                else {
                    return
                }

                receivedAt =
                    suggestedReceivedDate(
                        for: newDate
                    )
            }
            .onChange(of: isReceived) {
                _, newValue in
                guard newValue,
                      entry?.receivedAt == nil
                else {
                    return
                }

                receivedAt =
                    suggestedReceivedDate(
                        for: date
                    )
            }
            .alert(
                "Não foi possível salvar a entrada",
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
            .confirmationDialog(
                "Aplicar alterações à recorrência?",
                isPresented: $showingEditScope,
                titleVisibility: .visible
            ) {
                Button("Somente esta entrada") {
                    save(scope: .single)
                }

                Button("Esta e as próximas") {
                    save(scope: .future)
                }

                Button("Série inteira") {
                    save(scope: .series)
                }

                Button("Cancelar", role: .cancel) {}
            } message: {
                Text(
                    "Título, valor, categoria e observação seguem o alcance escolhido. Data e situação mudam somente nesta entrada."
                )
            }
        }
    }

    private var entrySection: some View {
        Section("Entrada") {
            TextField(
                "Descrição",
                text: $title
            )
            .textInputAutocapitalization(
                .sentences
            )

            TextField(
                "Valor",
                text: $amountText
            )
            .keyboardType(.decimalPad)

            DatePicker(
                isReceived
                    ? "Data de referência"
                    : "Previsto para",
                selection: $date,
                displayedComponents: .date
            )

            Picker(
                "Categoria",
                selection: $category
            ) {
                ForEach(
                    IncomeCategory.allCases
                ) { category in
                    Label(
                        category.title,
                        systemImage: category.symbol
                    )
                    .tag(category)
                }
            }
        }
    }

    private var statusSection: some View {
        Section {
            Toggle(
                "Valor já recebido",
                isOn: $isReceived
            )

            if isReceived {
                DatePicker(
                    "Recebido em",
                    selection: $receivedAt,
                    in: ...Date.now,
                    displayedComponents: .date
                )
            } else {
                Label(
                    "Esta entrada ficará como a receber.",
                    systemImage: "clock"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        } header: {
            Text("Situação")
        } footer: {
            if entry == nil,
               recurrence.isRecurring,
               isReceived {
                Text(
                    "Somente a primeira ocorrência será marcada como recebida. As próximas ficarão a receber."
                )
            }
        }
    }

    @ViewBuilder
    private var recurrenceSection: some View {
        if entry == nil {
            Section {
                Picker(
                    "Periodicidade",
                    selection: recurrenceSelection
                ) {
                    ForEach(
                        FinancialRecurrence.allCases
                    ) { option in
                        Label(
                            option.title,
                            systemImage: option.symbol
                        )
                        .tag(option)
                    }
                }

                if recurrence.isRecurring {
                    DatePicker(
                        "Repetir até",
                        selection:
                            $recurrenceEndDate,
                        in: recurrence
                            .minimumEndDate(
                                from: date
                            )...recurrence
                            .maximumEndDate(
                                from: date
                            ),
                        displayedComponents: .date
                    )

                    Label(
                        recurrencePreviewText,
                        systemImage:
                            "calendar.badge.checkmark"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            } header: {
                Text("Periodicidade")
            } footer: {
                if recurrence.isRecurring {
                    Text(
                        "Cada data será salva como uma entrada da mesma série."
                    )
                }
            }
        } else {
            Section {
                Label(
                    entry?.recurrence.summaryText
                        ?? FinancialRecurrence.once
                            .summaryText,
                    systemImage:
                        entry?.recurrence.symbol
                        ?? FinancialRecurrence.once.symbol
                )
            } header: {
                Text("Periodicidade")
            } footer: {
                if entry?.seriesID != nil {
                    if isDateWithinSeries {
                        Text(
                            "Ao salvar, você poderá alterar somente esta entrada, esta e as próximas ou a série inteira."
                        )
                    } else {
                        Text(
                            "A data desta ocorrência não pode ficar depois do fim da série."
                        )
                        .foregroundStyle(.red)
                    }
                }
            }
        }
    }

    private var notesSection: some View {
        Section("Observação") {
            TextField(
                "Origem, referência ou observação...",
                text: $notes,
                axis: .vertical
            )
            .lineLimit(3...6)
        }
    }

    private var recurrencePreviewText: String {
        let count = recurrenceDates.count
        let lastDate =
            recurrenceDates.last
            ?? recurrenceEndDate
        let formattedDate = lastDate.formatted(
            .dateTime
                .day()
                .month(.abbreviated)
                .year()
                .locale(locale)
        )

        if count == 1 {
            return "1 lançamento até \(formattedDate)"
        }

        return "\(count) lançamentos até \(formattedDate)"
    }

    private func updateRecurrenceEndDate(
        useSuggestion: Bool
    ) {
        guard entry == nil else {
            return
        }

        guard recurrence.isRecurring else {
            recurrenceEndDate = date
            return
        }

        let minimumDate =
            recurrence.minimumEndDate(
                from: date
            )
        let maximumDate =
            recurrence.maximumEndDate(
                from: date
            )

        if useSuggestion {
            recurrenceEndDate =
                recurrence.suggestedEndDate(
                    from: date
                )
        } else if recurrenceEndDate
            < minimumDate {
            recurrenceEndDate = minimumDate
        } else if recurrenceEndDate
            > maximumDate {
            recurrenceEndDate = maximumDate
        }
    }

    private func suggestedReceivedDate(
        for referenceDate: Date
    ) -> Date {
        min(referenceDate, Date.now)
    }

    private func requestSave() {
        guard canSave else {
            return
        }

        if entry?.seriesID != nil {
            showingEditScope = true
        } else {
            save(scope: .single)
        }
    }

    private func save(
        scope: EditScope
    ) {
        guard canSave,
              let amountInCents
        else {
            return
        }

        isSaving = true
        let normalizedNotes =
            notes.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        Task {
            do {
                if let entry {
                    let originalDate = entry.date
                    let targetEntries =
                        try entriesToEdit(
                            scope: scope,
                            originalDate: originalDate
                        )

                    for targetEntry in targetEntries {
                        targetEntry.title =
                            normalizedTitle
                        targetEntry.amountInCents =
                            amountInCents
                        targetEntry.category = category
                        targetEntry.notes =
                            normalizedNotes

                        if targetEntry.id == entry.id {
                            targetEntry.date = date
                            targetEntry.receivedAt =
                                isReceived
                                ? receivedAt
                                : nil
                        }

                        try await CloudantStore.shared.save(
                            targetEntry
                        )
                    }
                } else {
                    let seriesID =
                        recurrence.isRecurring
                        ? UUID()
                        : nil
                    let endDate =
                        recurrence.isRecurring
                        ? recurrenceEndDate
                        : nil

                    for (
                        index,
                        occurrenceDate
                    ) in recurrenceDates.enumerated() {
                        let occurrenceReceivedAt =
                            isReceived && index == 0
                            ? receivedAt
                            : nil
                        let newEntry = IncomeEntry(
                            title: normalizedTitle,
                            amountInCents:
                                amountInCents,
                            date: occurrenceDate,
                            category: category,
                            notes: normalizedNotes,
                            recurrence: recurrence,
                            seriesID: seriesID,
                            endDate: endDate,
                            receivedAt:
                                occurrenceReceivedAt
                        )

                        try await CloudantStore.shared.save(
                            newEntry
                        )
                        modelContext.insert(newEntry)
                    }
                }

                try modelContext.save()
                dismiss()
            } catch {
                modelContext.rollback()
                isSaving = false
                saveError =
                    error.localizedDescription
            }
        }
    }

    private func entriesToEdit(
        scope: EditScope,
        originalDate: Date
    ) throws -> [IncomeEntry] {
        guard scope != .single,
              let entry,
              let seriesID = entry.seriesID
        else {
            return entry.map { [$0] } ?? []
        }

        let descriptor =
            FetchDescriptor<IncomeEntry>()
        let seriesEntries =
            try modelContext
                .fetch(descriptor)
                .filter {
                    $0.seriesID == seriesID
                }

        switch scope {
        case .single:
            return [entry]

        case .future:
            return seriesEntries.filter {
                $0.date >= originalDate
            }

        case .series:
            return seriesEntries
        }
    }
}
