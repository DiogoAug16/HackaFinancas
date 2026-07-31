import Foundation
import SwiftUI
import UIKit

struct TrackedItemCard: View {
    @Environment(\.colorScheme) private var colorScheme

    let item: TrackedItem

    var body: some View {
        HStack(spacing: 13) {
            AppVisual(
                item: item,
                size: 52,
                cornerRadius: 15,
                symbolForeground:
                    AppStyle.accentForeground(
                        colorScheme
                    )
            )

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 5) {
                    Text(item.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    if item.isFavorite {
                        Image(systemName: "heart.fill")
                            .font(.caption2)
                            .foregroundStyle(AppStyle.pink)
                            .accessibilityLabel("Favorito")
                    }
                }

                HStack(spacing: 5) {
                    Text(item.category.title)

                    Text("•")

                    Text(ownershipText)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

                Label(
                    item.status.title,
                    systemImage: item.status.symbol
                )
                .font(.caption2.weight(.medium))
                .foregroundStyle(statusColor)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 4) {
                if let primaryCost =
                    item.primaryCostInCents {
                    Text(primaryCost.currencyText)
                        .font(
                            .system(
                                .headline,
                                design: .rounded,
                                weight: .semibold
                            )
                        )
                        .foregroundStyle(
                            AppStyle.accentForeground(
                                colorScheme
                            )
                        )
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                    Text(primaryCostSuffix)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    Text("sem usos")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(
                            AppStyle.accentForeground(
                                colorScheme
                            )
                        )

                    Text("registre o primeiro")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
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

    private var ownershipText: String {
        let days = item.daysOwned

        if days < 31 {
            return days == 1
                ? "1 dia"
                : "\(days) dias"
        }

        if days < 365 {
            let months = max(1, days / 30)
            return months == 1
                ? "1 mês"
                : "\(months) meses"
        }

        let years = max(1, days / 365)
        return years == 1
            ? "1 ano"
            : "\(years) anos"
    }

    private var primaryCostSuffix: String {
        item.trackingMode == .usage
            ? "por uso"
            : "por dia"
    }

    private var statusColor: Color {
        switch item.status {
        case .active:
            AppStyle.accentForeground(colorScheme)

        case .sold:
            AppStyle.gold

        case .donated:
            AppStyle.pink

        case .discarded:
            .secondary
        }
    }

    private var accessibilityText: String {
        var parts = [
            item.name,
            item.category.title,
            item.status.title,
            ownershipText
        ]

        if let primaryCost =
            item.primaryCostInCents {
            parts.append(
                "\(primaryCost.currencyText) \(primaryCostSuffix)"
            )
        } else {
            parts.append("Nenhum uso registrado")
        }

        return parts.joined(separator: ", ")
    }
}
