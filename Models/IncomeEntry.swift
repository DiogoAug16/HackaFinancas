import Foundation
import SwiftData

@Model
final class IncomeEntry {
    var id: UUID
    var title: String
    var amountInCents: Int
    var date: Date
    var categoryRawValue: String
    var notes: String
    var createdAt: Date
    var recurrenceRawValue: String?
    var seriesID: UUID?
    var endDate: Date?
    var receivedAt: Date?

    init(
        title: String,
        amountInCents: Int,
        date: Date = .now,
        category: IncomeCategory = .other,
        notes: String = "",
        recurrence: FinancialRecurrence = .once,
        seriesID: UUID? = nil,
        endDate: Date? = nil,
        receivedAt: Date? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.amountInCents = amountInCents
        self.date = date
        self.categoryRawValue = category.rawValue
        self.notes = notes
        self.createdAt = .now
        self.recurrenceRawValue = recurrence.rawValue
        self.seriesID = seriesID

        if recurrence.isRecurring && self.seriesID == nil {
            self.seriesID = UUID()
        }

        self.endDate = recurrence.isRecurring
            ? endDate
            : nil
        self.receivedAt = receivedAt
    }

    var category: IncomeCategory {
        get {
            IncomeCategory(
                rawValue: categoryRawValue
            ) ?? .other
        }

        set {
            categoryRawValue = newValue.rawValue
        }
    }

    var recurrence: FinancialRecurrence {
        get {
            FinancialRecurrence(
                rawValue: recurrenceRawValue
                    ?? FinancialRecurrence.once.rawValue
            ) ?? .once
        }

        set {
            recurrenceRawValue = newValue.rawValue

            if newValue == .once {
                seriesID = nil
                endDate = nil
            } else if seriesID == nil {
                seriesID = UUID()
            }
        }
    }

    var isReceived: Bool {
        receivedAt != nil
    }
}
