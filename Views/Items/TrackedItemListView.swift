import SwiftData
import SwiftUI

struct TrackedItemListView: View {
    @Environment(\.modelContext)
    private var modelContext
    @Environment(\.colorScheme)
    private var colorScheme

    @Query(
        sort: \TrackedItem.acquiredAt,
        order: .reverse
    )
    private var items: [TrackedItem]

    @State private var searchText = ""
    @State private var selectedCategory:
        ItemCategory?
    @State private var selectedStatus:
        ItemStatus?
    @State private var pendingDeletion:
        TrackedItem?
    @State private var operationError: String?

    let onSettings: () -> Void

    init(
        onSettings: @escaping () -> Void = {}
    ) {
        self.onSettings = onSettings
    }

    private var visibleItems: [TrackedItem] {
        let normalizedSearch =
            searchText.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        return items.filter { item in
            let matchesSearch =
                normalizedSearch.isEmpty
                || item.name
                    .localizedCaseInsensitiveContains(
                        normalizedSearch
                    )
                || item.category.title
                    .localizedCaseInsensitiveContains(
                        normalizedSearch
                    )
                || item.notes
                    .localizedCaseInsensitiveContains(
                        normalizedSearch
                    )

            let matchesCategory =
                selectedCategory == nil
                || item.category
                    == selectedCategory

            let matchesStatus =
                selectedStatus == nil
                || item.status == selectedStatus

            return matchesSearch
                && matchesCategory
                && matchesStatus
        }
    }

