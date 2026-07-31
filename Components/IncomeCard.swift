import SwiftUI

struct IncomeCard: View {
    @Environment(\.colorScheme)
    private var colorScheme

    let entry: IncomeEntry

    var body: some View {
        HStack(spacing: 13) {
            categoryIcon
            entryInformation

            Spacer(minLength: 8)

            amountInformation
        }
        .padding(14)
        .background(
            AppStyle.surface(colorScheme),
            in: RoundedRectangle(
                cornerRadius: AppStyle.cardRadius,
                style: .continuous
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: AppStyle.cardRadius,
                style: .continuous
            )
            .stroke(
                AppStyle.border(colorScheme),
                lineWidth: 1
            )
        }
        .contentShape(
            RoundedRectangle(
                cornerRadius: AppStyle.cardRadius,
                style: .continuous
            )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    private var categoryIcon: some View {
        Image(systemName: entry.category.symbol)
            .font(.system(size: 19, weight: .semibold))
            .foregroundStyle(
                AppStyle.accentForeground(colorScheme)
            )
            .frame(width: 50, height: 50)
            .background(
                AppStyle.mint.opacity(0.12),
                in: RoundedRectangle(
                    cornerRadius: 14,
                    style: .continuous
                )
            )
            .accessibilityHidden(true)
    }

    private var entryInformation: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(entry.title)
                .font(.headline)
                .foregroundStyle(.primary)
                .lineLimit(1)

            HStack(spacing: 5) {
                Text(entry.category.title)

                Text("•")

                Text(
                    IncomeSummary.cashFlowDate(
                        for: entry
                    ).shortDateText
                )
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)

            if entry.recurrence.isRecurring {
                Label(
                    entry.recurrence.shortTitle,
                    systemImage: "repeat"
                )
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
    }

    private var amountInformation: some View {
        VStack(alignment: .trailing, spacing: 5) {
            Text(entry.amountInCents.currencyText)
                .font(
                    .system(
                        .headline,
                        design: .rounded,
                        weight: .semibold
                    )
                )
                .foregroundStyle(
                    AppStyle.accentForeground(colorScheme)
                )
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Label(
                entry.isReceived
                    ? "recebido"
                    : "a receber",
                systemImage: entry.isReceived
                    ? "checkmark.circle.fill"
                    : "clock.fill"
            )
            .font(.caption2.weight(.medium))
            .foregroundStyle(
                entry.isReceived
                    ? AppStyle.accentForeground(colorScheme)
                    : Color.secondary
            )
        }
    }

    private var accessibilityText: String {
        [
            entry.title,
            entry.category.title,
            entry.amountInCents.currencyText,
            IncomeSummary.cashFlowDate(
                for: entry
            ).shortDateText,
            entry.isReceived
                ? "Recebido"
                : "A receber",
            entry.recurrence.summaryText
        ]
        .joined(separator: ", ")
    }
}
