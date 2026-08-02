import SwiftData
import SwiftUI

@main
struct HackaFinancasApp: App {
    private let modelContainer: ModelContainer = {
        do {
            let configuration = ModelConfiguration(
                isStoredInMemoryOnly: true
            )
            return try ModelContainer(
                for:
                    Expense.self,
                    IncomeEntry.self,
                    TrackedItem.self,
                    UsageRecord.self,
                configurations: configuration
            )
        } catch {
            fatalError(
                "Não foi possível iniciar o banco local: \(error)"
            )
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .task {
                    try? await CloudantStore.shared.reload(
                        into: modelContainer.mainContext
                    )
                }
        }
        .modelContainer(modelContainer)
    }
}
