import Foundation
import SwiftData

enum AppImageReferenceService {
    static func deleteIfUnreferenced(
        identifier: String?,
        in modelContext: ModelContext
    ) {
        guard
            let identifier,
            !identifier.isEmpty
        else {
            return
        }

        guard
            let expenses = try? modelContext.fetch(
                FetchDescriptor<Expense>()
            ),
            !expenses.contains(
                where: {
                    $0.imageIdentifier
                        == identifier
                }
            )
        else {
            return
        }

        guard
            let items = try? modelContext.fetch(
                FetchDescriptor<TrackedItem>()
            ),
            !items.contains(
                where: {
                    $0.imageIdentifier
                        == identifier
                }
            )
        else {
            return
        }

        ExpenseImageStore.shared.delete(identifier)
    }
}
