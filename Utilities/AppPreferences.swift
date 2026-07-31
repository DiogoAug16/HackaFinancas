import SwiftUI

enum AppAppearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .system:
            return "Sistema"

        case .light:
            return "Claro"

        case .dark:
            return "Escuro"
        }
    }

    var symbol: String {
        switch self {
        case .system:
            return "circle.lefthalf.filled"

        case .light:
            return "sun.max.fill"

        case .dark:
            return "moon.fill"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil

        case .light:
            return .light

        case .dark:
            return .dark
        }
    }
}

enum AppPreferenceKeys {
    static let appearance = "preferences.appearance"
    static let defaultCategory = "preferences.defaultCategory"
    static let defaultRecurrence = "preferences.defaultRecurrence"
}
