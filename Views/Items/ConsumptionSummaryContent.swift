import SwiftData
import SwiftUI

struct ConsumptionSummaryContent: View {
    @Environment(\.colorScheme) private var colorScheme

    @Query(
        sort: \TrackedItem.acquiredAt,
        order: .reverse
    )
    private var items: [TrackedItem]

    @State private var selectedPeriod: ItemCostPeriod = .day

    private var activeItems: [TrackedItem] {
        TrackedItemInsights.activeItems(
            from: items
        )
    }

    private var inactiveItems: [TrackedItem] {
        let retiredItems = items.filter {
            $0.status != .active
        }
        let dormantItems =
            TrackedItemInsights.dormantItems(
                from: items
            )

        return (retiredItems + dormantItems)
            .sorted {
                (
                    $0.lastUsageDate
                        ?? $0.acquiredAt
                ) < (
                    $1.lastUsageDate
                        ?? $1.acquiredAt
                )
            }
    }

    private var paidActiveItems: [TrackedItem] {
        activeItems.filter {
            !$0.isGift
                && $0.acquisitionValueInCents > 0
        }
    }

    private var insightMode: ItemTrackingMode? {
        let usageCount = paidActiveItems.lazy
            .filter {
                $0.trackingMode == .usage
            }
            .count
        let timeCount = paidActiveItems.count
            - usageCount

        if usageCount >= 2 {
            return .usage
        }

        if timeCount >= 2 {
            return .time
        }

        if usageCount == 1 {
            return .usage
        }

        return timeCount == 1
            ? .time
            : nil
    }

    private var comparableItemCount: Int {
        guard let insightMode else {
            return 0
        }

        return paidActiveItems.lazy.filter {
            $0.trackingMode == insightMode
        }.count
    }

    private var timeTrackedItems: [TrackedItem] {
        activeItems.filter {
            $0.trackingMode == .time
                && !$0.isGift
        }
    }

    private var totalInvestedInCents: Int {
        TrackedItemInsights
            .totalInvestedInCents(
                items
            )
    }

    private var collectionCostInCents: Int {
        safeTotal(
            timeTrackedItems.map {
                $0.costInCents(
                    for: selectedPeriod
                )
            }
        )
    }

    private var totalUsageCount: Int {
        safeTotal(
            items.map(\.usageCount)
        )
    }

    private var bestUtilizedItem: TrackedItem? {
        guard let insightMode else {
            return nil
        }

        return TrackedItemInsights.bestActiveItem(
            from: items,
            trackingMode: insightMode
        )
    }

