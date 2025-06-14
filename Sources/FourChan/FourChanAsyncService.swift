import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct FourChanAsyncService {
    public static let shared = FourChanAsyncService()
    private let decoder = JSONDecoder()

    public init() {}

    private func fetchBytes(from url: URL, progress: ((Double) -> Void)?) async throws -> Data {
        final class Delegate: NSObject, URLSessionDataDelegate, @unchecked Sendable {
            var expected: Int64 = 0
            var received: Int64 = 0
            var data = Data()
            var progressHandler: ((Double) -> Void)?
            var continuation: CheckedContinuation<Data, Error>?

            func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
                expected = response.expectedContentLength
                completionHandler(.allow)
            }

            func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
                received += Int64(data.count)
                self.data.append(data)
                if expected > 0 {
                    progressHandler?(Double(received) / Double(expected))
                }
            }

            func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
                if let error = error {
                    continuation?.resume(throwing: error)
                } else {
                    progressHandler?(1.0)
                    continuation?.resume(returning: data)
                }
            }
        }

        let delegate = Delegate()
        delegate.progressHandler = progress
        let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data, Error>) in
            delegate.continuation = continuation
            session.dataTask(with: url).resume()
        }
    }

    private func decodeEndpoint<T: Decodable>(_ endpoint: FourChanAPIEndpoint,
                                             progress: ((Double) -> Void)?) async throws -> T {
        let url = endpoint.url()
        let data = try await fetchBytes(from: url, progress: progress)
        return try decoder.decode(T.self, from: data)
    }

    public func getBoards(progress: ((Double) -> Void)? = nil) async throws -> Boards {
        try await decodeEndpoint(.boards, progress: progress)
    }

    public func getCatalog(boardName: BoardName,
                           progress: ((Double) -> Void)? = nil) async throws -> Catalog {
        try await decodeEndpoint(.catalog(board: boardName), progress: progress)
    }

    public func getThread(boardName: BoardName, no: PostNumber,
                          progress: ((Double) -> Void)? = nil) async throws -> ChanThread {
        try await decodeEndpoint(.thread(board: boardName, no: no), progress: progress)
    }

    public func getThreads(boardName: BoardName, page: PageNumber,
                           progress: ((Double) -> Void)? = nil) async throws -> Threads {
        try await decodeEndpoint(.threads(board: boardName, page: page), progress: progress)
    }

    public func getAllThreads(boardName: BoardName,
                              progress: ((Double) -> Void)? = nil) async throws -> Pages {
        try await decodeEndpoint(.allThreads(board: boardName), progress: progress)
    }

    public func getArchive(boardName: BoardName,
                           progress: ((Double) -> Void)? = nil) async throws -> Archive {
        try await decodeEndpoint(.archive(board: boardName), progress: progress)
    }

    public func getImageData(boardName: BoardName, tim: Int, ext: String,
                             progress: ((Double) -> Void)? = nil) async throws -> Data {
        let endpoint = FourChanAPIEndpoint.image(board: boardName, tim: tim, ext: ext)
        return try await decodeEndpoint(endpoint, progress: progress)
    }
}
