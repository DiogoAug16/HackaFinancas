import Foundation
import SwiftUI
import UIKit

struct AppVisual: View {
    let imageData: Data?
    let imageIdentifier: String?
    let symbolName: String
    var size: CGFloat = 48
    var cornerRadius: CGFloat = 14
    var symbolForeground: Color = AppStyle.mint
    var symbolBackground: Color = AppStyle.mint.opacity(0.12)

    @State private var loadedImageData: Data?

    init(
        imageData: Data?,
        symbolName: String,
        size: CGFloat = 48,
        cornerRadius: CGFloat = 14,
        symbolForeground: Color = AppStyle.mint,
        symbolBackground: Color = AppStyle.mint.opacity(0.12)
    ) {
        self.imageData = imageData
        self.imageIdentifier = nil
        self.symbolName = symbolName
        self.size = size
        self.cornerRadius = cornerRadius
        self.symbolForeground = symbolForeground
        self.symbolBackground = symbolBackground
    }

    init(
        imageIdentifier: String?,
        symbolName: String,
        size: CGFloat = 48,
        cornerRadius: CGFloat = 14,
        symbolForeground: Color = AppStyle.mint,
        symbolBackground: Color = AppStyle.mint.opacity(0.12)
    ) {
        self.imageData = nil
        self.imageIdentifier = imageIdentifier
        self.symbolName = symbolName
        self.size = size
        self.cornerRadius = cornerRadius
        self.symbolForeground = symbolForeground
        self.symbolBackground = symbolBackground
    }

    var body: some View {
        let resolvedImage = image

        return Group {
            if let resolvedImage {
                Image(uiImage: resolvedImage)
                    .resizable()
                    .scaledToFill()
                    .accessibilityHidden(true)
            } else {
                Image(systemName: symbolName)
                    .font(
                        .system(
                            size: size * 0.38,
                            weight: .semibold
                        )
                    )
                    .foregroundStyle(symbolForeground)
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: .infinity
                    )
                    .background(symbolBackground)
                    .accessibilityHidden(true)
            }
        }
        .frame(width: size, height: size)
        .clipShape(
            RoundedRectangle(
                cornerRadius: cornerRadius,
                style: .continuous
            )
        )
        .overlay {
            if resolvedImage != nil {
                RoundedRectangle(
                    cornerRadius: cornerRadius,
                    style: .continuous
                )
                .stroke(
                    Color.white.opacity(0.24),
                    lineWidth: 1
                )
            }
        }
        .task(id: imageIdentifier) {
            loadedImageData = nil

            guard let imageIdentifier else {
                return
            }

            let data = await ExpenseImageStore
                .shared
                .loadData(
                    for: imageIdentifier
                )

            guard !Task.isCancelled else {
                return
            }

            loadedImageData = data
        }
    }

    private var image: UIImage? {
        guard let data = imageData ?? loadedImageData else {
            return nil
        }
        return UIImage(data: data)
    }
}

extension AppVisual {
    init(
        expense: Expense,
        size: CGFloat = 48,
        cornerRadius: CGFloat = 14,
        symbolForeground: Color = AppStyle.mint,
        symbolBackground: Color = AppStyle.mint.opacity(0.12)
    ) {
        self.init(
            imageIdentifier: expense.imageIdentifier,
            symbolName: expense.visualSymbol,
            size: size,
            cornerRadius: cornerRadius,
            symbolForeground: symbolForeground,
            symbolBackground: symbolBackground
        )
    }

    init(
        item: TrackedItem,
        size: CGFloat = 48,
        cornerRadius: CGFloat = 14,
        symbolForeground: Color = AppStyle.mint,
        symbolBackground: Color = AppStyle.mint.opacity(0.12)
    ) {
        self.init(
            imageIdentifier: item.imageIdentifier,
            symbolName: item.visualSymbol,
            size: size,
            cornerRadius: cornerRadius,
            symbolForeground: symbolForeground,
            symbolBackground: symbolBackground
        )
    }
}
