import Foundation

/**
 One download or upload stream. It owns one URLSession, so each stream opens its own TCP connections.

 A shared session would let HTTP/2 multiplex the streams over one connection and cap the measured rate. The stream
 chains requests: when one ends, the next starts, until `stop()` is called or the stream fails. Byte counts are read
 by the phase monitor from another thread, so they sit behind a lock.
 */
final class SpeedTestStream: NSObject, URLSessionDataDelegate {
    /// What the stream transfers on each request.
    enum Kind {
        /// GET requests, each expecting exactly `expectedBytes` of body.
        case download(url: URL, expectedBytes: Int64)
        /// POST requests, each sending the same reused `body`.
        case upload(url: URL, body: Data)
    }

    /// The User-Agent every speed test request sends. It carries no personal details.
    static let userAgent = "StatusMonitor speed test"

    private let kind: Kind
    private let clock: () -> TimeInterval
    private let uploadCountingDelay: TimeInterval
    private let startedAt: TimeInterval
    private let lock = NSLock()
    private var session: URLSession?
    private var pending: CheckedContinuation<Void, Error>?
    private var isStopped = false
    private var counted: Int64 = 0
    private var receivedBodyBytes: Int64 = 0
    private var requestFailure: SpeedTestError?
    private var streamFailure: SpeedTestError?

    /**
     Creates a stream and its session. The stream does not send anything until `run()` is called.

     - Parameters:
       - kind: The transfer each request makes.
       - configuration: The base configuration. Timeouts, cache, cookies and User-Agent are applied on top.
       - clock: Supplies monotonic seconds.
       - uploadCountingDelay: Seconds after creation before upload bytes count, while the send buffer fills.
     */
    init(
        kind: Kind,
        configuration: URLSessionConfiguration,
        clock: @escaping () -> TimeInterval,
        uploadCountingDelay: TimeInterval
    ) {
        self.kind = kind
        self.clock = clock
        self.uploadCountingDelay = uploadCountingDelay
        self.startedAt = clock()
        super.init()
        self.session = Self.makeSession(configuration: configuration, delegate: self)
    }

    /// Bytes counted so far. Download bytes count as they arrive. Upload bytes count after the counting delay.
    var countedBytes: Int64 {
        lock.lock()
        defer { lock.unlock() }
        return counted
    }

    /// The error that stopped this stream, or nil while it is healthy or was stopped on purpose.
    var failure: SpeedTestError? {
        lock.lock()
        defer { lock.unlock() }
        return streamFailure
    }

    /**
     Sends requests one after another until the stream is stopped or a request fails.

     A failure is recorded in `failure` and the method returns normally, so other streams keep running. An offline
     failure is thrown at once, so the phase can stop without waiting for the rest.

     - Throws: `SpeedTestError.offline` when the network is not connected.
     */
    func run() async throws {
        defer { stop() }
        do {
            try await withTaskCancellationHandler {
                while !stopped {
                    try await performRequest()
                }
            } onCancel: {
                self.stop()
            }
        } catch SpeedTestError.offline {
            throw SpeedTestError.offline
        } catch {
            if !stopped {
                recordFailure(Self.classify(error))
            }
        }
    }

    /// Stops the chain and cancels any request in flight by invalidating the session. Safe to call more than once.
    func stop() {
        lock.lock()
        guard !isStopped else {
            lock.unlock()
            return
        }
        isStopped = true
        let session = self.session
        self.session = nil
        lock.unlock()
        session?.invalidateAndCancel()
    }

    /**
     Creates a session with the speed test's constraints applied: no cache, no cookies, a 10 s request timeout, a 30 s
     overall timeout, and the speed test User-Agent.

     - Parameters:
       - configuration: The base configuration, usually ephemeral. It is modified in place.
       - delegate: Receives the session's callbacks, or nil.
     - Returns: A session that is not yet invalidated.
     */
    static func makeSession(configuration: URLSessionConfiguration, delegate: URLSessionDelegate?) -> URLSession {
        URLSession(configuration: configure(configuration), delegate: delegate, delegateQueue: nil)
    }

