import Foundation

enum ExpenseReportPeriod: String, CaseIterable, Identifiable, Sendable {
    case month
    case semester
    case year

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .month:
            "Mês"

        case .semester:
            "Semestre"

        case .year:
            "Ano"
        }
    }

    var currentPeriodText: String {
        switch self {
        case .month:
            "mês atual"

        case .semester:
            "semestre atual"

        case .year:
            "ano atual"
        }
    }

    var previousPeriodAccessibilityLabel: String {
        switch self {
        case .month:
            "Mês anterior"

        case .semester:
            "Semestre anterior"

        case .year:
            "Ano anterior"
        }
    }

    var nextPeriodAccessibilityLabel: String {
        switch self {
        case .month:
            "Próximo mês"

        case .semester:
            "Próximo semestre"

        case .year:
            "Próximo ano"
        }
    }

    func dateInterval(
        containing date: Date,
        calendar: Calendar = .current
    ) -> DateInterval? {
        switch self {
        case .month:
            return calendar.dateInterval(
                of: .month,
                for: date
            )

        case .semester:
            let components = calendar.dateComponents(
                [.era, .year, .month],
                from: date
            )

            guard
                let month = components.month,
                let year = components.year
            else {
                return nil
            }

            var startComponents = DateComponents()
            startComponents.calendar = calendar
            startComponents.timeZone = calendar.timeZone
            startComponents.era = components.era
            startComponents.year = year
            startComponents.month = month <= 6 ? 1 : 7
            startComponents.day = 1

            guard
                let start = calendar.date(
                    from: startComponents
                ),
                let end = calendar.date(
                    byAdding: .month,
                    value: 6,
                    to: start
                )
            else {
                return nil
            }

            return DateInterval(
                start: start,
                end: end
            )

        case .year:
            return calendar.dateInterval(
                of: .year,
                for: date
            )
        }
    }

    func date(
        byAdvancing referenceDate: Date,
        value: Int,
        calendar: Calendar = .current
    ) -> Date? {
        guard
            let interval = dateInterval(
                containing: referenceDate,
                calendar: calendar
            )
        else {
            return nil
        }

        switch self {
        case .month:
            return calendar.date(
                byAdding: .month,
                value: value,
                to: interval.start
            )

        case .semester:
            return calendar.date(
                byAdding: .month,
                value: value * 6,
                to: interval.start
            )

        case .year:
            return calendar.date(
                byAdding: .year,
                value: value,
                to: interval.start
            )
        }
    }

    func formattedTitle(
        containing date: Date,
        calendar: Calendar = .current,
        locale: Locale = Locale(
            identifier: "pt_BR"
        )
    ) -> String {
        switch self {
        case .month:
            return date
                .formatted(
                    .dateTime
                        .month(.wide)
                        .year()
                        .locale(locale)
                )
                .capitalized(with: locale)

        case .semester:
            let month = calendar.component(
                .month,
                from: date
            )
            let year = calendar.component(
                .year,
                from: date
            )
            let semester = month <= 6 ? 1 : 2

            return "\(semester)º semestre de \(year)"

        case .year:
            return String(
                calendar.component(
                    .year,
                    from: date
                )
            )
        }
    }
}
