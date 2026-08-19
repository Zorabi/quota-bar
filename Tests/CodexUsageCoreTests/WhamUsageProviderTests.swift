import XCTest
@testable import CodexUsageCore

final class WhamUsageProviderTests: XCTestCase {
    func testSuccessStatusCodesReturnNil() {
        XCTAssertNil(WhamUsageProvider.classify(statusCode: 200))
        XCTAssertNil(WhamUsageProvider.classify(statusCode: 204))
    }

    func testUnauthorizedStatusCodes() {
        XCTAssertEqual(WhamUsageProvider.classify(statusCode: 401), .unauthorized)
        XCTAssertEqual(WhamUsageProvider.classify(statusCode: 403), .unauthorized)
    }

    func testOtherStatusCodesMapToNetworkError() {
        XCTAssertEqual(WhamUsageProvider.classify(statusCode: 500), .network("HTTP 500"))
        XCTAssertEqual(WhamUsageProvider.classify(statusCode: 429), .network("HTTP 429"))
    }
}