    private var activeItemCount: Int {
        items.lazy.filter {
            $0.status.isActive
        }.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(
                    alignment: .leading,
                    spacing: 18
                ) {
                    header
                    searchBar
                    statusFilters
                    categoryFilters
                    resultInformation
                    content
                }
                .padding(20)
                .padding(.bottom, 12)
            }
            .background(
                AppStyle.background(colorScheme)
                    .ignoresSafeArea()
            )
            .toolbar(.hidden, for: .navigationBar)
            .alert(
                "Não foi possível concluir a ação",
                isPresented: Binding(
                    get: {
                        operationError != nil
                    },
                    set: { isPresented in
                        if !isPresented {
                            operationError = nil
                        }
                    }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(operationError ?? "")
            }
            .confirmationDialog(
                "Excluir este item?",
                isPresented: Binding(
                    get: {
                        pendingDeletion != nil
                    },
                    set: { isPresented in
                        if !isPresented {
                            pendingDeletion = nil
                        }
                    }
                ),
                titleVisibility: .visible
            ) {
                Button(
                    "Excluir item e histórico",
                    role: .destructive
                ) {
                    if let pendingDeletion {
                        delete(pendingDeletion)
                    }

                    pendingDeletion = nil
                }

                Button(
                    "Cancelar",
                    role: .cancel
                ) {
                    pendingDeletion = nil
                }
            } message: {
                Text(
                    "Os usos registrados também serão apagados. Um gasto vinculado será mantido."
                )
            }
        }
    }

    private var header: some View {
        AppHeader(
            title: "Meus itens",
            subtitle: activeItemCount == 1
                ? "1 item em uso"
                : "\(activeItemCount) itens em uso",
            onSettings: onSettings
        )
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField(
                "buscar item...",
                text: $searchText
            )
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(
                        systemName:
                            "xmark.circle.fill"
                    )
                }
                .foregroundStyle(.secondary)
                .buttonStyle(.plain)
                .accessibilityLabel("Limpar busca")
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 48)
        .background(
            AppStyle.surface(colorScheme),
            in: RoundedRectangle(
                cornerRadius:
                    AppStyle.controlRadius,
                style: .continuous
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius:
                    AppStyle.controlRadius,
                style: .continuous
            )
            .stroke(
                AppStyle.border(colorScheme),
                lineWidth: 1
            )
        }
    }

    private var statusFilters: some View {
        ScrollView(
            .horizontal,
            showsIndicators: false
        ) {
            HStack(spacing: 8) {
                statusFilterButton(
                    title: "Todos",
                    symbol:
                        "square.grid.2x2.fill",
                    status: nil
                )

                ForEach(ItemStatus.allCases) {
                    status in
                    statusFilterButton(
                        title: status.title,
                        symbol: status.symbol,
                        status: status
                    )
                }
            }
        }
        .accessibilityLabel(
            "Filtro por situação"
        )
    }

    private var categoryFilters: some View {
        ScrollView(
            .horizontal,
            showsIndicators: false
        ) {
            HStack(spacing: 8) {
                categoryFilterButton(
                    title: "Categorias",
                    symbol: "tag.fill",
                    category: nil
                )

                ForEach(ItemCategory.allCases) {
                    category in
                    categoryFilterButton(
                        title: category.title,
                        symbol: category.symbol,
                        category: category
                    )
                }
            }
        }
        .accessibilityLabel(
            "Filtro por categoria"
        )
    }

    private func statusFilterButton(
        title: String,
        symbol: String,
        status: ItemStatus?
    ) -> some View {
        filterButton(
            title: title,
            symbol: symbol,
            isSelected:
                selectedStatus == status
        ) {
            withAnimation(
                .easeInOut(duration: 0.18)
            ) {
                selectedStatus = status
            }
        }
    }

    private func categoryFilterButton(
        title: String,
        symbol: String,
        category: ItemCategory?
    ) -> some View {
        filterButton(
            title: title,
            symbol: symbol,
            isSelected:
                selectedCategory == category
        ) {
            withAnimation(
                .easeInOut(duration: 0.18)
            ) {
                selectedCategory = category
            }
        }
    }

    private func filterButton(
        title: String,
        symbol: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(
                title,
                systemImage: symbol
            )
            .font(.caption.weight(.semibold))
            .foregroundStyle(
                isSelected
                    ? Color.white
                    : Color.secondary
            )
            .padding(.horizontal, 13)
            .padding(.vertical, 9)
            .background(
                isSelected
                    ? AppStyle.mintStrong
                    : AppStyle.surface(
                        colorScheme
                    ),
                in: Capsule()
            )
            .overlay {
                if !isSelected {
                    Capsule()
                        .stroke(
                            AppStyle.border(
                                colorScheme
                            ),
                            lineWidth: 1
                        )
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var resultInformation: some View {
        HStack {
            Text("Itens acompanhados")
                .font(.headline)

            Spacer()

            Text(
                "\(visibleItems.count) de \(items.count)"
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var content: some View {
        if items.isEmpty {
            emptyState(
                title: "Suas compras ganham contexto",
                description:
                    "Cadastre um item para descobrir seu custo por dia ou por uso."
            )
        } else if visibleItems.isEmpty {
            emptyState(
                title: "Nenhum item encontrado",
                description:
                    "Altere a busca ou os filtros para ver outros itens."
            )
        } else {
            LazyVStack(spacing: 12) {
                ForEach(visibleItems) { item in
                    NavigationLink {
                        TrackedItemDetailView(
                            item: item
                        )
                    } label: {
                        TrackedItemCard(
                            item: item
                        )
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(
                            role: .destructive
                        ) {
                            pendingDeletion = item
                        } label: {
                            Label(
                                "Excluir item",
                                systemImage: "trash"
                            )
                        }
                    }
                }
            }
        }
    }

    private func emptyState(
        title: String,
        description: String
    ) -> some View {
        VStack(spacing: 14) {
            BrandLogo(
                variant: .playful,
                size: 150
            )

            Text(title)
                .font(.title3.bold())
                .multilineTextAlignment(.center)

            Text(description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(
            maxWidth: .infinity,
            minHeight: 330
        )
        .padding(.horizontal, 24)
    }

    private func delete(
        _ item: TrackedItem
    ) {
        let imageIdentifier =
            item.imageIdentifier
        modelContext.delete(item)

        do {
            try modelContext.save()
            AppImageReferenceService
                .deleteIfUnreferenced(
                    identifier:
                        imageIdentifier,
                    in: modelContext
                )
        } catch {
            modelContext.rollback()
            operationError =
                error.localizedDescription
        }
    }
}
