import SwiftUI

struct AppHeader: View {
    @Environment(\.colorScheme) private var colorScheme

    let title: String
    let subtitle: String
    let onSettings: () -> Void

    var body: some View {
        HStack(spacing: 13) {
            BrandLogo(
                variant: .main,
                size: 58
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .editorialTitle()
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                HStack(spacing: 6) {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .layoutPriority(1)

                    UFMTSignature()
                }
            }

            Spacer(minLength: 8)

            Button(action: onSettings) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(
                        AppStyle.accentForeground(
                            colorScheme
                        )
                    )
                    .frame(width: 44, height: 44)
                    .background(
                        AppStyle.mint.opacity(0.12),
                        in: RoundedRectangle(
                            cornerRadius: 13,
                            style: .continuous
                        )
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Abrir configurações")
        }
        .padding(.top, 8)
    }
}
