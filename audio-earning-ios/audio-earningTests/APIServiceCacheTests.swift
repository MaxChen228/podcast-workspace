import Foundation
import Testing
@testable import audio_earning

struct APIServiceCacheTests {
    @Test func isFileFreshHonorsTTL() throws {
        let service = APIService()
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent("cache-test-\(UUID().uuidString)", isDirectory: true)
        let fileURL = tempRoot.appendingPathComponent("sample.dat")

        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        try Data("data".utf8).write(to: fileURL)

        let sixtySecondsAgo = Date().addingTimeInterval(-60)
        try FileManager.default.setAttributes([
            .modificationDate: sixtySecondsAgo
        ], ofItemAtPath: fileURL.path)

        #expect(service.isFileFresh(at: fileURL, ttl: 120))
        #expect(service.isFileFresh(at: fileURL, ttl: 30) == false)

        try? FileManager.default.removeItem(at: tempRoot)
    }

    @Test func normalizedMediaURLConvertsGCScheme() throws {
        let gsURL = URL(string: "gs://storytelling-output/output/book/chapter/podcast.mp3")!
        let normalized = APIService.normalizedMediaURL(from: gsURL)
        #expect(normalized.scheme == "https")
        #expect(normalized.host == "storage.googleapis.com")
        #expect(normalized.path == "/storytelling-output/output/book/chapter/podcast.mp3")
    }

    @Test func downloadAudioResolvesPublicURL() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)
        let service = APIService(session: session)

        let apiURL = URL(string: "https://storytelling-backend-service-1034996974388.asia-east1.run.app/books/Foundation/chapters/chapter0/audio")!
        let gcsURL = URL(string: "https://storage.googleapis.com/storytelling-output/output/Foundation/chapter0/podcast.mp3")!

        MockURLProtocol.clear()
        MockURLProtocol.responder = { request in
            let method = request.httpMethod ?? "GET"
            if method == "HEAD" {
                let response = HTTPURLResponse(url: request.url!, statusCode: 405, httpVersion: nil, headerFields: [:])!
                return (response, Data())
            }

            if request.value(forHTTPHeaderField: "Range") != nil {
                let headers = [
                    "ETag": "\"abc\"",
                    "Content-Range": "bytes 0-0/1000"
                ]
                let response = HTTPURLResponse(url: gcsURL, statusCode: 206, httpVersion: nil, headerFields: headers)!
                return (response, Data([0]))
            }

            let headers = [
                "ETag": "\"abc\""
            ]
            let response = HTTPURLResponse(url: gcsURL, statusCode: 200, httpVersion: nil, headerFields: headers)!
            let payload = Data(repeating: 1, count: 4)
            return (response, payload)
        }

        let result = try await service.downloadAudio(from: apiURL)

        #expect(result.remoteURL == gcsURL)
        #expect(result.eTag == "\"abc\"")
        #expect(FileManager.default.fileExists(atPath: result.localURL.path))

        let metaPath = result.localURL.appendingPathExtension("etag")
        #expect((try? String(contentsOf: metaPath, encoding: .utf8)) == "\"abc\"")

        // Expect HEAD + range GET + full download
        #expect(MockURLProtocol.recordedRequests.count == 3)
        if let first = MockURLProtocol.recordedRequests.first {
            #expect(first.httpMethod == "HEAD")
        }
        if MockURLProtocol.recordedRequests.count >= 2 {
            #expect(MockURLProtocol.recordedRequests[1].value(forHTTPHeaderField: "Range") == "bytes=0-0")
        }

        // cleanup
        try? FileManager.default.removeItem(at: result.localURL)
        try? FileManager.default.removeItem(at: metaPath)
        MockURLProtocol.clear()
    }
}

final class MockURLProtocol: URLProtocol {
    typealias ResponseProvider = (URLRequest) throws -> (HTTPURLResponse, Data?)

    static var responder: ResponseProvider?
    static var recordedRequests: [URLRequest] = []

    static func clear() {
        responder = nil
        recordedRequests.removeAll()
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let responder = Self.responder else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        Self.recordedRequests.append(request)

        do {
            let (response, data) = try responder(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            if let data {
                client?.urlProtocol(self, didLoad: data)
            }
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
