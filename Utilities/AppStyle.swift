import SwiftUI

enum AppStyle {
    static let mint = Color(
        red: 0.12,
        green: 0.75,
        blue: 0.51
    )

    static let mintStrong = Color(
        red: 0.04,
        green: 0.48,
        blue: 0.31
    )

    static let cream = Color(
        red: 0.965,
        green: 0.957,
        blue: 0.933
    )

    static let pink = Color(
        red: 0.95,
        green: 0.57,
        blue: 0.67
    )

    static let pinkStrong = Color(
        red: 0.66,
        green: 0.16,
        blue: 0.31
    )

    static let gold = Color(
        red: 1.00,
        green: 0.73,
        blue: 0.08
    )

    static let cardRadius: CGFloat = 18
    static let heroRadius: CGFloat = 24
    static let controlRadius: CGFloat = 14

    static func background(
        _ colorScheme: ColorScheme
    ) -> Color {
        colorScheme == .dark
            ? Color(.systemBackground)
            : cream
    }

    static func surface(
        _ colorScheme: ColorScheme
    ) -> Color {
        colorScheme == .dark
            ? Color(.secondarySystemBackground)
            : .white
    }

    static func accentForeground(
        _ colorScheme: ColorScheme
    ) -> Color {
        colorScheme == .dark
            ? mint
            : mintStrong
    }

    static func warningForeground(
        _ colorScheme: ColorScheme
    ) -> Color {
        colorScheme == .dark
            ? pink
            : pinkStrong
    }

    static func border(
        _ colorScheme: ColorScheme
    ) -> Color {
        colorScheme == .dark
            ? Color.white.opacity(0.09)
            : Color.black.opacity(0.08)
    }

    static func shadow(
        _ colorScheme: ColorScheme
    ) -> Color {
        colorScheme == .dark
            ? Color.black.opacity(0.28)
            : Color.black.opacity(0.07)
    }
}

extension View {
    func appCard(
        colorScheme: ColorScheme,
        padding: CGFloat = 16,
        cornerRadius: CGFloat = AppStyle.cardRadius
    ) -> some View {
        self
            .padding(padding)
            .background(
                AppStyle.surface(colorScheme),
                in: RoundedRectangle(
                    cornerRadius: cornerRadius,
                    style: .continuous
                )
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: cornerRadius,
                    style: .continuous
                )
                .stroke(
                    AppStyle.border(colorScheme),
                    lineWidth: 1
                )
            }
            .shadow(
                color: AppStyle.shadow(colorScheme),
                radius: 8,
                y: 3
            )
    }

    func editorialTitle() -> some View {
        font(
            .system(
                .largeTitle,
                design: .rounded,
                weight: .semibold
            )
        )
        .tracking(-1)
    }
}
