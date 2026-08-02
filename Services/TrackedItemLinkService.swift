import Foundation
import SwiftData

enum TrackedItemLinkService {
    static func firstItem(
        linkedTo expenseID: UUID,
        in modelContext: ModelContext
    ) throws -> TrackedItem? {
        let descriptor =
            FetchDescriptor<TrackedItem>()

        return try modelContext
            .fetch(descriptor)
            .first {
                $0.sourceExpenseID == expenseID
            }
    }

    static func unlinkItems(
        linkedTo expenseIDs: Set<UUID>,
        in modelContext: ModelContext
    ) throws -> [TrackedItem] {
        guard !expenseIDs.isEmpty else {
            return []
        }

        let descriptor =
            FetchDescriptor<TrackedItem>()

        var unlinkedItems: [TrackedItem] = []

        for item in try modelContext
            .fetch(descriptor) {
            guard
                let sourceExpenseID =
                    item.sourceExpenseID,
                expenseIDs.contains(
                    sourceExpenseID
                )
            else {
                continue
            }

            item.sourceExpenseID = nil
            unlinkedItems.append(item)
        }

        return unlinkedItems
    }
}
