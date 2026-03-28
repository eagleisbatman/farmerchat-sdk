import XCTest
@testable import FarmerChatUIKit

@MainActor
final class FarmerChatUIKitTests: XCTestCase {
    func testInitialization() {
        let fc = FarmerChat.shared
        XCTAssertFalse(fc.isInitialized)
        fc.initialize(config: FarmerChatConfig(apiKey: "test_key"))
        XCTAssertTrue(fc.isInitialized)
        // Cleanup for next test run
        fc.destroy()
        XCTAssertFalse(fc.isInitialized)
    }

    func testSessionIdGeneration() {
        let fc = FarmerChat.shared
        fc.initialize(config: FarmerChatConfig(apiKey: "test_key"))
        let sessionId = fc.getSessionId()
        XCTAssertFalse(sessionId.isEmpty)
        fc.destroy()
    }

    func testCustomSessionId() {
        let fc = FarmerChat.shared
        fc.initialize(config: FarmerChatConfig(apiKey: "test_key", sessionId: "custom-123"))
        XCTAssertEqual(fc.getSessionId(), "custom-123")
        fc.destroy()
    }

    func testSSEParserBasic() {
        let parser = SSEParser()
        XCTAssertNil(parser.feed(line: "event: token"))
        XCTAssertNil(parser.feed(line: "data: {\"text\":\"hello\"}"))
        let event = parser.feed(line: "")
        XCTAssertNotNil(event)
        XCTAssertEqual(event?.event, "token")
        XCTAssertEqual(event?.data, "{\"text\":\"hello\"}")
    }

    func testSSEParserFlush() {
        let parser = SSEParser()
        _ = parser.feed(line: "event: done")
        _ = parser.feed(line: "data: {}")
        let event = parser.flush()
        XCTAssertNotNil(event)
        XCTAssertEqual(event?.event, "done")
    }

    func testQueryRequestSerialization() throws {
        let request = QueryRequest(text: "hello", inputMethod: "text", language: "en")
        let data = try request.toJsonData()
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(json?["text"] as? String, "hello")
        XCTAssertEqual(json?["input_method"] as? String, "text")
        XCTAssertEqual(json?["language"] as? String, "en")
    }

    func testFeedbackRequestSerialization() throws {
        let request = FeedbackRequest(responseId: "r1", rating: "positive", comment: "great")
        let data = try request.toJsonData()
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(json?["response_id"] as? String, "r1")
        XCTAssertEqual(json?["rating"] as? String, "positive")
        XCTAssertEqual(json?["comment"] as? String, "great")
    }
}
