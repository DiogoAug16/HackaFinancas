import Foundation

//formatar o dinheiro para pt-br R$ (Atrás da grana meu amigo)
//https://www.youtube.com/watch?v=0Xdn8wkr6q0

extension Int {
    var currencyText: String {
        let value = Decimal(self) / 100

        return value.formatted(
            .currency(code: "BRL")
            .locale(Locale(identifier: "pt_BR"))
        )
    }
}

extension Date {
    var shortDateText: String {
        formatted(
            .dateTime
                .day()
                .month(.abbreviated)
                .locale(Locale(identifier: "pt_BR"))
        )
    }
}

enum CurrencyFormatter {
    static let amountFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.numberStyle = .decimal
        return formatter
    }()

    static let amountInputFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    static func parseAmount(_ text: String) -> Int? {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty,
              let number = amountFormatter.number(from: normalized) else {
            return nil
        }
        let cents = (number.doubleValue * 100).rounded()
        guard cents.isFinite, cents > 0, cents < Double(Int.max) else {
            return nil
        }
        return Int(cents)
    }

    static func amountInputText(from amountInCents: Int) -> String {
        amountInputFormatter.string(from: NSNumber(value: Double(amountInCents) / 100)) ?? ""
    }
}