import SwiftUI
import UIKit

struct ReceiptScannerView: View {
    enum ScanMode {
        case ocrPhoto
        case qrCode
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme

    let scanMode: ScanMode
    let onScannedExpense: (String, Int, Date, [ScannedItem]) -> Void

    @State private var selectedImage: UIImage?
    @State private var isShowingImagePicker = false
    @State private var isScanning = false
    @State private var scannedData: ScannedReceiptData?
    @State private var manualQrCodeInput = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if scanMode == .ocrPhoto {
                    ocrScannerSection
                } else {
                    qrCodeScannerSection
                }

                if let data = scannedData {
                    scannedResultsSection(data: data)
                }

                Spacer()
            }
            .padding(20)
            .background(AppStyle.background(colorScheme).ignoresSafeArea())
            .navigationTitle(scanMode == .ocrPhoto ? "Escanear Nota por Foto" : "Leitor QR Code Cupom")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $isShowingImagePicker) {
                ImagePickerView(image: $selectedImage) { img in
                    if let img {
                        processPhoto(img)
                    }
                }
            }
        }
    }

    private var ocrScannerSection: some View {
        VStack(spacing: 14) {
            Image(systemName: "doc.text.viewfinder")
                .font(.system(size: 48))
                .foregroundStyle(AppStyle.accentForeground(colorScheme))

            Text("Tire uma foto ou selecione da galeria um cupom fiscal ou nota para reconhecer o texto automaticamente.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                isShowingImagePicker = true
            } label: {
                Label("Selecionar Foto da Nota", systemImage: "photo.badge.plus")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(AppStyle.mintStrong, in: RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
        }
        .appCard(colorScheme: colorScheme)
    }

    private var qrCodeScannerSection: some View {
        VStack(spacing: 14) {
            Image(systemName: "qrcode.viewfinder")
                .font(.system(size: 48))
                .foregroundStyle(AppStyle.accentForeground(colorScheme))

            Text("Escanear QR Code da NFC-e / Cupom Fiscal")
                .font(.headline)

            Text("Selecione uma imagem com o QR Code ou cole a URL/dados do Cupom Fiscal abaixo.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                isShowingImagePicker = true
            } label: {
                Label("Escanear Imagem de QR Code", systemImage: "qrcode")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(AppStyle.mintStrong, in: RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)

            Divider()

            HStack {
                TextField("Ou cole o link do QR Code da NFC-e", text: $manualQrCodeInput)
                    .textFieldStyle(.roundedBorder)

                Button("Processar") {
                    if !manualQrCodeInput.isEmpty {
                        let parsed = ReceiptScannerService.parseNFCeQRCode(manualQrCodeInput)
                        scannedData = parsed
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .appCard(colorScheme: colorScheme)
    }

    private func scannedResultsSection(data: ScannedReceiptData) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Dados Detectados", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(AppStyle.accentForeground(colorScheme))

                Spacer()
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Descrição: \(data.detectedTitle)")
                    .font(.subheadline.bold())

                if let cents = data.detectedAmountInCents {
                    Text("Valor Total: \(cents.currencyText)")
                        .font(.title3.bold())
                        .foregroundStyle(AppStyle.accentForeground(colorScheme))
                }

                if let date = data.detectedDate {
                    Text("Data: \(date.formatted(.dateTime.day().month().year()))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if !data.extractedItems.isEmpty {
                Divider()

                Text("Itens do Cupom (\(data.extractedItems.count))")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)

                ForEach(data.extractedItems) { item in
                    HStack {
                        Text(item.name)
                            .font(.caption)
                        Spacer()
                        Text(item.amountInCents.currencyText)
                            .font(.caption.bold())
                    }
                }
            }

            Button {
                let amount = data.detectedAmountInCents ?? 0
                let title = data.detectedTitle
                let date = data.detectedDate ?? Date()
                onScannedExpense(title, amount, date, data.extractedItems)
                dismiss()
            } label: {
                Text("Usar Estes Dados no Cadastro")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(AppStyle.mintStrong, in: RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
        }
        .appCard(colorScheme: colorScheme)
    }

    private func processPhoto(_ image: UIImage) {
        isScanning = true
        ReceiptScannerService.shared.processImageForOCR(image) { data in
            isScanning = false
            scannedData = data
        }
    }
}

struct ImagePickerView: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    let onSelected: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePickerView

        init(_ parent: ImagePickerView) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            let selected = info[.originalImage] as? UIImage
            parent.image = selected
            parent.onSelected(selected)
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}