    private var itemWithMorePotential: TrackedItem? {
        guard
            let insightMode,
            comparableItemCount > 1
        else {
            return nil
        }

        return TrackedItemInsights
            .worstActiveItem(
                from: items,
                trackingMode: insightMode
            )
    }

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: 16
        ) {
            if items.isEmpty {
                emptyState
            } else {
                if !timeTrackedItems.isEmpty {
                    periodPicker
                    collectionCostCard
                }

                investmentCard

                HStack(spacing: 12) {
                    metricCard(
                        title: "ativos",
                        value: "\(activeItems.count)",
                        symbol: "checkmark.circle.fill"
                    )

                    metricCard(
                        title: "usos",
                        value: "\(totalUsageCount)",
                        symbol: "hand.tap.fill"
                    )
                }

                if let bestUtilizedItem {
                    highlightCard(
                        eyebrow:
                            "melhor aproveitado \(insightQualifier)",
                        symbol: "star.fill",
                        item: bestUtilizedItem
                    )
                }

                if let itemWithMorePotential {
                    highlightCard(
                        eyebrow:
                            "pode render mais \(insightQualifier)",
                        symbol: "arrow.up.right",
                        item: itemWithMorePotential
                    )
                }

                inactiveCard
            }
        }
    }

    private var periodPicker: some View {
        Picker(
            "Período do custo",
            selection: $selectedPeriod
        ) {
            ForEach(ItemCostPeriod.allCases) { period in
                Text(periodTitle(period))
                    .tag(period)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityHint(
            "Altera o período usado para calcular o custo da coleção."
        )
    }

    private var collectionCostCard: some View {
        VStack(
            alignment: .leading,
            spacing: 6
        ) {
            Text("sua coleção custa")
                .font(.subheadline)
                .foregroundStyle(
                    .white.opacity(0.88)
                )

            HStack(
                alignment: .lastTextBaseline,
                spacing: 4
            ) {
                Text(
                    collectionCostInCents.currencyText
                )
                .font(
                    .system(
                        size: 42,
                        weight: .semibold,
                        design: .rounded
                    )
                )
                .tracking(-1)
                .minimumScaleFactor(0.62)
                .lineLimit(1)

                Text(
                    "/\(periodTitle(selectedPeriod).lowercased())"
                )
                .font(.headline)
            }

            Text(collectionCostDescription)
                .font(.caption)
                .foregroundStyle(
                    .white.opacity(0.8)
                )
        }
        .foregroundStyle(.white)
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .padding(22)
        .background(
            AppStyle.mintStrong.gradient,
            in: RoundedRectangle(
                cornerRadius: AppStyle.heroRadius,
                style: .continuous
            )
        )
        .shadow(
            color: AppStyle.mint.opacity(0.24),
            radius: 14,
            y: 8
        )
        .accessibilityElement(children: .combine)
    }

    private var investmentCard: some View {
        HStack(spacing: 14) {
            Image(systemName: "banknote.fill")
                .font(.headline)
                .foregroundStyle(
                    AppStyle.accentForeground(
                        colorScheme
                    )
                )
                .frame(width: 42, height: 42)
                .background(
                    AppStyle.mint.opacity(0.12),
                    in: RoundedRectangle(
                        cornerRadius: 12,
                        style: .continuous
                    )
                )

            VStack(
                alignment: .leading,
                spacing: 3
            ) {
                Text("total investido")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(
                    totalInvestedInCents.currencyText
                )
                .font(
                    .system(
                        .title2,
                        design: .rounded,
                        weight: .semibold
                    )
                )
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            }

            Spacer(minLength: 8)

            if items.contains(where: \.isGift) {
                Text("presentes não somam")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
            }
        }
        .appCard(
            colorScheme: colorScheme
        )
        .accessibilityElement(children: .combine)
    }

    private func metricCard(
        title: String,
        value: String,
        symbol: String
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: 8
        ) {
            Image(systemName: symbol)
                .font(.subheadline.bold())
                .foregroundStyle(
                    AppStyle.accentForeground(
                        colorScheme
                    )
                )

            Text(value)
                .font(
                    .system(
                        .title2,
                        design: .rounded,
                        weight: .semibold
                    )
                )

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .appCard(
            colorScheme: colorScheme
        )
        .accessibilityElement(children: .combine)
    }

    private func highlightCard(
        eyebrow: String,
        symbol: String,
        item: TrackedItem
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: 11
        ) {
            Label(
                eyebrow,
                systemImage: symbol
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                AppVisual(
                    item: item,
                    size: 52,
                    cornerRadius: 13,
                    symbolForeground:
                        AppStyle.accentForeground(
                            colorScheme
                        )
                )

                VStack(
                    alignment: .leading,
                    spacing: 3
                ) {
                    Text(item.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(item.category.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                VStack(
                    alignment: .trailing,
                    spacing: 2
                ) {
                    Text(
                        utilizationCost(
                            for: item
                        )
                        .currencyText
                    )
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
                    .minimumScaleFactor(0.72)
                    .lineLimit(1)

                    Text(
                        utilizationUnit(
                            for: item
                        )
                    )
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .appCard(
            colorScheme: colorScheme
        )
        .accessibilityElement(children: .combine)
    }

    private var inactiveCard: some View {
        VStack(
            alignment: .leading,
            spacing: 12
        ) {
            HStack {
                Label(
                    "itens inativos",
                    systemImage: "archivebox.fill"
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)

                Spacer()

                Text("\(inactiveItems.count)")
                    .font(.caption.bold())
                    .foregroundStyle(
                        AppStyle.accentForeground(
                            colorScheme
                        )
                    )
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(
                        AppStyle.mint.opacity(0.12),
                        in: Capsule()
                    )
            }

            if inactiveItems.isEmpty {
                Text(
                    "Nenhum item encerrado ou parado há 90 dias."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            } else {
                ForEach(
                    inactiveItems.prefix(3)
                ) { item in
                    HStack(spacing: 10) {
                        Image(
                            systemName:
                                item.visualSymbol
                        )
                        .font(.caption.bold())
                        .foregroundStyle(
                            AppStyle.accentForeground(
                                colorScheme
                            )
                        )
                        .frame(width: 28, height: 28)
                        .background(
                            AppStyle.mint.opacity(0.1),
                            in: RoundedRectangle(
                                cornerRadius: 8,
                                style: .continuous
                            )
                        )

                        Text(item.name)
                            .font(.subheadline)
                            .lineLimit(1)

                        Spacer()

                        Text(
                            inactivityDescription(
                                for: item
                            )
                        )
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    }
                }

                if inactiveItems.count > 3 {
                    Text(
                        "e mais \(inactiveItems.count - 3)"
                    )
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .appCard(
            colorScheme: colorScheme
        )
        .accessibilityElement(children: .combine)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            BrandLogo(
                variant: .playful,
                size: 130
            )

            Text("Sua coleção está vazia")
                .font(.headline)

            Text(
                "Cadastre uma compra como item para acompanhar uso, vida útil e custo real."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .appCard(
            colorScheme: colorScheme
        )
    }

    private var collectionCostDescription: String {
        let count = timeTrackedItems.count

        if count == 1 {
            return "1 item ativo acompanhado por tempo"
        }

        return "\(count) itens ativos acompanhados por tempo"
    }

    private func utilizationCost(
        for item: TrackedItem
    ) -> Int {
        if item.trackingMode == .usage {
            return item.costPerUseInCents
                ?? item.acquisitionValueInCents
        }

        return item.costInCents(
            for: selectedPeriod
        )
    }

    private func inactivityDescription(
        for item: TrackedItem
    ) -> String {
        if item.status != .active {
            return item.status.title
                .lowercased()
        }

        guard let lastUsageDate =
            item.lastUsageDate
        else {
            return "nenhum uso"
        }

        return "desde \(lastUsageDate.shortDateText)"
    }

    private func utilizationUnit(
        for item: TrackedItem
    ) -> String {
        if item.trackingMode == .usage {
            return item.usageCount == 0
                ? "sem usos"
                : "por uso"
        }

        return "por \(periodTitle(selectedPeriod).lowercased())"
    }

    private var insightQualifier: String {
        insightMode == .usage
            ? "por uso"
            : "pelo tempo"
    }

    private func periodTitle(
        _ period: ItemCostPeriod
    ) -> String {
        switch period {
        case .day:
            return "Dia"

        case .week:
            return "Semana"

        case .month:
            return "Mês"

        case .year:
            return "Ano"
        }
    }

    private func safeTotal(
        _ values: [Int]
    ) -> Int {
        values.reduce(0) {
            partialResult,
            value in
            let nonnegativeValue = max(0, value)
            let result =
                partialResult
                .addingReportingOverflow(
                    nonnegativeValue
                )

            return result.overflow
                ? Int.max
                : result.partialValue
        }
    }
}
