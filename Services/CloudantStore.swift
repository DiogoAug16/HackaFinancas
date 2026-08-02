import Foundation
import SwiftData

struct CloudantDocument: Codable, Equatable {
    let id: String
    let revision: String?
    let type: String
    let data: String

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case revision = "_rev"
        case type
        case data
    }
}

struct CloudantDocumentList: Decodable {
    let documents: [CloudantDocument]
}

private struct CloudantWriteResult: Decodable {
    let id: String
    let rev: String
}

@MainActor
final class CloudantStore {
    static let shared = CloudantStore()
    static let database = "hackafinancas"
    static let defaultGatewayURL = "http://localhost:1880"

    private let session: URLSession
    private let defaults: UserDefaults

    init(
        session: URLSession = .shared,
        defaults: UserDefaults = .standard
    ) {
        self.session = session
        self.defaults = defaults
    }

    func reload(into modelContext: ModelContext) async throws {
        let documents = try await listDocuments()
        var expenses: [Expense] = []
        var incomeEntries: [IncomeEntry] = []
        var trackedItems: [TrackedItem] = []
        var usages: [(UsageRecord, UUID?)] = []

        for document in documents {
            switch document.type {
            case "expense":
                expenses.append(
                    try decode(ExpensePayload.self, from: document)
                        .model(revision: document.revision)
                )
            case "income":
                incomeEntries.append(
                    try decode(IncomePayload.self, from: document)
                        .model(revision: document.revision)
                )
            case "trackedItem":
                trackedItems.append(
                    try decode(TrackedItemPayload.self, from: document)
                        .model(revision: document.revision)
                )
            case "usage":
                let payload = try decode(UsagePayload.self, from: document)
                usages.append((payload.model(revision: document.revision), payload.itemID))
            default:
                continue
            }
        }

        try modelContext.delete(model: UsageRecord.self)
        try modelContext.delete(model: TrackedItem.self)
        try modelContext.delete(model: Expense.self)
        try modelContext.delete(model: IncomeEntry.self)

        for expense in expenses {
            modelContext.insert(expense)
        }
        for income in incomeEntries {
            modelContext.insert(income)
        }
        for item in trackedItems {
            modelContext.insert(item)
        }

        let itemsByID = Dictionary(
            uniqueKeysWithValues: trackedItems.map { ($0.id, $0) }
        )
        for (usage, itemID) in usages {
            usage.item = itemID.flatMap { itemsByID[$0] }
            modelContext.insert(usage)
        }

        try modelContext.save()
    }

    func save(_ expense: Expense) async throws {
        expense.cloudantRevision = try await write(
            id: expense.id,
            revision: expense.cloudantRevision,
            type: "expense",
            payload: ExpensePayload(expense)
        )
    }

    func save(_ income: IncomeEntry) async throws {
        income.cloudantRevision = try await write(
            id: income.id,
            revision: income.cloudantRevision,
            type: "income",
            payload: IncomePayload(income)
        )
    }

    func save(_ item: TrackedItem) async throws {
        item.cloudantRevision = try await write(
            id: item.id,
            revision: item.cloudantRevision,
            type: "trackedItem",
            payload: TrackedItemPayload(item)
        )
    }

    func save(_ usage: UsageRecord) async throws {
        usage.cloudantRevision = try await write(
            id: usage.id,
            revision: usage.cloudantRevision,
            type: "usage",
            payload: UsagePayload(usage)
        )
    }

    func delete(_ expense: Expense) async throws {
        try await delete(id: expense.id, revision: expense.cloudantRevision)
    }

    func delete(_ income: IncomeEntry) async throws {
        try await delete(id: income.id, revision: income.cloudantRevision)
    }

    func delete(_ item: TrackedItem) async throws {
        try await delete(id: item.id, revision: item.cloudantRevision)
    }

    func delete(_ usage: UsageRecord) async throws {
        try await delete(id: usage.id, revision: usage.cloudantRevision)
    }

