import SwiftUI

struct UFMTSignature: View {
    var body: some View {
        Image("ufmtlogo")
            .resizable()
            .scaledToFit()
            .frame(width: 14, height: 14)
            .padding(3)
            .background(Color.white, in: Circle())
            .overlay {
                Circle()
                    .stroke(
                        Color.black.opacity(0.08),
                        lineWidth: 0.5
                    )
            }
            .accessibilityLabel(
                "Universidade Federal de Mato Grosso"
            )
    }
}

struct HackaTruckLogo: View {
    var body: some View {
        Image("hacka-logo")
            .resizable()
            .scaledToFit()
            .frame(maxWidth: 230)
            .frame(height: 62)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Color.white,
                in: RoundedRectangle(
                    cornerRadius: 14,
                    style: .continuous
                )
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: 14,
                    style: .continuous
                )
                .stroke(
                    Color.black.opacity(0.08),
                    lineWidth: 1
                )
            }
            .accessibilityLabel(
                "HackaTruck Maker Space"
            )
    }
}
