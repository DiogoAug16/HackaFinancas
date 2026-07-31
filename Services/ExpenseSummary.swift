import Foundation

enum ExpenseSummary {
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

    static func expenses(
        from expenses: [Expense],
        in interval: DateInterval
    ) -> [Expense] {
        expenses.filter {
            $0.date >= interval.start
                && $0.date < interval.end
        }
    }

    static func expenses(
        from expenses: [Expense],
        in period: ExpenseReportPeriod,
        containing referenceDate: Date,
        calendar: Calendar = .current
    ) -> [Expense] {
        guard let interval = dateInterval(
            for: period,
            containing: referenceDate,
            calendar: calendar
        ) else {
            return []
        }

        return self.expenses(
            from: expenses,
            in: interval
        )
    }

    static func expenses(
        from expenses: [Expense],
        in month: Date,
        calendar: Calendar = .current
    ) -> [Expense] {
        self.expenses(
            from: expenses,
            in: .month,
            containing: month,
            calendar: calendar
        )
    }

    static func totalInCents(
        _ expenses: [Expense]
    ) -> Int {
        expenses.reduce(0) {
            clampedAddition(
                $0,
                $1.amountInCents
            )
        }
    }

    static func totalByCategory(
        _ expenses: [Expense]
    ) -> [(category: ExpenseCategory, totalInCents: Int)] {
        let grouped = Dictionary(grouping: expenses) {
            $0.category
        }

        return grouped.map { category, expenses in
            (
                category: category,
                totalInCents: expenses.reduce(0) {
                    clampedAddition(
                        $0,
                        $1.amountInCents
                    )
                }
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
