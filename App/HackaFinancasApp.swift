import SwiftData
import SwiftUI

@main
struct HackaFinancasApp: App {
    private let modelContainer: ModelContainer = {
        do {
            return try ModelContainer(
                for:
                    Expense.self,
                    IncomeEntry.self,
                    TrackedItem.self,
                    UsageRecord.self
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
                .onAppear {
                    seedIfEmpty()
                }
        }
        .modelContainer(modelContainer)
    }

    private func seedIfEmpty() {
        let context = modelContainer.mainContext
        let fetchDescriptor = FetchDescriptor<Expense>()
        if (try? context.fetchCount(fetchDescriptor)) == 0 {
            DatabaseSeeder.shared.seedSampleData(modelContext: context)
        }
    }
}
