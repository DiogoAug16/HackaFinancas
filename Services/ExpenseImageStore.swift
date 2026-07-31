import Foundation
import ImageIO

final class ExpenseImageStore: @unchecked Sendable {
    static let shared = ExpenseImageStore()

    private let fileManager: FileManager
    private let cache = NSCache<NSString, NSData>()
    private let accessLock = NSLock()
    private static let directoryName = "ExpenseImages"
    private let directoryURL: URL?

    private init(
        fileManager: FileManager = .default
    ) {
        self.fileManager = fileManager

        if let applicationSupportURL =
            try? fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            ) {
            let imageDirectoryURL =
                applicationSupportURL
                .appendingPathComponent(
                    Self.directoryName,
                    isDirectory: true
                )

            do {
                try fileManager.createDirectory(
                    at: imageDirectoryURL,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
                directoryURL = imageDirectoryURL
            } catch {
                directoryURL = nil
            }
        } else {
            directoryURL = nil
        }

        cache.countLimit = 80
        cache.totalCostLimit = 24 * 1_024 * 1_024
    }

    func save(
        _ data: Data
    ) throws -> String {
        guard let directoryURL else {
            throw ExpenseImageStoreError
                .directoryUnavailable
        }

        accessLock.lock()
        defer {
            accessLock.unlock()
        }

        let identifier = UUID().uuidString
        let fileURL = directoryURL
            .appendingPathComponent(identifier)
            .appendingPathExtension("jpg")

        try data.write(
            to: fileURL,
            options: .atomic
        )
        cache.setObject(
            NSData(data: data),
            forKey: identifier as NSString,
            cost: data.count
        )

        return identifier
    }

    func data(
        for identifier: String?
    ) -> Data? {
        guard
            let identifier,
            !identifier.isEmpty,
            let directoryURL
        else {
            return nil
        }

        accessLock.lock()
        defer {
            accessLock.unlock()
        }

        let cacheKey = identifier as NSString

        if let cachedData = cache.object(
            forKey: cacheKey
        ) {
            return Data(referencing: cachedData)
        }

        let fileURL = directoryURL
            .appendingPathComponent(identifier)
            .appendingPathExtension("jpg")

        guard let data = try? Data(
            contentsOf: fileURL,
            options: .mappedIfSafe
        ) else {
            return nil
        }

        cache.setObject(
            NSData(data: data),
            forKey: cacheKey,
            cost: data.count
        )

        return data
    }

    func loadData(
        for identifier: String?
    ) async -> Data? {
        let loadTask = Task.detached(
            priority: .utility
        ) { [self] () -> Data? in
            guard !Task.isCancelled else {
                return nil
            }

            return data(for: identifier)
        }

        return await withTaskCancellationHandler(
            operation: {
                await loadTask.value
            },
            onCancel: {
                loadTask.cancel()
            }
        )
    }

    func delete(
        _ identifier: String?
    ) {
        guard
            let identifier,
            !identifier.isEmpty,
            let directoryURL
        else {
            return
        }

        accessLock.lock()
        defer {
            accessLock.unlock()
        }

        cache.removeObject(
            forKey: identifier as NSString
        )

        let fileURL = directoryURL
            .appendingPathComponent(identifier)
            .appendingPathExtension("jpg")

        try? fileManager.removeItem(
            at: fileURL
        )
    }
}

enum ExpenseImageStoreError: LocalizedError {
    case directoryUnavailable

    var errorDescription: String? {
        switch self {
        case .directoryUnavailable:
            return "Não foi possível preparar o armazenamento da imagem."
        }
    }
}

enum ExpenseImageProcessor {
    static func prepareForStorage(
        _ data: Data
    ) -> Data? {
        let thumbnailOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways:
                true,
            kCGImageSourceCreateThumbnailWithTransform:
                true,
            kCGImageSourceThumbnailMaxPixelSize:
                1_200
        ]

        guard
            let source = CGImageSourceCreateWithData(
                data as CFData,
                nil
            ),
            let thumbnail =
                CGImageSourceCreateThumbnailAtIndex(
                    source,
                    0,
                    thumbnailOptions as CFDictionary
                )
        else {
            return nil
        }

        let outputData = NSMutableData()

        guard let destination =
            CGImageDestinationCreateWithData(
                outputData as CFMutableData,
                "public.jpeg" as CFString,
                1,
                nil
            )
        else {
            return nil
        }

        let destinationOptions: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality:
                0.82
        ]

        CGImageDestinationAddImage(
            destination,
            thumbnail,
            destinationOptions as CFDictionary
        )

        guard CGImageDestinationFinalize(
            destination
        ) else {
            return nil
        }

        return Data(referencing: outputData)
    }
}
