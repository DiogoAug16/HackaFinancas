import SwiftUI

struct ExpenseCard: View {
    @Environment(\.colorScheme) private var colorScheme

    let expense: Expense

    var body: some View {
        HStack(spacing: 13) {
            categoryIcon

            expenseInformation

            Spacer(minLength: 8)

            amountInformation
        }
        .padding(14)
        .background(
            AppStyle.surface(colorScheme),
            in: RoundedRectangle(
                cornerRadius: 18,
                style: .continuous
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: 18,
                style: .continuous
            )
            .stroke(
                Color.secondary.opacity(0.12),
                lineWidth: 1
            )
        }
        .contentShape(
            RoundedRectangle(
                cornerRadius: 18,
                style: .continuous
            )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    private var categoryIcon: some View {
        AppVisual(
            expense: expense,
            size: 48,
            cornerRadius: 14,
            symbolForeground:
                AppStyle.accentForeground(
                    colorScheme
                )
        )
    }

    private var expenseInformation: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(expense.title)
                .font(.headline)
                .foregroundStyle(.primary)
                .lineLimit(1)

            HStack(spacing: 5) {
                Text(expense.category.rawValue)

                Text("•")

                Text(expense.date.shortDateText)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
    }

    private var amountInformation: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(expense.amountInCents.currencyText)
                .font(.system(.headline, design: .rounded))
                .fontWeight(.semibold)
                .foregroundStyle(
                    AppStyle.accentForeground(
                        colorScheme
                    )
                )
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            if isFutureExpense {
                Label(
                    "programado",
                    systemImage: "calendar.badge.clock"
                )
                .font(.caption2)
                .foregroundStyle(.secondary)
            } else if expense.recurrence == .once {
                Text("gasto")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                Label(
                    expense.recurrence.shortTitle.lowercased(),
                    systemImage: "repeat"
                )
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
    }

    private var accessibilityText: String {
        var values = [
            expense.title,
            expense.category.rawValue,
            expense.amountInCents.currencyText,
            expense.date.shortDateText
        ]

        if expense.recurrence.isRecurring {
            values.append(
                expense.recurrence.summaryText
            )
        }

        if isFutureExpense {
            values.append("Lançamento futuro")
        }

        return values.joined(separator: ", ")
    }

    private var isFutureExpense: Bool {
        Calendar.current.compare(
            expense.date,
            to: Date.now,
            toGranularity: .day
        ) == .orderedDescending
    }
}