    /**
     Applies the speed test's constraints to a configuration.

     - Parameter configuration: The configuration to modify in place.
     - Returns: The same configuration object, now constrained.
     */
    static func configure(_ configuration: URLSessionConfiguration) -> URLSessionConfiguration {
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.urlCredentialStorage = nil
        configuration.timeoutIntervalForRequest = 10
        configuration.timeoutIntervalForResource = 30
        configuration.httpAdditionalHeaders = ["User-Agent": userAgent]
        return configuration
    }

    /**
     Maps any error from a speed test request to the error the caller sees.

     - Parameter error: The error to map.
     - Returns: `offline` for a not-connected URLError, `cancelled` for cancellation, the error itself for a
       `SpeedTestError`, and `serviceUnavailable` for anything else.
     */
    static func classify(_ error: Error) -> SpeedTestError {
        if let speedTestError = error as? SpeedTestError {
            return speedTestError
        }
        if error is CancellationError {
            return .cancelled
        }
        guard let urlError = error as? URLError else {
            return .serviceUnavailable
        }
        switch urlError.code {
        case .notConnectedToInternet:
            return .offline
        case .cancelled:
            return .cancelled
        default:
            return .serviceUnavailable
        }
    }

    private var stopped: Bool {
        lock.lock()
        defer { lock.unlock() }
        return isStopped
    }

    private func recordFailure(_ failure: SpeedTestError) {
        lock.lock()
        defer { lock.unlock() }
        if streamFailure == nil {
            streamFailure = failure
        }
    }

    private func performRequest() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            lock.lock()
            guard !isStopped, let session else {
                lock.unlock()
                continuation.resume(throwing: CancellationError())
                return
            }
            receivedBodyBytes = 0
            requestFailure = nil
            pending = continuation
            let task = makeTask(in: session)
            lock.unlock()
            task.resume()
        }
    }

    private func makeTask(in session: URLSession) -> URLSessionTask {
        switch kind {
        case let .download(url, _):
            return session.dataTask(with: makeRequest(url: url, method: "GET"))
        case let .upload(url, body):
            return session.uploadTask(with: makeRequest(url: url, method: "POST"), from: body)
        }
    }

    private func makeRequest(url: URL, method: String) -> URLRequest {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)
        request.httpMethod = method
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        return request
    }

    /// The verdict for a finished request. Call with the lock held.
    private func requestVerdict(error: Error?) -> Result<Void, Error> {
        if isStopped {
            return .failure(CancellationError())
        }
        if let requestFailure {
            return .failure(requestFailure)
        }
        if let error {
            return .failure(Self.classify(error))
        }
        if case let .download(_, expectedBytes) = kind, receivedBodyBytes != expectedBytes {
            return .failure(SpeedTestError.invalidResponse)
        }
        return .success(())
    }

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        let failure = CloudflareSpeedTestClient.failure(forStatusCode: statusCode)
        if let failure {
            lock.lock()
            requestFailure = failure
            lock.unlock()
        }
        completionHandler(failure == nil ? .allow : .cancel)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        lock.lock()
        defer { lock.unlock() }
        receivedBodyBytes += Int64(data.count)
        if case .download = kind {
            counted += Int64(data.count)
        }
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didSendBodyData bytesSent: Int64,
        totalBytesSent: Int64,
        totalBytesExpectedToSend: Int64
    ) {
        let now = clock()
        lock.lock()
        defer { lock.unlock() }
        if case .upload = kind, now - startedAt >= uploadCountingDelay {
            counted += bytesSent
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        lock.lock()
        let continuation = pending
        pending = nil
        let verdict = requestVerdict(error: error)
        lock.unlock()
        continuation?.resume(with: verdict)
    }
}
