import SwiftData
import SwiftUI

struct RootView: View {
    private enum ActiveSheet: String, Identifiable {
        case newExpense
        case scanPhoto
        case scanQRCode
        case prefilledExpense
        case newIncome
        case newItem
        case settings

        var id: String {
            rawValue
        }
    }

    @AppStorage(AppPreferenceKeys.appearance)
    private var appearanceRawValue =
        AppAppearance.system.rawValue

    @Environment(\.colorScheme) private var colorScheme

    @State private var selectedTab: AppTab = .expenses
    @State private var activeSheet: ActiveSheet?
    @State private var showingAddOptions = false

    @State private var prefilledTitle = ""
    @State private var prefilledAmount: Int?
    @State private var prefilledDate = Date()
    @State private var prefilledNotes = ""

    private var appearance: AppAppearance {
        AppAppearance(
            rawValue: appearanceRawValue
        ) ?? .system
    }

    var body: some View {
        ZStack {
            ExpenseListView {
                activeSheet = .settings
            }
            .opacity(
                selectedTab == .expenses
                    ? 1
                    : 0
            )
            .allowsHitTesting(
                selectedTab == .expenses
            )
            .accessibilityHidden(
                selectedTab != .expenses
            )

            TrackedItemListView {
                activeSheet = .settings
            }
            .opacity(
                selectedTab == .items
                    ? 1
                    : 0
            )
            .allowsHitTesting(
                selectedTab == .items
            )
            .accessibilityHidden(
                selectedTab != .items
            )

            IncomeListView {
                activeSheet = .settings
            }
            .opacity(
                selectedTab == .income
                    ? 1
                    : 0
            )
            .allowsHitTesting(
                selectedTab == .income
            )
            .accessibilityHidden(
                selectedTab != .income
            )

            DashboardView {
                activeSheet = .settings
            }
            .opacity(
                selectedTab == .dashboard
                    ? 1
                    : 0
            )
            .allowsHitTesting(
                selectedTab == .dashboard
            )
            .accessibilityHidden(
                selectedTab != .dashboard
            )
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            CustomTabBar(
                selectedTab: $selectedTab,
                onAdd: {
                    showingAddOptions = true
                }
            )
        }
        .tint(
            AppStyle.accentForeground(
                colorScheme
            )
        )
        .preferredColorScheme(
            appearance.colorScheme
        )
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .newExpense:
                ExpenseFormView()

            case .scanPhoto:
                ReceiptScannerView(scanMode: .ocrPhoto) { title, amount, date, items in
                    prefilledTitle = title
                    prefilledAmount = amount
                    prefilledDate = date
                    prefilledNotes = items.map { "\($0.name): \($0.amountInCents.currencyText)" }.joined(separator: "\n")
                    activeSheet = .prefilledExpense
                }

            case .scanQRCode:
                ReceiptScannerView(scanMode: .qrCode) { title, amount, date, items in
                    prefilledTitle = title
                    prefilledAmount = amount
                    prefilledDate = date
                    prefilledNotes = items.map { "\($0.name): \($0.amountInCents.currencyText)" }.joined(separator: "\n")
                    activeSheet = .prefilledExpense
                }

            case .prefilledExpense:
                ExpenseFormView(
                    initialTitle: prefilledTitle,
                    initialAmountInCents: prefilledAmount,
                    initialDate: prefilledDate,
                    initialNotes: prefilledNotes
                )

            case .newIncome:
                IncomeFormView()

            case .newItem:
                TrackedItemFormView()

            case .settings:
                SettingsView()
            }
        }
        .confirmationDialog(
            "O que você quer registrar?",
            isPresented: $showingAddOptions,
            titleVisibility: .visible
        ) {
            Button("Nova despesa manual") {
                activeSheet = .newExpense
            }

            Button("Escanear Nota por Foto (OCR)") {
                activeSheet = .scanPhoto
            }

            Button("Escanear QR Code do Cupom Fiscal") {
                activeSheet = .scanQRCode
            }

            Button("Nova entrada ou renda") {
                activeSheet = .newIncome
            }

            Button("Novo item para acompanhar o uso") {
                activeSheet = .newItem
            }

            Button("Cancelar", role: .cancel) {}
        } message: {
            Text(
                "Escolha o método de lançamento: manual, leitura de recibo por foto ou scanner de QR Code de cupom fiscal."
            )
        }
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

    return RootView()
        .modelContainer(container)
}
