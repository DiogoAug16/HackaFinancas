import Foundation
import PhotosUI
import SwiftUI

struct ExpenseVisualPicker: View {
    private enum RepresentationMode: String, CaseIterable, Identifiable {
        case symbol
        case photo

        var id: String {
            rawValue
        }

        var title: String {
            switch self {
            case .symbol:
                return "Ícone"
            case .photo:
                return "Imagem"
            }
        }
    }

    @Binding private var customSymbolName: String?
    @Binding private var imageData: Data?
    @Binding private var isProcessingPhoto: Bool

    let category: ExpenseCategory
    let onRepresentationChange: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    @State private var mode: RepresentationMode
    @State private var photoItem: PhotosPickerItem?
    @State private var photoImportTask:
        Task<Void, Never>?
    @State private var photoImportGeneration =
        UUID()
    @State private var importError: String?

    private let columns = Array(
        repeating: GridItem(
            .flexible(),
            spacing: 8
        ),
        count: 5
    )

    private let symbols = [
        "banknote.fill",
        "creditcard.fill",
        "cart.fill",
        "bag.fill",
        "house.fill",
        "car.fill",
        "fuelpump.fill",
        "fork.knife",
        "cross.case.fill",
        "graduationcap.fill",
        "gamecontroller.fill",
        "airplane",
        "gift.fill",
        "pawprint.fill",
        "iphone",
        "bolt.fill",
        "drop.fill",
        "wifi",
        "repeat.circle.fill",
        "square.grid.2x2.fill"
    ]

    init(
        customSymbolName: Binding<String?>,
        imageData: Binding<Data?>,
        isProcessingPhoto: Binding<Bool>,
        category: ExpenseCategory,
        onRepresentationChange:
            @escaping () -> Void = {}
    ) {
        _customSymbolName = customSymbolName
        _imageData = imageData
        _isProcessingPhoto = isProcessingPhoto
        self.category = category
        self.onRepresentationChange =
            onRepresentationChange
        _mode = State(
            initialValue: imageData.wrappedValue == nil
                ? .symbol
                : .photo
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Picker(
                "Representação",
                selection: $mode
            ) {
                ForEach(
                    RepresentationMode.allCases
                ) { mode in
                    Text(mode.title)
                        .tag(mode)
                }
            }
            .pickerStyle(.segmented)

            switch mode {
            case .symbol:
                symbolPicker

            case .photo:
                photoPicker
            }
        }
        .onChange(of: mode) { _, newMode in
            if newMode == .symbol {
                photoImportGeneration = UUID()
                photoImportTask?.cancel()
                onRepresentationChange()
                imageData = nil
                photoItem = nil
                isProcessingPhoto = false
            }
        }
        .onChange(of: photoItem) { _, newItem in
            guard let newItem else {
                return
            }

            let generation = UUID()
            photoImportGeneration = generation
            photoImportTask?.cancel()
            photoImportTask = Task {
                await importPhoto(
                    from: newItem,
                    generation: generation
                )
            }
        }
        .onDisappear {
            photoImportGeneration = UUID()
            photoImportTask?.cancel()
            isProcessingPhoto = false
        }
        .alert(
            "Não foi possível usar a imagem",
            isPresented: Binding(
                get: {
                    importError != nil
                },
                set: { isPresented in
                    if !isPresented {
                        importError = nil
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importError ?? "")
        }
    }

    private var symbolPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Use o ícone da categoria ou escolha outro.")
                .font(.caption)
                .foregroundStyle(.secondary)

            LazyVGrid(
                columns: columns,
                spacing: 8
            ) {
                symbolButton(
                    symbol: category.symbol,
                    customValue: nil,
                    accessibilityLabel: "Automático: \(category.rawValue)"
                )

                ForEach(symbols, id: \.self) { symbol in
                    symbolButton(
                        symbol: symbol,
                        customValue: symbol,
                        accessibilityLabel: "Usar ícone \(symbol)"
                    )
                }
            }
        }
    }

    private var photoPicker: some View {
        HStack(spacing: 14) {
            AppVisual(
                imageData: imageData,
                symbolName: customSymbolName
                    ?? category.symbol,
                size: 72,
                cornerRadius: 18
            )

            VStack(
                alignment: .leading,
                spacing: 9
            ) {
                PhotosPicker(
                    selection: $photoItem,
                    matching: .images
                ) {
                    Label(
                        imageData == nil
                            ? "Escolher imagem"
                            : "Trocar imagem",
                        systemImage: "photo.on.rectangle"
                    )
                }
                .disabled(isProcessingPhoto)

                if isProcessingPhoto {
                    ProgressView("Preparando imagem…")
                        .font(.caption)
                } else if imageData != nil {
                    Button(
                        "Remover imagem",
                        role: .destructive
                    ) {
                        onRepresentationChange()
                        imageData = nil
                        photoItem = nil
                    }
                    .font(.caption.weight(.semibold))
                } else {
                    Text(
                        "Apenas a foto escolhida será acessada."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func symbolButton(
        symbol: String,
        customValue: String?,
        accessibilityLabel: String
    ) -> some View {
        let isSelected =
            customSymbolName == customValue

        return Button {
            onRepresentationChange()
            customSymbolName = customValue
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(
                    isSelected
                        ? Color.white
                        : AppStyle.accentForeground(
                            colorScheme
                        )
                )
                .frame(
                    maxWidth: .infinity,
                    minHeight: 44
                )
                .background(
                    isSelected
                        ? AppStyle.mintStrong
                        : AppStyle.mint.opacity(0.11),
                    in: RoundedRectangle(
                        cornerRadius: 12,
                        style: .continuous
                    )
                )
                .overlay(alignment: .topTrailing) {
                    if isSelected {
                        Image(
                            systemName: "checkmark.circle.fill"
                        )
                        .font(.caption2)
                        .foregroundStyle(.white)
                        .padding(4)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(
            isSelected
                ? .isSelected
                : []
        )
    }

    @MainActor
    private func importPhoto(
        from item: PhotosPickerItem,
        generation: UUID
    ) async {
        guard generation == photoImportGeneration else {
            return
        }

        isProcessingPhoto = true
        defer {
            if generation
                == photoImportGeneration {
                isProcessingPhoto = false
            }
        }

        do {
            guard let sourceData =
                try await item.loadTransferable(
                    type: Data.self
                )
            else {
                throw PhotoImportError.invalidImage
            }

            let processedData =
                await Task.detached(
                    priority: .userInitiated
                ) {
                    ExpenseImageProcessor
                        .prepareForStorage(
                            sourceData
                        )
                }
                .value

            guard !Task.isCancelled,
                  generation
                    == photoImportGeneration
            else {
                return
            }

            guard let processedData else {
                throw PhotoImportError.invalidImage
            }

            onRepresentationChange()
            imageData = processedData
        } catch {
            guard !Task.isCancelled,
                  generation
                    == photoImportGeneration
            else {
                return
            }

            photoItem = nil
            importError =
                "Escolha outra imagem e tente novamente."
        }
    }

}

private enum PhotoImportError: Error {
    case invalidImage
}
