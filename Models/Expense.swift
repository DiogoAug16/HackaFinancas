import Foundation
import SwiftData

//@Model para gerenciar o armazenamento local @query para pegar os registros
//na interface

@Model
final class Expense {
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
    var customSymbolName: String?
    var imageIdentifier: String?

    init(
        title: String,
        amountInCents: Int,
        date: Date = .now,
        category: ExpenseCategory = .other,
        notes: String = "",
        recurrence: FinancialRecurrence = .once,
        seriesID: UUID? = nil,
        endDate: Date? = nil,
        customSymbolName: String? = nil,
        imageIdentifier: String? = nil
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

        self.endDate = endDate
        self.customSymbolName = customSymbolName
        self.imageIdentifier = imageIdentifier
    }

    var category: ExpenseCategory {
        get {
            ExpenseCategory(rawValue: categoryRawValue) ?? .other
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

    var visualSymbol: String {
        guard
            let customSymbolName,
            !customSymbolName.trimmingCharacters(
                in: .whitespacesAndNewlines
            ).isEmpty
        else {
            return category.symbol
        }

        return customSymbolName.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
    }

}
