import SwiftData
import SwiftUI

struct RegisterUsageView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext)
    private var modelContext

    let item: TrackedItem

    @State private var usedAt = Date()
    @State private var notes = ""
    @State private var isSaving = false
    @State private var saveError: String?

    private var normalizedNotes: String {
        notes.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
    }

    private var latestAllowedDate: Date {
        min(
            item.retiredAt ?? .now,
            .now
        )
    }

    private var canSave: Bool {
        let calendar = Calendar.current

        return !isSaving
            && calendar.compare(
                usedAt,
                to: item.acquiredAt,
                toGranularity: .day
            ) != .orderedAscending
            && calendar.compare(
                usedAt,
                to: latestAllowedDate,
                toGranularity: .day
            ) != .orderedDescending
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 13) {
                        AppVisual(
                            item: item,
                            size: 50,
                            cornerRadius: 14
                        )

                        VStack(
                            alignment: .leading,
                            spacing: 4
                        ) {
                            Text(item.name)
                                .font(.headline)

                            Text(
                                usageCountDescription
                            )
                            .font(.caption)
                            .foregroundStyle(
                                .secondary
                            )
                        }
                    }
                }

                Section {
                    DatePicker(
                        "Data do uso",
                        selection: $usedAt,
                        displayedComponents: .date
                    )

                    TextField(
                        "Como ou onde você usou?",
                        text: $notes,
                        axis: .vertical
                    )
                    .lineLimit(2...5)
                } header: {
                    Text("Novo uso")
                } footer: {
                    Text(
                        "A anotação é opcional. Cada registro melhora o cálculo de custo por uso."
                    )
                }

                if !canSave && !isSaving {
                    Label(
                        "A data precisa estar entre a aquisição e o encerramento do item.",
                        systemImage:
                            "exclamationmark.triangle.fill"
                    )
                    .font(.caption)
                    .foregroundStyle(.orange)
                }
            }
            .navigationTitle("Registrar uso")
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
                "Não foi possível registrar o uso",
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

    private var usageCountDescription: String {
        if item.usageCount == 0 {
            return "Este será o primeiro uso"
        }

        if item.usageCount == 1 {
            return "1 uso registrado"
        }

        return "\(item.usageCount) usos registrados"
    }

    private func save() {
        guard canSave else {
            return
        }

        isSaving = true

        let usage = UsageRecord(
            usedAt: usedAt,
            notes: normalizedNotes,
            item: item
        )
        modelContext.insert(usage)

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
