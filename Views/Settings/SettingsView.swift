import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

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

    @Query(
        sort: \TrackedItem.acquiredAt,
        order: .reverse
    )
    private var trackedItems: [TrackedItem]

    @AppStorage(AppPreferenceKeys.appearance)
    private var appearanceRawValue = AppAppearance.system.rawValue

    @AppStorage(AppPreferenceKeys.defaultCategory)
    private var defaultCategoryRawValue = ExpenseCategory.other.rawValue

    @AppStorage(AppPreferenceKeys.defaultRecurrence)
    private var defaultRecurrenceRawValue = FinancialRecurrence.once.rawValue

    @AppStorage(AppPreferenceKeys.cloudantGatewayURL)
    private var cloudantGatewayURL = CloudantStore.defaultGatewayURL

    private var appearance: AppAppearance {
        AppAppearance(rawValue: appearanceRawValue) ?? .system
    }

    private var defaultCategory: ExpenseCategory {
        ExpenseCategory(rawValue: defaultCategoryRawValue) ?? .other
    }

    private var defaultRecurrence: FinancialRecurrence {
        FinancialRecurrence(rawValue: defaultRecurrenceRawValue) ?? .once
    }

    private var appearanceSelection: Binding<AppAppearance> {
        Binding(
            get: { appearance },
            set: { appearanceRawValue = $0.rawValue }
        )
    }

    private var categorySelection: Binding<ExpenseCategory> {
        Binding(
            get: { defaultCategory },
            set: { defaultCategoryRawValue = $0.rawValue }
        )
    }

    private var recurrenceSelection: Binding<FinancialRecurrence> {
        Binding(
            get: { defaultRecurrence },
            set: { defaultRecurrenceRawValue = $0.rawValue }
        )
    }

    private var currentMonthExpenses: [Expense] {
        ExpenseSummary.expenses(
            from: expenses,
            in: .now
        )
        .filter {
            Calendar.current.compare(
                $0.date,
                to: Date.now,
                toGranularity: .day
            ) != .orderedDescending
        }
    }

    private var currentMonthTotalInCents: Int {
        ExpenseSummary.totalInCents(
            currentMonthExpenses
        )
    }

    private var currentMonthReceivedEntries:
        [IncomeEntry] {
        IncomeSummary.received(
            from: incomeEntries,
            in: .month,
            containing: .now
        )
    }

    private var currentMonthReceivedInCents:
        Int {
        IncomeSummary.totalInCents(
            currentMonthReceivedEntries
        )
    }

    private var currentMonthBalanceInCents: Int {
        currentMonthReceivedInCents
            - currentMonthTotalInCents
    }

    @Environment(\.modelContext) private var modelContext
    @State private var cloudantMessage: String?
    @State private var isReloadingCloudant = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(
                    alignment: .leading,
                    spacing: 18
                ) {
                    header
                    cloudantSummary
                    preferencesSection
                    cloudantSection
                    privacySection
                    aboutSection

                    Text(
                        "As preferências são salvas automaticamente."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 2)
                }
                .padding(20)
                .padding(.bottom, 12)
            }
            .background(
                AppStyle.background(colorScheme)
                    .ignoresSafeArea()
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(
                    placement: .topBarTrailing
                ) {
                    Button {
                        dismiss()
                    } label: {
                        Image(
                            systemName: "xmark.circle.fill"
                        )
                        .font(.title3)
                        .symbolRenderingMode(.hierarchical)
                    }
                    .accessibilityLabel(
                        "Fechar configurações"
                    )
                }
            }
        }
        .tint(
            AppStyle.accentForeground(colorScheme)
        )
        .preferredColorScheme(
            appearance.colorScheme
        )
    }

    private var header: some View {
        HStack(spacing: 13) {
            BrandLogo(
                variant: .main,
                size: 58
            )

            VStack(alignment: .leading, spacing: 4) {
                Text("Configurações")
                    .editorialTitle()

                Text("deixe o app do seu jeito")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.top, 8)
    }

    private var cloudantSummary: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Resumo Cloudant")
                        .font(.headline)

                    Text("Dados carregados do banco principal")
                        .font(.caption)
                        .foregroundStyle(
                            .white.opacity(0.82)
                        )
                }

                Spacer()

                Image(systemName: "iphone.gen3")
                    .font(.title3.bold())
                    .frame(width: 42, height: 42)
                    .background(
                        .white.opacity(0.16),
                        in: RoundedRectangle(
                            cornerRadius: 13,
                            style: .continuous
                        )
                    )
                    .accessibilityHidden(true)
            }

            Text(currentMonthBalanceInCents.currencyText)
                .font(
                    .system(
                        size: 36,
                        weight: .semibold,
                        design: .rounded
                    )
                )
                .minimumScaleFactor(0.7)
                .lineLimit(1)

            Text("saldo confirmado no mês atual")
                .font(.caption)
                .foregroundStyle(
                    .white.opacity(0.82)
                )

            Divider()
                .overlay(.white.opacity(0.25))

            HStack(spacing: 16) {
                summaryMetric(
                    value:
                        currentMonthReceivedInCents
                            .currencyText,
                    title: "recebido"
                )

                summaryMetric(
                    value:
                        currentMonthTotalInCents
                            .currencyText,
                    title: "gasto"
                )
            }

            HStack(spacing: 14) {
                Label(
                    "\(incomeEntries.count) entradas no total",
                    systemImage:
                        "arrow.down.circle.fill"
                )

                Label(
                    trackedItems.count == 1
                        ? "1 item no total"
                        : "\(trackedItems.count) itens no total",
                    systemImage: "shippingbox.fill"
                )
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white.opacity(0.88))
            .lineLimit(1)
            .minimumScaleFactor(0.75)
        }
        .foregroundStyle(.white)
        .padding(20)
        .background(
            (
                currentMonthBalanceInCents >= 0
                    ? AppStyle.mintStrong
                    : AppStyle.pinkStrong
            ).gradient,
            in: RoundedRectangle(
                cornerRadius: AppStyle.heroRadius,
                style: .continuous
            )
        )
        .shadow(
            color:
                (
                    currentMonthBalanceInCents >= 0
                        ? AppStyle.mint
                        : AppStyle.pinkStrong
                )
                .opacity(0.25),
            radius: 14,
            y: 8
        )
        .accessibilityElement(
            children: .combine
        )
    }

    private func summaryMetric(
        value: String,
        title: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
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
                .font(.caption2)
                .foregroundStyle(
                    .white.opacity(0.78)
                )
        }
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
    }

    private var preferencesSection: some View {
        settingsSection(
            title: "Preferências"
        ) {
            VStack(spacing: 0) {
                appearancePreference

                cardDivider

                categoryPreference

                cardDivider

                recurrencePreference
            }
        }
    }

    private var appearancePreference: some View {
        VStack(alignment: .leading, spacing: 13) {
            preferenceHeading(
                title: "Aparência",
                subtitle: "Tema usado no aplicativo",
                symbol: appearance.symbol
            )

            Picker(
                "Aparência",
                selection: appearanceSelection
            ) {
                ForEach(AppAppearance.allCases) { option in
                    Text(option.title)
                        .tag(option)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(.vertical, 4)
    }

    private var categoryPreference: some View {
        Menu {
            Picker(
                "Categoria padrão",
                selection: categorySelection
            ) {
                ForEach(ExpenseCategory.allCases) { category in
                    Label(
                        category.rawValue,
                        systemImage: category.symbol
                    )
                    .tag(category)
                }
            }
        } label: {
            preferenceMenuLabel(
                title: "Categoria padrão",
                subtitle: "Usada ao criar uma despesa",
                symbol: defaultCategory.symbol,
                value: defaultCategory.rawValue
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            "Categoria padrão, \(defaultCategory.rawValue)"
        )
    }

    private var recurrencePreference: some View {
        Menu {
            Picker(
                "Periodicidade padrão",
                selection: recurrenceSelection
            ) {
                ForEach(FinancialRecurrence.allCases) { recurrence in
                    Label(
                        recurrence.title,
                        systemImage: recurrence.symbol
                    )
                    .tag(recurrence)
                }
            }
        } label: {
            preferenceMenuLabel(
                title: "Periodicidade padrão",
                subtitle: "Frequência inicial de novos gastos",
                symbol: defaultRecurrence.symbol,
                value: defaultRecurrence.title
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            "Periodicidade padrão, \(defaultRecurrence.title)"
        )
    }

    private var cloudantSection: some View {
        settingsSection(
            title: "Cloudant"
        ) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 13) {
                    preferenceIcon(systemName: "network")

                    VStack(alignment: .leading, spacing: 3) {
                        Text("URL do gateway")
                            .font(.subheadline.weight(.semibold))

                        Text("Use o endereço do computador que executa o Node-RED no laboratório.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                TextField(
                    "http://192.168.0.10:1880",
                    text: $cloudantGatewayURL
                )
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textFieldStyle(.roundedBorder)
                .keyboardType(.URL)

                Button {
                    reloadCloudant()
                } label: {
                    Label(
                        isReloadingCloudant
                            ? "Carregando dados..."
                            : "Carregar dados do Cloudant",
                        systemImage: "arrow.triangle.2.circlepath"
                    )
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(AppStyle.mintStrong, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .disabled(isReloadingCloudant)

                if let msg = cloudantMessage {
                    Text(msg)
                        .font(.caption.bold())
                        .foregroundStyle(AppStyle.accentForeground(colorScheme))
                }
            }
        }
    }

    private var privacySection: some View {
        settingsSection(
            title: "Privacidade"
        ) {
            HStack(alignment: .top, spacing: 13) {
                preferenceIcon(
                    systemName: "lock.shield.fill"
                )

                VStack(alignment: .leading, spacing: 5) {
                    Text("Dados no Cloudant")
                        .font(.subheadline.weight(.semibold))

                    Text(
                        "Despesas, entradas, itens e usos ficam no Cloudant. Este aparelho mantém apenas uma cópia temporária para mostrar as telas."
                    )
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

    private func reloadCloudant() {
        isReloadingCloudant = true
        cloudantMessage = nil

        Task {
            defer { isReloadingCloudant = false }

            do {
                try await CloudantStore.shared.reload(
                    into: modelContext
                )
                cloudantMessage = "Dados carregados do Cloudant."
            } catch {
                cloudantMessage = error.localizedDescription
            }
        }
    }

    private var aboutSection: some View {
        settingsSection(
            title: "Aplicativo"
        ) {
            NavigationLink {
                AboutView()
            } label: {
                HStack(spacing: 13) {
                    preferenceIcon(
                        systemName: "info.circle.fill"
                    )

                    VStack(
                        alignment: .leading,
                        spacing: 3
                    ) {
                        Text("Sobre")
                            .font(
                                .subheadline.weight(
                                    .semibold
                                )
                            )

                        Text(
                            "Versão, propósito e privacidade"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(
                        systemName: "chevron.right"
                    )
                    .font(.caption.bold())
                    .foregroundStyle(.tertiary)
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(
                "Abre informações sobre o aplicativo"
            )
        }
    }

    private func settingsSection<Content: View>(
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

    private func preferenceHeading(
        title: String,
        subtitle: String,
        symbol: String
    ) -> some View {
        HStack(spacing: 13) {
            preferenceIcon(
                systemName: symbol
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(
                        .subheadline.weight(
                            .semibold
                        )
                    )

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func preferenceMenuLabel(
        title: String,
        subtitle: String,
        symbol: String,
        value: String
    ) -> some View {
        HStack(spacing: 13) {
            preferenceIcon(
                systemName: symbol
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(
                        .subheadline.weight(
                            .semibold
                        )
                    )

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            HStack(spacing: 5) {
                Text(value)
                    .font(.subheadline)
                    .lineLimit(1)

                Image(
                    systemName: "chevron.up.chevron.down"
                )
                .font(.caption2.bold())
            }
            .foregroundStyle(
                AppStyle.accentForeground(
                    colorScheme
                )
            )
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }

    private func preferenceIcon(
        systemName: String
    ) -> some View {
        Image(systemName: systemName)
            .font(.subheadline.bold())
            .foregroundStyle(
                AppStyle.accentForeground(
                    colorScheme
                )
            )
            .accessibilityHidden(true)
            .frame(width: 38, height: 38)
            .background(
                AppStyle.mint.opacity(0.12),
                in: RoundedRectangle(
                    cornerRadius: 11,
                    style: .continuous
                )
            )
    }

    private var cardDivider: some View {
        Divider()
            .padding(.leading, 51)
            .padding(.vertical, 14)
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

    return SettingsView()
        .modelContainer(container)
}
