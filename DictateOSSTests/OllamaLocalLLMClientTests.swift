import XCTest
@testable import DictateOSS

final class OllamaLocalLLMClientTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    func testCompleteSendsNonStreamingChatPayload() async throws {
        MockURLProtocol.requestHandler = { request in
            let body = try XCTUnwrap(request.testBodyData)
            let json = try JSONSerialization.jsonObject(with: body) as? [String: Any]

            XCTAssertEqual(request.url?.path, "/api/chat")
            XCTAssertEqual(json?["model"] as? String, "qwen2.5:3b")
            XCTAssertEqual(json?["stream"] as? Bool, false)
            let messages = try XCTUnwrap(json?["messages"] as? [[String: String]])
            XCTAssertEqual(messages.first?["role"], "system")
            XCTAssertEqual(messages.last?["role"], "user")
            XCTAssertTrue(messages.last?["content"]?.contains("<transcription>") == true)

            return MockURLProtocol.Stub(
                statusCode: 200,
                data: #"{"message":{"role":"assistant","content":"Texto formatado."}}"#.data(using: .utf8)!,
                headers: ["Content-Type": "application/json"]
            )
        }

        let client = OllamaLocalLLMClient(session: MockURLProtocol.makeSession())
        let result = try await client.complete(
            systemPrompt: "system",
            userText: "texto cru",
            configuration: .default
        )

        XCTAssertEqual(result, "Texto formatado.")
    }

    func testInstalledModelsDecodesTagsResponse() async throws {
        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.path, "/api/tags")
            return MockURLProtocol.Stub(
                statusCode: 200,
                data: #"{"models":[{"name":"z-model"},{"name":"a-model"}]}"#.data(using: .utf8)!,
                headers: ["Content-Type": "application/json"]
            )
        }

        let client = OllamaLocalLLMClient(session: MockURLProtocol.makeSession())
        let result = try await client.installedModels(configuration: .default)

        XCTAssertEqual(result, ["a-model", "z-model"])
    }

    func testInvalidJSONThrowsDecodingFailed() async {
        MockURLProtocol.requestHandler = { _ in
            MockURLProtocol.Stub(
                statusCode: 200,
                data: Data("not json".utf8),
                headers: ["Content-Type": "application/json"]
            )
        }

        let client = OllamaLocalLLMClient(session: MockURLProtocol.makeSession())

        do {
            _ = try await client.complete(systemPrompt: "system", userText: "raw", configuration: .default)
            XCTFail("Expected decoding failure")
        } catch {
            XCTAssertEqual(error as? OllamaLocalLLMError, .decodingFailed)
        }
    }

    func testRequestUsesConfiguredTimeout() async throws {
        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.timeoutInterval, 7)
            return MockURLProtocol.Stub(
                statusCode: 200,
                data: #"{"message":{"role":"assistant","content":"ok"}}"#.data(using: .utf8)!,
                headers: ["Content-Type": "application/json"]
            )
        }

        var config = LocalLLMConfiguration.default
        config.timeoutSeconds = 7
        let client = OllamaLocalLLMClient(session: MockURLProtocol.makeSession())

        _ = try await client.complete(systemPrompt: "system", userText: "raw", configuration: config)
    }

    func testRemoteEndpointIsRejected() async {
        let client = OllamaLocalLLMClient(session: MockURLProtocol.makeSession())
        var config = LocalLLMConfiguration.default
        config.endpoint = "https://example.com"

        do {
            _ = try await client.installedModels(configuration: config)
            XCTFail("Expected remote endpoint rejection")
        } catch {
            XCTAssertEqual(error as? OllamaLocalLLMError, .remoteEndpointNotAllowed)
        }
    }

    func testHTTPErrorIncludesStatus() async {
        MockURLProtocol.requestHandler = { _ in
            MockURLProtocol.Stub(
                statusCode: 500,
                data: #"{"error":"boom"}"#.data(using: .utf8)!,
                headers: ["Content-Type": "application/json"]
            )
        }

        let client = OllamaLocalLLMClient(session: MockURLProtocol.makeSession())

        do {
            _ = try await client.complete(systemPrompt: "system", userText: "raw", configuration: .default)
            XCTFail("Expected HTTP error")
        } catch let error as OllamaLocalLLMError {
            guard case .httpError(let status, _) = error else {
                return XCTFail("Expected httpError")
            }
            XCTAssertEqual(status, 500)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
