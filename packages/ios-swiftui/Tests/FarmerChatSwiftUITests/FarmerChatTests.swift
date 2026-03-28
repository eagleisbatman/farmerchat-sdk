import XCTest
@testable import FarmerChatSwiftUI

@MainActor
final class FarmerChatTests: XCTestCase {

    override func tearDown() {
        super.tearDown()
        FarmerChat.shared.destroy()
    }

    func testInitializationWithConfig() {
        let fc = FarmerChat.shared
        XCTAssertFalse(fc.isInitialized)

        let config = FarmerChatConfig(apiKey: "test-key")
        fc.initialize(config: config)

        XCTAssertTrue(fc.isInitialized)
        XCTAssertNotNil(fc.apiClient)
        XCTAssertNotNil(fc.connectivityMonitor)
        XCTAssertNotNil(fc.chatViewModel)
    }

    func testInitializationIsIdempotent() {
        let fc = FarmerChat.shared
        let config1 = FarmerChatConfig(apiKey: "key-1")
        let config2 = FarmerChatConfig(apiKey: "key-2")

        fc.initialize(config: config1)
        fc.initialize(config: config2) // Should be a no-op

        // Config should still be the first one
        XCTAssertEqual(fc.config?.apiKey, "key-1")
    }

    func testDestroy() {
        let fc = FarmerChat.shared
        fc.initialize(config: FarmerChatConfig(apiKey: "test-key"))
        XCTAssertTrue(fc.isInitialized)

        fc.destroy()
        XCTAssertFalse(fc.isInitialized)
        XCTAssertNil(fc.apiClient)
        XCTAssertNil(fc.chatViewModel)
        XCTAssertNil(fc.config)
    }

    func testReinitializeAfterDestroy() {
        let fc = FarmerChat.shared
        fc.initialize(config: FarmerChatConfig(apiKey: "key-1"))
        fc.destroy()

        fc.initialize(config: FarmerChatConfig(apiKey: "key-2"))
        XCTAssertTrue(fc.isInitialized)
        XCTAssertEqual(fc.config?.apiKey, "key-2")
    }

    func testSessionIdGenerated() {
        let fc = FarmerChat.shared
        fc.initialize(config: FarmerChatConfig(apiKey: "test-key"))

        let sessionId = fc.getSessionId()
        XCTAssertFalse(sessionId.isEmpty)
    }

    func testCustomSessionId() {
        let fc = FarmerChat.shared
        var config = FarmerChatConfig(apiKey: "test-key")
        config.sessionId = "custom-session-123"
        fc.initialize(config: config)

        XCTAssertEqual(fc.getSessionId(), "custom-session-123")
    }
}
