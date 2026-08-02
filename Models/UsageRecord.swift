import Foundation
import SwiftData

@Model
final class UsageRecord {
    var id: UUID
    var usedAt: Date
    var notes: String
    var createdAt: Date
    var item: TrackedItem?
    var cloudantRevision: String?

    init(
        usedAt: Date = .now,
        notes: String = "",
        item: TrackedItem? = nil
    ) {
        self.id = UUID()
        self.usedAt = usedAt
        self.notes = notes
        self.createdAt = .now
        self.item = item
        self.cloudantRevision = nil
    }
}
