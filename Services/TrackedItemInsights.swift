import Foundation

enum TrackedItemInsights {
    struct StatusSummary: Identifiable, Sendable {
        let status: ItemStatus
        let itemCount: Int
        let totalInvestedInCents: Int
        let totalEffectiveCostInCents: Int

        var id: ItemStatus {
            status
        }
    }

    static func totalInvestedInCents(
        _ items: [TrackedItem]
    ) -> Int {
        items.reduce(0) { total, item in
            guard !item.isGift else {
                return total
            }

            return clampedAddition(
                total,
                max(
                    0,
                    item.acquisitionValueInCents
                )
            )
        }
    }

    static func totalEffectiveCostInCents(
        _ items: [TrackedItem]
    ) -> Int {
        items.reduce(0) { total, item in
            guard !item.isGift else {
                return total
            }

            return clampedAddition(
                total,
                item.effectiveCostInCents
            )
        }
    }

    static func activeItems(
        from items: [TrackedItem]
    ) -> [TrackedItem] {
        items.filter {
            $0.status.isActive
        }
    }

    static func bestActiveItem(
        from items: [TrackedItem],
        trackingMode: ItemTrackingMode,
        at referenceDate: Date = .now,
        calendar: Calendar = .current
    ) -> TrackedItem? {
        let candidate = activePurchases(
            from: items,
            trackingMode: trackingMode
        )
        .compactMap { item in
            metric(
                for: item,
                at: referenceDate,
                calendar: calendar
            ).map {
                (
                    item: item,
                    value: $0
                )
            }
        }
        .min {
            if $0.value == $1.value {
                return $0.item.acquiredAt
                    < $1.item.acquiredAt
            }

            return $0.value < $1.value
        }

        return candidate?.item
    }

    static func worstActiveItem(
        from items: [TrackedItem],
        trackingMode: ItemTrackingMode,
        at referenceDate: Date = .now,
        calendar: Calendar = .current
    ) -> TrackedItem? {
        activePurchases(
            from: items,
            trackingMode: trackingMode
        )
        .max { first, second in
            let firstMetric = metric(
                for: first,
                at: referenceDate,
                calendar: calendar
            )
            let secondMetric = metric(
                for: second,
                at: referenceDate,
                calendar: calendar
            )

            switch (
                firstMetric,
                secondMetric
            ) {
            case let (
                firstValue?,
                secondValue?
            ):
                if firstValue == secondValue {
                    return first.acquiredAt
                        > second.acquiredAt
                }

                return firstValue < secondValue

            case (nil, nil):
                return first.acquiredAt
                    > second.acquiredAt

            case (nil, _?):
                return false

            case (_?, nil):
                return true
            }
        }
    }

    static func dormantItems(
        from items: [TrackedItem],
        at referenceDate: Date = .now,
        thresholdDays: Int = 90,
        calendar: Calendar = .current
    ) -> [TrackedItem] {
        let safeThreshold = max(
            1,
            thresholdDays
        )

        guard let cutoffDate = calendar.date(
            byAdding: .day,
            value: -safeThreshold,
            to: referenceDate
        ) else {
            return []
        }

        return activeItems(
            from: items
        )
        .filter { item in
            guard item.trackingMode == .usage else {
                return false
            }

            let mostRecentActivity =
                item.lastUsageDate
                    ?? item.acquiredAt

            return mostRecentActivity <= cutoffDate
        }
        .sorted {
            let firstDate =
                $0.lastUsageDate
                    ?? $0.acquiredAt
            let secondDate =
                $1.lastUsageDate
                    ?? $1.acquiredAt

            return firstDate < secondDate
        }
    }

    static func statusCounts(
        for items: [TrackedItem]
    ) -> [ItemStatus: Int] {
        Dictionary(
            grouping: items,
            by: \.status
        )
        .mapValues(\.count)
    }

    static func summariesByStatus(
        for items: [TrackedItem]
    ) -> [StatusSummary] {
        let grouped = Dictionary(
            grouping: items,
            by: \.status
        )

        return ItemStatus.allCases.compactMap {
            status in
            guard let statusItems = grouped[status] else {
                return nil
            }

            return StatusSummary(
                status: status,
                itemCount: statusItems.count,
                totalInvestedInCents:
                    totalInvestedInCents(
                        statusItems
                    ),
                totalEffectiveCostInCents:
                    totalEffectiveCostInCents(
                        statusItems
                    )
            )
        }
    }

    private static func activePurchases(
        from items: [TrackedItem],
        trackingMode: ItemTrackingMode
    ) -> [TrackedItem] {
        activeItems(
            from: items
        )
        .filter {
            !$0.isGift
                && $0.trackingMode
                    == trackingMode
        }
    }

    private static func metric(
        for item: TrackedItem,
        at referenceDate: Date,
        calendar: Calendar
    ) -> Int? {
        switch item.trackingMode {
        case .time:
            item.costInCents(
                for: .day,
                now: referenceDate,
                calendar: calendar
            )

        case .usage:
            item.costPerUseInCents
        }
    }

    private static func clampedAddition(
        _ current: Int,
        _ value: Int
    ) -> Int {
        let (result, overflow) =
            current.addingReportingOverflow(
                value
            )

        guard overflow else {
            return result
        }

        return value >= 0
            ? Int.max
            : Int.min
    }
}
