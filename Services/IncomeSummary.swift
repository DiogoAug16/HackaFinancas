import Foundation

enum IncomeSummary {
    static func dateInterval(
        for period: ExpenseReportPeriod,
        containing referenceDate: Date,
        calendar: Calendar = .current
    ) -> DateInterval? {
        period.dateInterval(
            containing: referenceDate,
            calendar: calendar
        )
    }

    static func entries(
        from entries: [IncomeEntry],
        in interval: DateInterval
    ) -> [IncomeEntry] {
        entries.filter {
            $0.date >= interval.start
                && $0.date < interval.end
        }
    }

    static func cashFlowDate(
        for entry: IncomeEntry
    ) -> Date {
        entry.receivedAt ?? entry.date
    }

    static func cashFlowEntries(
        from entries: [IncomeEntry],
        in interval: DateInterval
    ) -> [IncomeEntry] {
        entries.filter { entry in
            let effectiveDate =
                cashFlowDate(for: entry)

            return effectiveDate >= interval.start
                && effectiveDate < interval.end
        }
    }

    static func cashFlowEntries(
        from entries: [IncomeEntry],
        in period: ExpenseReportPeriod,
        containing referenceDate: Date,
        calendar: Calendar = .current
    ) -> [IncomeEntry] {
        guard let interval = dateInterval(
            for: period,
            containing: referenceDate,
            calendar: calendar
        ) else {
            return []
        }

        return cashFlowEntries(
            from: entries,
            in: interval
        )
    }

    static func entries(
        from entries: [IncomeEntry],
        in period: ExpenseReportPeriod,
        containing referenceDate: Date,
        calendar: Calendar = .current
    ) -> [IncomeEntry] {
        guard let interval = dateInterval(
            for: period,
            containing: referenceDate,
            calendar: calendar
        ) else {
            return []
        }

        return self.entries(
            from: entries,
            in: interval
        )
    }

    static func received(
        from entries: [IncomeEntry]
    ) -> [IncomeEntry] {
        entries.filter(\.isReceived)
    }

    static func received(
        from entries: [IncomeEntry],
        in interval: DateInterval
    ) -> [IncomeEntry] {
        entries.filter { entry in
            guard let receivedAt =
                entry.receivedAt
            else {
                return false
            }

            return receivedAt >= interval.start
                && receivedAt < interval.end
        }
    }

    static func received(
        from entries: [IncomeEntry],
        in period: ExpenseReportPeriod,
        containing referenceDate: Date,
        calendar: Calendar = .current
    ) -> [IncomeEntry] {
        guard let interval = dateInterval(
            for: period,
            containing: referenceDate,
            calendar: calendar
        ) else {
            return []
        }

        return received(
            from: entries,
            in: interval
        )
    }

    static func receivable(
        from entries: [IncomeEntry]
    ) -> [IncomeEntry] {
        entries.filter {
            !$0.isReceived
        }
    }

    static func totalInCents(
        _ entries: [IncomeEntry]
    ) -> Int {
        entries.reduce(0) {
            clampedAddition(
                $0,
                $1.amountInCents
            )
        }
    }

    static func receivedTotalInCents(
        _ entries: [IncomeEntry]
    ) -> Int {
        totalInCents(
            received(from: entries)
        )
    }

    static func receivableTotalInCents(
        _ entries: [IncomeEntry]
    ) -> Int {
        totalInCents(
            receivable(from: entries)
        )
    }

    static func totalByCategory(
        _ entries: [IncomeEntry]
    ) -> [(category: IncomeCategory, totalInCents: Int)] {
        let grouped = Dictionary(
            grouping: entries
        ) {
            $0.category
        }

        return grouped.map { category, entries in
            (
                category: category,
                totalInCents: totalInCents(
                    entries
                )
            )
        }
        .sorted {
            $0.totalInCents > $1.totalInCents
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