    private func listDocuments() async throws -> [CloudantDocument] {
        // ponytail: gateway returns 200 documents; add offset pagination if this database grows past that.
        var components = URLComponents(url: try documentsURL(), resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "limit", value: "200")]
        let request = URLRequest(url: try validURL(components?.url))
        let (data, response) = try await session.data(for: request)
        try validate(response)
        return try decoder.decode(CloudantDocumentList.self, from: data).documents
    }

    private func write<Payload: Encodable>(
        id: UUID,
        revision: String?,
        type: String,
        payload: Payload
    ) async throws -> String {
        let payloadData = try encoder.encode(payload)
        let document = CloudantDocument(
            id: id.uuidString,
            revision: revision,
            type: type,
            data: String(decoding: payloadData, as: UTF8.self)
        )
        let isUpdate = revision != nil
        var request = URLRequest(
            url: isUpdate
                ? try documentsURL().appendingPathComponent(id.uuidString)
                : try documentsURL()
        )
        request.httpMethod = isUpdate ? "PUT" : "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(document)

        let (data, response) = try await session.data(for: request)
        try validate(response)
        return try decoder.decode(CloudantWriteResult.self, from: data).rev
    }

    private func delete(id: UUID, revision: String?) async throws {
        guard let revision else {
            throw CloudantStoreError.missingRevision
        }

        var components = URLComponents(
            url: try documentsURL().appendingPathComponent(id.uuidString),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [URLQueryItem(name: "rev", value: revision)]
        var request = URLRequest(url: try validURL(components?.url))
        request.httpMethod = "DELETE"

        let (_, response) = try await session.data(for: request)
        try validate(response)
    }

    private func documentsURL() throws -> URL {
        let rawURL = defaults.string(forKey: AppPreferenceKeys.cloudantGatewayURL)
            ?? Self.defaultGatewayURL
        guard
            let gatewayURL = URL(string: rawURL),
            ["http", "https"].contains(gatewayURL.scheme?.lowercased() ?? "")
        else {
            throw CloudantStoreError.invalidGatewayURL
        }

        return gatewayURL
            .appendingPathComponent("v1")
            .appendingPathComponent("databases")
            .appendingPathComponent(Self.database)
            .appendingPathComponent("documents")
    }

    private func validate(_ response: URLResponse) throws {
        guard let response = response as? HTTPURLResponse else {
            throw CloudantStoreError.invalidResponse
        }
        guard (200...299).contains(response.statusCode) else {
            throw CloudantStoreError.requestFailed(response.statusCode)
        }
    }

    private func validURL(_ url: URL?) throws -> URL {
        guard let url else {
            throw CloudantStoreError.invalidGatewayURL
        }
        return url
    }

    private func decode<Payload: Decodable>(
        _ type: Payload.Type,
        from document: CloudantDocument
    ) throws -> Payload {
        try decoder.decode(type, from: Data(document.data.utf8))
    }

    private var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

enum CloudantStoreError: LocalizedError {
    case invalidGatewayURL
    case invalidResponse
    case missingRevision
    case requestFailed(Int)

    var errorDescription: String? {
        switch self {
        case .invalidGatewayURL:
            "Configure uma URL válida para o gateway Cloudant."
        case .invalidResponse:
            "O gateway Cloudant retornou uma resposta inválida."
        case .missingRevision:
            "O documento ainda não foi carregado do Cloudant."
        case let .requestFailed(status):
            "O gateway Cloudant falhou (HTTP \(status))."
        }
    }
}

// ponytail: images travel inline; use Cloudant attachments if documents approach 1 MB.
private struct ExpensePayload: Codable {
    let id: UUID
    let title: String
    let amountInCents: Int
    let date: Date
    let categoryRawValue: String
    let notes: String
    let createdAt: Date
    let recurrenceRawValue: String?
    let seriesID: UUID?
    let endDate: Date?
    let customSymbolName: String?
    let imageData: Data?

    init(_ expense: Expense) {
        id = expense.id
        title = expense.title
        amountInCents = expense.amountInCents
        date = expense.date
        categoryRawValue = expense.categoryRawValue
        notes = expense.notes
        createdAt = expense.createdAt
        recurrenceRawValue = expense.recurrenceRawValue
        seriesID = expense.seriesID
        endDate = expense.endDate
        customSymbolName = expense.customSymbolName
        imageData = ExpenseImageStore.shared.data(for: expense.imageIdentifier)
    }

    func model(revision: String?) -> Expense {
        let expense = Expense(
            title: title,
            amountInCents: amountInCents,
            date: date,
            category: ExpenseCategory(rawValue: categoryRawValue) ?? .other,
            notes: notes,
            recurrence: FinancialRecurrence(rawValue: recurrenceRawValue ?? "") ?? .once,
            seriesID: seriesID,
            endDate: endDate,
            customSymbolName: customSymbolName,
            imageIdentifier: try? imageData.map { try ExpenseImageStore.shared.save($0) }
        )
        expense.id = id
        expense.createdAt = createdAt
        expense.recurrenceRawValue = recurrenceRawValue
        expense.cloudantRevision = revision
        return expense
    }
}

private struct IncomePayload: Codable {
    let id: UUID
    let title: String
    let amountInCents: Int
    let date: Date
    let categoryRawValue: String
    let notes: String
    let createdAt: Date
    let recurrenceRawValue: String?
    let seriesID: UUID?
    let endDate: Date?
    let receivedAt: Date?

    init(_ income: IncomeEntry) {
        id = income.id
        title = income.title
        amountInCents = income.amountInCents
        date = income.date
        categoryRawValue = income.categoryRawValue
        notes = income.notes
        createdAt = income.createdAt
        recurrenceRawValue = income.recurrenceRawValue
        seriesID = income.seriesID
        endDate = income.endDate
        receivedAt = income.receivedAt
    }

    func model(revision: String?) -> IncomeEntry {
        let income = IncomeEntry(
            title: title,
            amountInCents: amountInCents,
            date: date,
            category: IncomeCategory(rawValue: categoryRawValue) ?? .other,
            notes: notes,
            recurrence: FinancialRecurrence(rawValue: recurrenceRawValue ?? "") ?? .once,
            seriesID: seriesID,
            endDate: endDate,
            receivedAt: receivedAt
        )
        income.id = id
        income.createdAt = createdAt
        income.recurrenceRawValue = recurrenceRawValue
        income.cloudantRevision = revision
        return income
    }
}

private struct TrackedItemPayload: Codable {
    let id: UUID
    let name: String
    let acquisitionValueInCents: Int
    let acquiredAt: Date
    let categoryRawValue: String
    let notes: String
    let createdAt: Date
    let isGift: Bool
    let trackingModeRawValue: String
    let goalValueInCents: Int?
    let goalPeriodRawValue: String?
    let isFavorite: Bool
    let statusRawValue: String
    let retiredAt: Date?
    let resaleValueInCents: Int?
    let customSymbolName: String?
    let imageData: Data?
    let sourceExpenseID: UUID?

    init(_ item: TrackedItem) {
        id = item.id
        name = item.name
        acquisitionValueInCents = item.acquisitionValueInCents
        acquiredAt = item.acquiredAt
        categoryRawValue = item.categoryRawValue
        notes = item.notes
        createdAt = item.createdAt
        isGift = item.isGift
        trackingModeRawValue = item.trackingModeRawValue
        goalValueInCents = item.goalValueInCents
        goalPeriodRawValue = item.goalPeriodRawValue
        isFavorite = item.isFavorite
        statusRawValue = item.statusRawValue
        retiredAt = item.retiredAt
        resaleValueInCents = item.resaleValueInCents
        customSymbolName = item.customSymbolName
        imageData = ExpenseImageStore.shared.data(for: item.imageIdentifier)
        sourceExpenseID = item.sourceExpenseID
    }

    func model(revision: String?) -> TrackedItem {
        let item = TrackedItem(
            name: name,
            acquisitionValueInCents: acquisitionValueInCents,
            acquiredAt: acquiredAt,
            category: ItemCategory(rawValue: categoryRawValue) ?? .other,
            notes: notes,
            isGift: isGift,
            trackingMode: ItemTrackingMode(rawValue: trackingModeRawValue) ?? .time,
            goalValueInCents: goalValueInCents,
            goalPeriod: ItemCostPeriod(rawValue: goalPeriodRawValue ?? ""),
            isFavorite: isFavorite,
            status: ItemStatus(rawValue: statusRawValue) ?? .active,
            retiredAt: retiredAt,
            resaleValueInCents: resaleValueInCents,
            customSymbolName: customSymbolName,
            imageIdentifier: try? imageData.map { try ExpenseImageStore.shared.save($0) },
            sourceExpenseID: sourceExpenseID
        )
        item.id = id
        item.createdAt = createdAt
        item.cloudantRevision = revision
        return item
    }
}

private struct UsagePayload: Codable {
    let id: UUID
    let usedAt: Date
    let notes: String
    let createdAt: Date
    let itemID: UUID?

    init(_ usage: UsageRecord) {
        id = usage.id
        usedAt = usage.usedAt
        notes = usage.notes
        createdAt = usage.createdAt
        itemID = usage.item?.id
    }

    func model(revision: String?) -> UsageRecord {
        let usage = UsageRecord(usedAt: usedAt, notes: notes)
        usage.id = id
        usage.createdAt = createdAt
        usage.cloudantRevision = revision
        return usage
    }
}
