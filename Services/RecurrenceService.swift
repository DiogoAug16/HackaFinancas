import Foundation

enum RecurrenceService {
    static let defaultOccurrenceLimit = 500

    static func occurrenceDates(
        startingAt startDate: Date,
        recurrence: FinancialRecurrence,
        until endDate: Date?,
        calendar: Calendar = .current,
        limit: Int = defaultOccurrenceLimit
    ) -> [Date] {
        guard recurrence.isRecurring else {
            return [startDate]
        }

        var dates: [Date] = []
        var currentIndex = 0
        let maxLimit = min(max(1, limit), defaultOccurrenceLimit)

        while currentIndex < maxLimit {
            guard let date = occurrenceDate(
                startingAt: startDate,
                recurrence: recurrence,
                occurrenceIndex: currentIndex,
                calendar: calendar
            ) else {
                break
            }

            if let endDate {
                let comparison = calendar.compare(
                    date,
                    to: endDate,
                    toGranularity: .day
                )
                if comparison == .orderedDescending {
                    break
                }
            }

            dates.append(date)
            currentIndex += 1
        }

        return dates
    }

    static func occurrenceDate(
        startingAt startDate: Date,
        recurrence: FinancialRecurrence,
        occurrenceIndex: Int,
        calendar: Calendar = .current
    ) -> Date? {
        guard occurrenceIndex >= 0 else {
            return nil
        }

        if occurrenceIndex == 0 || !recurrence.isRecurring {
            return startDate
        }

        if let days = recurrence.dayInterval {
            return calendar.date(
                byAdding: .day,
                value: days * occurrenceIndex,
                to: startDate
            )
        }

        if let months = recurrence.monthInterval {
            return calendar.date(
                byAdding: .month,
                value: months * occurrenceIndex,
                to: startDate
            )
        }

        return nil
    }
}
