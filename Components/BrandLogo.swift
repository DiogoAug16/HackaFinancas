import SwiftUI

struct BrandLogo: View {
    enum Variant {
        case main
        case playful
    }

    let variant: Variant
    var size: CGFloat = 64

    private var assetName: String {
        switch variant {
        case .main:
            return "PigLogo"

        case .playful:
            return "PigLogoFun"
        }
    }

    var body: some View {
        Image(assetName)
            .resizable()
            .scaledToFit()
            .frame(
                width: size,
                height: size
            )
            .accessibilityHidden(true)
    }
}