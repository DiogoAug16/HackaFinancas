import XCTest
@testable import HackaFinancas

final class HackaFinancasTests: XCTestCase {
    func testAppModuleLoads() {
        XCTAssertTrue(true)
    }

    @MainActor
    func testCloudantDocumentRoundTrip() throws {
        let document = CloudantDocument(
            id: "expense-1",
            revision: "1-a",
            type: "expense",
            data: "{\"categoryRawValue\":\"Alimentação\"}"
        )

        let decoded = try JSONDecoder().decode(
            CloudantDocument.self,
            from: JSONEncoder().encode(document)
        )

        XCTAssertEqual(decoded, document)
        XCTAssertEqual(CloudantStore.database, "hackafinancas")
    }
}
