import SwiftData
import SwiftUI

struct ExpenseFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @AppStorage(AppPreferenceKeys.defaultCategory)
    private var defaultCategoryRawValue =
        ExpenseCategory.other.rawValue

    @AppStorage(AppPreferenceKeys.defaultRecurrence)
    private var defaultRecurrenceRawValue =
        FinancialRecurrence.once.rawValue

    @State private var title: String
    @State private var amountText: String
    @State private var date: Date
    @State private var category = ExpenseCategory.other
    @State private var notes: String
    @State private var recurrence = FinancialRecurrence.once
    @State private var recurrenceEndDate = Date()
    @State private var customSymbolName: String?
    @State private var imageData: Data?
    @State private var isProcessingPhoto = false
    @State private var didApplyDefaults = false
    @State private var isSaving = false
    @State private var saveError: String?

    init(
        initialTitle: String = "",
        initialAmountInCents: Int? = nil,
        initialDate: Date = Date(),
        initialNotes: String = ""
    ) {
        _title = State(initialValue: initialTitle)
        _date = State(initialValue: initialDate)
        _notes = State(initialValue: initialNotes)

        if let cents = initialAmountInCents, cents > 0 {
            _amountText = State(initialValue: CurrencyFormatter.amountInputText(from: cents))
        } else {
            _amountText = State(initialValue: "")
        }
    }

    private let locale = Locale(identifier: "pt_BR")

    private var amountInCents: Int? {
        CurrencyFormatter.parseAmount(amountText)
    }

    private var normalizedTitle: String {
        title.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
    }

    private var canSave: Bool {
        !normalizedTitle.isEmpty
            && (amountInCents ?? 0) > 0
            && !recurrenceDates.isEmpty
            && !isProcessingPhoto
            && !isSaving
    }

    private var recurrenceDates: [Date] {
        recurrence.occurrenceDates(
            from: date,
            through: recurrence.isRecurring
                ? recurrenceEndDate
                : nil
        )
    }

    private var recurrenceSelection: Binding<FinancialRecurrence> {
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
                expenseSection
                recurrenceSection
                representationSection
                notesSection
            }
            .navigationTitle("Novo gasto")
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
            .onAppear {
                applyDefaultsIfNeeded()
            }
            .onChange(of: date) { _, _ in
                updateRecurrenceEndDate(
                    useSuggestion: false
                )
            }
            .alert(
                "Não foi possível salvar o gasto",
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

    private var expenseSection: some View {
        Section("Gasto") {
            TextField(
                "Descrição",
                text: $title
            )
            .textInputAutocapitalization(.sentences)

            TextField(
                "Valor",
                text: $amountText
            )
            .keyboardType(.decimalPad)

            DatePicker(
                "Data inicial",
                selection: $date,
                displayedComponents: .date
            )

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
        }
    }

    private var recurrenceSection: some View {
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
                    selection: $recurrenceEndDate,
                    in: recurrence.minimumEndDate(
                        from: date
                    )...recurrence.maximumEndDate(
                        from: date
                    ),
                    displayedComponents: .date
                )

                Label(
                    recurrencePreviewText,
                    systemImage: "calendar.badge.checkmark"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        } header: {
            Text("Repetição")
        } footer: {
            if recurrence.isRecurring {
                Text(
                    "Cada data será salva como um lançamento da mesma série."
                )
            }
        }
    }

    private var representationSection: some View {
        Section("Representação") {
            ExpenseVisualPicker(
                customSymbolName: $customSymbolName,
                imageData: $imageData,
                isProcessingPhoto:
                    $isProcessingPhoto,
                category: category
            )
            .padding(.vertical, 4)
        }
    }

    private var notesSection: some View {
        Section("Observação") {
            TextField(
                "Observação opcional",
                text: $notes,
                axis: .vertical
            )
            .lineLimit(3...6)
        }
    }

    private var recurrencePreviewText: String {
        let count = recurrenceDates.count
        let lastDate = recurrenceDates.last
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

    private func applyDefaultsIfNeeded() {
        guard !didApplyDefaults else {
            return
        }

        didApplyDefaults = true
        category = ExpenseCategory(
            rawValue: defaultCategoryRawValue
        ) ?? .other
        recurrence = FinancialRecurrence(
            rawValue: defaultRecurrenceRawValue
        ) ?? .once

        updateRecurrenceEndDate(
            useSuggestion: true
        )
    }

    private func updateRecurrenceEndDate(
        useSuggestion: Bool
    ) {
        guard recurrence.isRecurring else {
            recurrenceEndDate = date
            return
        }

        let minimumDate = recurrence.minimumEndDate(
            from: date
        )
        let maximumDate = recurrence.maximumEndDate(
            from: date
        )

        if useSuggestion {
            recurrenceEndDate =
                recurrence.suggestedEndDate(
                    from: date
                )
            return
        }

        if recurrenceEndDate < minimumDate {
            recurrenceEndDate = minimumDate
        } else if recurrenceEndDate > maximumDate {
            recurrenceEndDate = maximumDate
        }
    }

    private func save() {
        guard let amountInCents,
              amountInCents > 0,
              !normalizedTitle.isEmpty,
              !recurrenceDates.isEmpty,
              !isProcessingPhoto
        else {
            return
        }

        isSaving = true
        let normalizedNotes =
            notes.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
        let seriesID = recurrence.isRecurring
            ? UUID()
            : nil
        let endDate = recurrence.isRecurring
            ? recurrenceEndDate
            : nil

        Task {
            var savedImageIdentifier: String?
            var remoteExpenses: [Expense] = []

            do {
                if let imageData {
                    savedImageIdentifier =
                        try ExpenseImageStore.shared.save(
                            imageData
                        )
                }

                for occurrenceDate in recurrenceDates {
                    let expense = Expense(
                        title: normalizedTitle,
                        amountInCents: amountInCents,
                        date: occurrenceDate,
                        category: category,
                        notes: normalizedNotes,
                        recurrence: recurrence,
                        seriesID: seriesID,
                        endDate: endDate,
                        customSymbolName: customSymbolName,
                        imageIdentifier:
                            savedImageIdentifier
                    )

                    try await CloudantStore.shared.save(expense)
                    remoteExpenses.append(expense)
                    modelContext.insert(expense)
                }

                try modelContext.save()
                dismiss()
            } catch {
                for expense in remoteExpenses {
                    try? await CloudantStore.shared.delete(expense)
                }
                modelContext.rollback()
                ExpenseImageStore.shared.delete(
                    savedImageIdentifier
                )
                isSaving = false
                saveError = error.localizedDescription
            }
        }
    }
}
