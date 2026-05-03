import Foundation
import SwiftData
import XCTest
@testable import DictateOSS

final class TestDefaults: UserDefaultsProviding {
    private var store: [String: Any] = [:]

    func object(forKey defaultName: String) -> Any? { store[defaultName] }
    func set(_ value: Any?, forKey defaultName: String) { store[defaultName] = value }
    func removeObject(forKey defaultName: String) { store.removeValue(forKey: defaultName) }
    func string(forKey defaultName: String) -> String? { store[defaultName] as? String }
    func bool(forKey defaultName: String) -> Bool { store[defaultName] as? Bool ?? false }
    func integer(forKey defaultName: String) -> Int { store[defaultName] as? Int ?? 0 }
    func float(forKey defaultName: String) -> Float { store[defaultName] as? Float ?? 0 }
    func double(forKey defaultName: String) -> Double { store[defaultName] as? Double ?? 0 }
    func data(forKey defaultName: String) -> Data? { store[defaultName] as? Data }
    @discardableResult func synchronize() -> Bool { true }
}

func makeTestModelContext() throws -> ModelContext {
    let schema = Schema([TranscriptionRecord.self, ReplacementRule.self, DictionaryEntry.self])
    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [config])
    return ModelContext(container)
}

final class MockURLProtocol: URLProtocol {
    struct Stub {
        let statusCode: Int
        let data: Data
        let headers: [String: String]
    }

    nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> Stub)?
    nonisolated(unsafe) static var lastRequest: URLRequest?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        do {
            Self.lastRequest = request
            guard let handler = Self.requestHandler else {
                throw NSError(domain: "MockURLProtocol", code: 1)
            }
            let stub = try handler(request)
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: stub.statusCode,
                httpVersion: nil,
                headerFields: stub.headers
            )!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: stub.data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}

    static func makeSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }

    static func reset() {
        requestHandler = nil
        lastRequest = nil
    }
}

extension URLRequest {
    var testBodyData: Data? {
        if let httpBody {
            return httpBody
        }
        guard let httpBodyStream else {
            return nil
        }

        httpBodyStream.open()
        defer { httpBodyStream.close() }

        var data = Data()
        let bufferSize = 1_024
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }

        while httpBodyStream.hasBytesAvailable {
            let read = httpBodyStream.read(buffer, maxLength: bufferSize)
            if read < 0 {
                return nil
            }
            if read == 0 {
                break
            }
            data.append(buffer, count: read)
        }
        return data
    }
}

func makeTempAudioURL() -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("dictate-oss-test-\(UUID().uuidString).m4a")
    FileManager.default.createFile(atPath: url.path, contents: Data("audio".utf8))
    return url
}
