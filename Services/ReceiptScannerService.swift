import Foundation
import UIKit
import Vision

struct ScannedReceiptData {
    var detectedTitle: String
    var detectedAmountInCents: Int?
    var detectedDate: Date?
    var rawTextLines: [String]
    var qrCodeUrl: String?
    var extractedItems: [ScannedItem]
}

struct ScannedItem: Identifiable {
    let id = UUID()
    let name: String
    let amountInCents: Int
}

final class ReceiptScannerService {
    static let shared = ReceiptScannerService()

    private init() {}

    // Process image for OCR Text Recognition
    func processImageForOCR(_ image: UIImage, completion: @escaping (ScannedReceiptData) -> Void) {
        guard let cgImage = image.cgImage else {
            completion(ScannedReceiptData(detectedTitle: "", detectedAmountInCents: nil, detectedDate: nil, rawTextLines: [], qrCodeUrl: nil, extractedItems: []))
            return
        }

        let request = VNRecognizeTextRequest { request, error in
            guard let observations = request.results as? [VNRecognizedTextObservation], error == nil else {
                completion(ScannedReceiptData(detectedTitle: "", detectedAmountInCents: nil, detectedDate: nil, rawTextLines: [], qrCodeUrl: nil, extractedItems: []))
                return
            }

            let lines = observations.compactMap { $0.topCandidates(1).first?.string }
            let parsed = Self.parseReceiptText(lines)
            
            // Check for QR code in the same image
            let qrCode = Self.detectQRCodeInImage(image)
            var finalData = parsed
            finalData.qrCodeUrl = qrCode

            DispatchQueue.main.async {
                completion(finalData)
            }
        }

        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["pt-BR", "en-US"]

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            try? handler.perform([request])
        }
    }

    // Detect QR Code in UIImage using Vision
    static func detectQRCodeInImage(_ image: UIImage) -> String? {
        guard let cgImage = image.cgImage else { return nil }
        let request = VNDetectBarcodesRequest()
        request.symbologies = [.qr]

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform([request])

        if let results = request.results as? [VNBarcodeObservation], let first = results.first {
            return first.payloadStringValue
        }
        return nil
    }

    // Parse receipt text lines to extract Title, Total Amount, Date, and Items
    static func parseReceiptText(_ lines: [String]) -> ScannedReceiptData {
        var title = ""
        var amountInCents: Int? = nil
        var detectedDate: Date? = nil
        var items: [ScannedItem] = []

        let dateRegex = try? NSRegularExpression(pattern: #"(\d{2})[/.-](\d{2})[/.-](\d{2,4})"#)
        let amountRegex = try? NSRegularExpression(pattern: #"(?:R\$\s*)?(\d{1,4}(?:[.,]\d{3})*[.,]\d{2})"#)

        // Find title from top non-empty lines
        for line in lines.prefix(4) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty && !trimmed.lowercased().contains("cnpj") && !trimmed.lowercased().contains("nota") {
                title = trimmed
                break
            }
        }
        if title.isEmpty, let firstLine = lines.first {
            title = firstLine
        }

        // Parse lines for Total Amount & Dates
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            let lower = trimmed.lowercased()

            // Look for total
            if (lower.contains("total") || lower.contains("valor") || lower.contains("pago") || lower.contains("r$")) && amountInCents == nil {
                let nsString = trimmed as NSString
                if let match = amountRegex?.firstMatch(in: trimmed, options: [], range: NSRange(location: 0, length: nsString.length)) {
                    let matchStr = nsString.substring(with: match.range(at: 1))
                    amountInCents = parseAmountString(matchStr)
                }
            }

            // Look for date
            if detectedDate == nil {
                let nsString = trimmed as NSString
                if let match = dateRegex?.firstMatch(in: trimmed, options: [], range: NSRange(location: 0, length: nsString.length)) {
                    let dayStr = nsString.substring(with: match.range(at: 1))
                    let monthStr = nsString.substring(with: match.range(at: 2))
                    let yearStr = nsString.substring(with: match.range(at: 3))

                    var year = Int(yearStr) ?? 2026
                    if year < 100 { year += 2000 }
                    if let day = Int(dayStr), let month = Int(monthStr) {
                        var components = DateComponents()
                        components.day = day
                        components.month = month
                        components.year = year
                        detectedDate = Calendar.current.date(from: components)
                    }
                }
            }

            // Extract item lines (format: NAME 12,90 or 1 x NAME 12.90)
            if let cents = extractLineAmount(trimmed), cents > 0, !lower.contains("total"), !lower.contains("troco"), !lower.contains("subtotal") {
                let namePart = trimmed.replacingOccurrences(of: #"[0-9]+[.,][0-9]{2}"#, with: "", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !namePart.isEmpty && namePart.count > 2 {
                    items.append(ScannedItem(name: namePart, amountInCents: cents))
                }
            }
        }

        // Fallback amount check if "total" keyword line wasn't found
        if amountInCents == nil {
            var highestCents = 0
            for line in lines {
                if let cents = extractLineAmount(line) {
                    if cents > highestCents {
                        highestCents = cents
                    }
                }
            }
            if highestCents > 0 {
                amountInCents = highestCents
            }
        }

        return ScannedReceiptData(
            detectedTitle: title.isEmpty ? "Cupom Fiscal / Recibo" : title,
            detectedAmountInCents: amountInCents,
            detectedDate: detectedDate ?? Date(),
            rawTextLines: lines,
            qrCodeUrl: nil,
            extractedItems: items
        )
    }

    private static func extractLineAmount(_ text: String) -> Int? {
        let pattern = #"(\d{1,4}[.,]\d{2})"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let nsString = text as NSString
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length))
        guard let lastMatch = matches.last else { return nil }
        let matchStr = nsString.substring(with: lastMatch.range(at: 1))
        return parseAmountString(matchStr)
    }

    private static func parseAmountString(_ rawStr: String) -> Int? {
        var clean = rawStr.replacingOccurrences(of: "R$", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        clean = clean.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
        if let doubleVal = Double(clean) {
            return Int((doubleVal * 100).rounded())
        }
        return nil
    }

    // Simulate Parsing NFC-e / SAT QR Code URL
    static func parseNFCeQRCode(_ qrCodeString: String) -> ScannedReceiptData {
        // Sample NFC-e URL parser
        let isNFCe = qrCodeString.contains("sefaz") || qrCodeString.contains("nfce") || qrCodeString.contains("sat") || qrCodeString.contains("fazenda") || qrCodeString.contains("http")
        
        let dummyTitle = isNFCe ? "Nota Fiscal Eletrônica (NFC-e)" : "Cupom Fiscal QR Code"
        
        // Extract random/sample items typical of NFC-e if URL provided
        let sampleItems = [
            ScannedItem(name: "Item Cupom 1", amountInCents: 1590),
            ScannedItem(name: "Item Cupom 2", amountInCents: 850),
            ScannedItem(name: "Item Cupom 3", amountInCents: 3200)
        ]
        let total = sampleItems.reduce(0) { $0 + $1.amountInCents }

        return ScannedReceiptData(
            detectedTitle: dummyTitle,
            detectedAmountInCents: total,
            detectedDate: Date(),
            rawTextLines: [qrCodeString],
            qrCodeUrl: qrCodeString,
            extractedItems: sampleItems
        )
    }
}
