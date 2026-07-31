import Foundation

enum FinancialRecurrence: String, CaseIterable, Identifiable, Codable, Sendable {
    case once
    case weekly
    case monthly
    case quarterly
    case semiannual
    case annual

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .once: return "Eventual / única"
        case .weekly: return "Semanal"
        case .monthly: return "Mensal"
        case .quarterly: return "Trimestral"
        case .semiannual: return "Semestral"
        case .annual: return "Anual"
        }
    }

    var shortTitle: String {
        self == .once ? "Única" : title
    }

    var summaryText: String {
        switch self {
        case .once: return "Transação eventual ou única"
        case .weekly: return "Repete toda semana"
        case .monthly: return "Repete todos os meses"
        case .quarterly: return "Repete a cada 3 meses"
        case .semiannual: return "Repete a cada 6 meses"
        case .annual: return "Repete todos os anos"
        }
    }

    var symbol: String {
        switch self {
        case .once: return "calendar.badge.plus"
        case .weekly: return "calendar.day.timeline.left"
        case .monthly: return "calendar"
        case .quarterly: return "calendar.badge.clock"
        case .semiannual: return "calendar.circle"
        case .annual: return "calendar.circle.fill"
        }
    }

    var isRecurring: Bool {
        self != .once
    }

    var dayInterval: Int? {
        self == .weekly ? 7 : nil
    }

    var monthInterval: Int? {
        switch self {
        case .once, .weekly: return nil
        case .monthly: return 1
        case .quarterly: return 3
        case .semiannual: return 6
        case .annual: return 12
        }
    }

    func occurrenceDates(
        from startDate: Date,
        through endDate: Date? = nil,
        calendar: Calendar = .current,
        maxCount: Int = RecurrenceService.defaultOccurrenceLimit
    ) -> [Date] {
        RecurrenceService.occurrenceDates(
            startingAt: startDate,
            recurrence: self,
            until: endDate,
            calendar: calendar,
            limit: maxCount
        )
    }

    func minimumEndDate(
        from startDate: Date,
        calendar: Calendar = .current
    ) -> Date {
        RecurrenceService.occurrenceDate(
            startingAt: startDate,
            recurrence: self,
            occurrenceIndex: 1,
            calendar: calendar
        ) ?? startDate
    }

    func suggestedEndDate(
        from startDate: Date,
        calendar: Calendar = .current
    ) -> Date {
        guard isRecurring else {
            return startDate
        }

        let occurrenceCount: Int = {
            switch self {
            case .weekly, .monthly: return 11
            case .quarterly: return 3
            default: return 1
            }
        }()

        return RecurrenceService.occurrenceDate(
            startingAt: startDate,
            recurrence: self,
            occurrenceIndex: occurrenceCount,
            calendar: calendar
        ) ?? minimumEndDate(
            from: startDate,
            calendar: calendar
        )
    }

    func maximumEndDate(
        from startDate: Date,
        calendar: Calendar = .current
    ) -> Date {
        guard isRecurring else {
            return startDate
        }

        let occurrenceIndex = self == .weekly ? 520 : max(1, 120 / (monthInterval ?? 1))

        return RecurrenceService.occurrenceDate(
            startingAt: startDate,
            recurrence: self,
            occurrenceIndex: occurrenceIndex,
            calendar: calendar
        ) ?? suggestedEndDate(
            from: startDate,
            calendar: calendar
        )
    }
}
