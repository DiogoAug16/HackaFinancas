import Foundation
import SwiftData

@Model
final class TrackedItem {
    var id: UUID
    var name: String
    var acquisitionValueInCents: Int
    var acquiredAt: Date
    var categoryRawValue: String
    var notes: String
    var createdAt: Date
    var isGift: Bool
    var trackingModeRawValue: String
    var goalValueInCents: Int?
    var goalPeriodRawValue: String?
    var isFavorite: Bool
    var statusRawValue: String
    var retiredAt: Date?
    var resaleValueInCents: Int?
    var customSymbolName: String?
    var imageIdentifier: String?
    var sourceExpenseID: UUID?

    @Relationship(
        deleteRule: .cascade,
        inverse: \UsageRecord.item
    )
    var usages: [UsageRecord]

    init(
        name: String,
        acquisitionValueInCents: Int,
        acquiredAt: Date = .now,
        category: ItemCategory = .other,
        notes: String = "",
        isGift: Bool = false,
        trackingMode: ItemTrackingMode = .time,
        goalValueInCents: Int? = nil,
        goalPeriod: ItemCostPeriod? = nil,
        isFavorite: Bool = false,
        status: ItemStatus = .active,
        retiredAt: Date? = nil,
        resaleValueInCents: Int? = nil,
        customSymbolName: String? = nil,
        imageIdentifier: String? = nil,
        sourceExpenseID: UUID? = nil,
        usages: [UsageRecord] = []
    ) {
        self.id = UUID()
        self.name = name
        self.acquisitionValueInCents =
            acquisitionValueInCents
        self.acquiredAt = acquiredAt
        self.categoryRawValue = category.rawValue
        self.notes = notes
        self.createdAt = .now
        self.isGift = isGift
        self.trackingModeRawValue =
            trackingMode.rawValue
        self.goalValueInCents = goalValueInCents
        self.goalPeriodRawValue =
            goalPeriod?.rawValue
        self.isFavorite = isFavorite
        self.statusRawValue = status.rawValue
        self.retiredAt = retiredAt
        self.resaleValueInCents =
            resaleValueInCents
        self.customSymbolName =
            customSymbolName
        self.imageIdentifier = imageIdentifier
        self.sourceExpenseID = sourceExpenseID
        self.usages = usages
    }

    var category: ItemCategory {
        get {
            ItemCategory(
                rawValue: categoryRawValue
            ) ?? .other
        }

        set {
            categoryRawValue = newValue.rawValue
        }
    }

    var trackingMode: ItemTrackingMode {
        get {
            ItemTrackingMode(
                rawValue: trackingModeRawValue
            ) ?? .time
        }

        set {
            trackingModeRawValue =
                newValue.rawValue
        }
    }

    var status: ItemStatus {
        get {
            ItemStatus(
                rawValue: statusRawValue
            ) ?? .active
        }

        set {
            statusRawValue = newValue.rawValue
        }
    }

    var goalPeriod: ItemCostPeriod? {
        get {
            guard let goalPeriodRawValue else {
                return nil
            }

            return ItemCostPeriod(
                rawValue: goalPeriodRawValue
            )
        }

        set {
            goalPeriodRawValue =
                newValue?.rawValue
        }
    }

    var usageCount: Int {
        usages.count
    }

    var lastUsageDate: Date? {
        usages.lazy.map(\.usedAt).max()
    }

    var effectiveCostInCents: Int {
        let acquisitionValue = max(
            0,
            acquisitionValueInCents
        )
        let resaleValue = max(
            0,
            resaleValueInCents ?? 0
        )

        guard resaleValue < acquisitionValue else {
            return 0
        }

        return acquisitionValue - resaleValue
    }

    var daysOwned: Int {
        daysOwned(at: .now)
    }

    var costPerUseInCents: Int? {
        guard usageCount > 0 else {
            return nil
        }

        return effectiveCostInCents / usageCount
    }

    var primaryCostInCents: Int? {
        switch trackingMode {
        case .time:
            costInCents(for: .day)

        case .usage:
            costPerUseInCents
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

    func daysOwned(
        at referenceDate: Date,
        calendar: Calendar = .current
    ) -> Int {
        let start = calendar.startOfDay(
            for: acquiredAt
        )
        let candidateEnd = retiredAt.map {
            min($0, referenceDate)
        } ?? referenceDate
        let end = calendar.startOfDay(
            for: candidateEnd
        )

        guard end >= start else {
            return 1
        }

        let elapsedDays = calendar.dateComponents(
            [.day],
            from: start,
            to: end
        ).day ?? 0
        let (inclusiveDays, overflow) =
            elapsedDays.addingReportingOverflow(1)

        return overflow
            ? Int.max
            : max(1, inclusiveDays)
    }

    func costInCents(
        for period: ItemCostPeriod,
        now referenceDate: Date = .now,
        calendar: Calendar = .current
    ) -> Int {
        let ownershipDays = daysOwned(
            at: referenceDate,
            calendar: calendar
        )
        let normalizedCost =
            Double(effectiveCostInCents)
            * Double(
                period.approximateDayCount
            )
            / Double(max(1, ownershipDays))

        guard normalizedCost.isFinite else {
            return Int.max
        }

        if normalizedCost
            >= Double(Int.max) {
            return Int.max
        }

        return max(
            0,
            Int(normalizedCost.rounded(.down))
        )
    }
}
