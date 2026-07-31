import SwiftUI

enum AppTab: Hashable {
    case expenses
    case income
    case items
    case dashboard
}

struct CustomTabBar: View {
    @Environment(\.colorScheme) private var colorScheme

    @Binding var selectedTab: AppTab
    let onAdd: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            tabButton(
                title: "Gastos",
                systemImage: "list.bullet.rectangle",
                tab: .expenses
            )

            tabButton(
                title: "Entradas",
                systemImage: "arrow.down.circle.fill",
                tab: .income
            )

            addButton

            tabButton(
                title: "Itens",
                systemImage: "shippingbox.fill",
                tab: .items
            )

            tabButton(
                title: "Resumo",
                systemImage: "chart.bar.fill",
                tab: .dashboard
            )
        }
        .padding(.horizontal, 8)
        .padding(.top, 10)
        .padding(.bottom, 6)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Divider()
                .opacity(0.45)
        }
    }

    private var addButton: some View {
        Button(action: onAdd) {
            Image(systemName: "plus")
                .font(.title2.bold())
                .foregroundStyle(.white)
                .frame(width: 58, height: 58)
                .background(
                    AppStyle.mintStrong,
                    in: Circle()
                )
                .shadow(
                    color: AppStyle.mint.opacity(0.32),
                    radius: 12,
                    y: 6
                )
        }
        .frame(maxWidth: .infinity)
        .buttonStyle(.plain)
        .accessibilityLabel("Adicionar")
    }

    private func tabButton(
        title: String,
        systemImage: String,
        tab: AppTab
    ) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                selectedTab = tab
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.title3)

                Text(title)
                    .font(.caption2.weight(.semibold))
            }
            .foregroundStyle(
                selectedTab == tab
                    ? AppStyle.accentForeground(
                        colorScheme
                    )
                    : Color.secondary
            )
            .frame(
                maxWidth: .infinity,
                minHeight: 52
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(
            selectedTab == tab
                ? .isSelected
                : []
        )
    }
}
