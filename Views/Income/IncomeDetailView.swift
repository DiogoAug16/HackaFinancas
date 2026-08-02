import SwiftData
import SwiftUI

struct IncomeDetailView: View {
    @Environment(\.modelContext)
    private var modelContext
    @Environment(\.dismiss)
    private var dismiss
    @Environment(\.colorScheme)
    private var colorScheme

    let entry: IncomeEntry

    @State private var showingEditForm = false
    @State private var showingDeleteConfirmation =
        false
    @State private var operationError: String?

    private let locale =
        Locale(identifier: "pt_BR")

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                heroCard
                informationSection

                if !entry.notes.isEmpty {
                    notesSection
                }

                actionsSection
            }
            .padding(20)
            .padding(.bottom, 24)
        }
        .background(
            AppStyle.background(colorScheme)
                .ignoresSafeArea()
        )
        .navigationTitle("Detalhes")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(
                placement: .topBarTrailing
            ) {
                Button("Editar") {
                    showingEditForm = true
                }
            }
        }
        .sheet(
            isPresented: $showingEditForm
        ) {
            IncomeFormView(entry: entry)
        }
        .confirmationDialog(
            "Excluir esta entrada?",
            isPresented:
                $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            if entry.seriesID == nil {
                Button(
                    "Excluir entrada",
                    role: .destructive
                ) {
                    deleteEntry()
                }
            } else {
                Button(
                    "Excluir somente esta ocorrência",
                    role: .destructive
                ) {
                    deleteEntry()
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
                entry.seriesID == nil
                    ? "Essa ação não poderá ser desfeita."
                    : "Você pode remover apenas esta data ou todos os lançamentos da série."
            )
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

    private var heroCard: some View {
        VStack(spacing: 13) {
            Image(systemName: entry.category.symbol)
                .font(
                    .system(
                        size: 28,
                        weight: .semibold
                    )
                )
                .foregroundStyle(
                    AppStyle.accentForeground(
                        colorScheme
                    )
                )
                .frame(width: 76, height: 76)
                .background(
                    AppStyle.mint.opacity(0.12),
                    in: RoundedRectangle(
                        cornerRadius: 22,
                        style: .continuous
                    )
                )
                .accessibilityHidden(true)

            Text(entry.title)
                .font(
                    .system(
                        .title2,
                        design: .rounded,
                        weight: .bold
                    )
                )
                .multilineTextAlignment(.center)

            Text(entry.amountInCents.currencyText)
                .font(
                    .system(
                        .largeTitle,
                        design: .rounded,
                        weight: .bold
                    )
                )
                .foregroundStyle(
                    AppStyle.accentForeground(
                        colorScheme
                    )
                )
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Label(
                entry.isReceived
                    ? "Recebido"
                    : "A receber",
                systemImage: entry.isReceived
                    ? "checkmark.circle.fill"
                    : "clock.fill"
            )
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(
                entry.isReceived
                    ? AppStyle.accentForeground(
                        colorScheme
                    )
                    : Color.secondary
            )
        }
        .frame(maxWidth: .infinity)
        .appCard(
            colorScheme: colorScheme,
            padding: 22,
            cornerRadius: AppStyle.heroRadius
        )
    }

    private var informationSection: some View {
        sectionCard(title: "Informações") {
            VStack(spacing: 0) {
                informationRow(
                    title: "Categoria",
                    value: entry.category.title,
                    symbol: entry.category.symbol
                )

                rowDivider

                informationRow(
                    title: entry.isReceived
                        ? "Data de referência"
                        : "Previsto para",
                    value: fullDateText(entry.date),
                    symbol: "calendar"
                )

                rowDivider

                informationRow(
                    title: entry.isReceived
                        ? "Recebido em"
                        : "Situação",
                    value:
                        receivedInformationText,
                    symbol: entry.isReceived
                        ? "checkmark.circle.fill"
                        : "clock.fill"
                )

                rowDivider

                informationRow(
                    title: "Periodicidade",
                    value:
                        recurrenceInformationText,
                    symbol:
                        entry.recurrence.symbol
                )
            }
        }
    }

    private var notesSection: some View {
        sectionCard(title: "Observação") {
            Text(entry.notes)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(
                    maxWidth: .infinity,
                    alignment: .leading
                )
        }
    }

    private var actionsSection: some View {
        VStack(spacing: 12) {
            Button {
                toggleReceivedStatus()
            } label: {
                Label(
                    entry.isReceived
                        ? "Marcar como a receber"
                        : "Marcar como recebido hoje",
                    systemImage: entry.isReceived
                        ? "clock.arrow.circlepath"
                        : "checkmark.circle.fill"
                )
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    AppStyle.mintStrong,
                    in: RoundedRectangle(
                        cornerRadius:
                            AppStyle.controlRadius,
                        style: .continuous
                    )
                )
            }
            .buttonStyle(.plain)

            Button(role: .destructive) {
                showingDeleteConfirmation = true
            } label: {
                Label(
                    entry.seriesID == nil
                        ? "Excluir entrada"
                        : "Excluir ocorrência ou série",
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

            Spacer(minLength: 8)
        }
        .frame(minHeight: 44)
    }

    private var rowDivider: some View {
        Divider()
            .padding(.leading, 40)
            .padding(.vertical, 8)
    }

    private var receivedInformationText:
        String {
        guard let receivedAt =
            entry.receivedAt
        else {
            return "A receber"
        }

        return fullDateText(receivedAt)
    }

    private var recurrenceInformationText:
        String {
        guard entry.recurrence.isRecurring,
              let endDate = entry.endDate
        else {
            return entry.recurrence.summaryText
        }

        return "\(entry.recurrence.shortTitle), até \(fullDateText(endDate))"
    }

    private func fullDateText(
        _ date: Date
    ) -> String {
        date.formatted(
            .dateTime
                .day()
                .month(.wide)
                .year()
                .locale(locale)
        )
    }

    private func toggleReceivedStatus() {
        entry.receivedAt = entry.isReceived
            ? nil
            : .now

        Task {
            do {
                try await CloudantStore.shared.save(entry)
                try modelContext.save()
            } catch {
                modelContext.rollback()
                operationError = error.localizedDescription
            }
        }
    }

    private func deleteEntry() {
        Task {
            do {
                try await CloudantStore.shared.delete(entry)
                modelContext.delete(entry)
                try modelContext.save()
                dismiss()
            } catch {
                modelContext.rollback()
                operationError = error.localizedDescription
            }
        }
    }

    private func deleteSeries() {
        guard let seriesID = entry.seriesID else {
            deleteEntry()
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
                dismiss()
            } catch {
                modelContext.rollback()
                operationError = error.localizedDescription
            }
        }
    }
}
