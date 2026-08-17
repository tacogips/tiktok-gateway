import Foundation

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

public struct HTTPRequest: Sendable {
  public let method: HTTPMethod
  public let url: URL
  public let headers: [String: String]
  public let body: Data?
  public let maximumResponseBytes: Int

  package init(
    method: HTTPMethod,
    url: URL,
    headers: [String: String],
    body: Data? = nil,
    maximumResponseBytes: Int = 8 * 1_024 * 1_024
  ) {
    self.method = method
    self.url = url
    self.headers = headers
    self.body = body
    self.maximumResponseBytes = maximumResponseBytes
  }
}

public struct HTTPResponse: Sendable {
  public let statusCode: Int
  public let headers: [String: String]
  public let body: Data

  public init(statusCode: Int, headers: [String: String] = [:], body: Data) {
    self.statusCode = statusCode
    self.headers = headers
    self.body = body
  }
}

public enum TransportFailurePhase: Sendable, Equatable {
  case preDispatch
  case outcomeUnknown
}

public enum TransportFailureTransience: Sendable, Equatable {
  case transient
  case permanent
}

public struct TransportError: Error, Sendable {
  public let phase: TransportFailurePhase
  public let transience: TransportFailureTransience

  public init(
    phase: TransportFailurePhase,
    transience: TransportFailureTransience = .transient
  ) {
    self.phase = phase
    self.transience = transience
  }
}

public protocol HTTPTransport: Sendable {
  func send(_ request: HTTPRequest) async throws -> HTTPResponse
}

public final class URLSessionHTTPTransport: HTTPTransport, @unchecked Sendable {
  private let configuration: URLSessionConfiguration
  private let allowedOrigin: URL
  private let permitsInsecureLoopback: Bool

  public init() {
    self.configuration = Self.harden(URLSessionConfiguration.ephemeral)
    self.allowedOrigin = OperationCatalog.origin
    self.permitsInsecureLoopback = false
  }

  init(testingOrigin: URL, configuration: URLSessionConfiguration = .ephemeral) {
    self.configuration = Self.harden(configuration)
    self.allowedOrigin = testingOrigin
    self.permitsInsecureLoopback = true
  }

  private static func harden(_ configuration: URLSessionConfiguration)
    -> URLSessionConfiguration
  {
    configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
    configuration.urlCache = nil
    configuration.httpCookieStorage = nil
    configuration.httpShouldSetCookies = false
    configuration.urlCredentialStorage = nil
    configuration.connectionProxyDictionary = [:]
    configuration.timeoutIntervalForRequest = 30
    configuration.timeoutIntervalForResource = 45
    configuration.waitsForConnectivity = false
    return configuration
  }

  public func send(_ request: HTTPRequest) async throws -> HTTPResponse {
    let sameOrigin =
      request.url.host == allowedOrigin.host
      && request.url.port == allowedOrigin.port
    let acceptedScheme =
      request.url.scheme == "https"
      || (permitsInsecureLoopback && request.url.scheme == "http" && isLoopback(request.url.host))
    let acceptedPath =
      permitsInsecureLoopback
      || request.url.path.hasPrefix("/open_api/v1.3/")
    guard sameOrigin, acceptedScheme, acceptedPath, request.maximumResponseBytes > 0
    else {
      throw GatewayError(.invalidArgument, message: "Transport rejected a non-catalog destination")
    }

    var urlRequest = URLRequest(url: request.url)
    urlRequest.httpMethod = request.method.rawValue
    urlRequest.httpBody = request.body
    for (key, value) in request.headers { urlRequest.setValue(value, forHTTPHeaderField: key) }

    let delegate = BoundedDataDelegate(maximumBytes: request.maximumResponseBytes)
    return try await delegate.perform(urlRequest, configuration: configuration)
  }

  private func isLoopback(_ host: String?) -> Bool {
    host == "127.0.0.1" || host == "localhost" || host == "::1"
  }

  package static func classify(_ error: URLError) -> TransportError {
    let preDispatchTransient: Set<URLError.Code> = [
      .cannotFindHost,
      .cannotConnectToHost,
      .dnsLookupFailed,
      .notConnectedToInternet,
      .internationalRoamingOff,
      .callIsActive,
      .dataNotAllowed,
    ]
    let outcomeUnknownTransient: Set<URLError.Code> = [
      .timedOut,
      .networkConnectionLost,
      .cannotLoadFromNetwork,
    ]
    if preDispatchTransient.contains(error.code) {
      return TransportError(phase: .preDispatch, transience: .transient)
    }
    if outcomeUnknownTransient.contains(error.code) {
      return TransportError(phase: .outcomeUnknown, transience: .transient)
    }
    let permanentPreDispatch: Set<URLError.Code> = [.badURL, .unsupportedURL]
    return TransportError(
      phase: permanentPreDispatch.contains(error.code) ? .preDispatch : .outcomeUnknown,
      transience: .permanent
    )
  }
}

private final class BoundedDataDelegate: NSObject, URLSessionDataDelegate, @unchecked Sendable {
  private let maximumBytes: Int
  private let lock = NSLock()
  private var continuation: CheckedContinuation<HTTPResponse, Error>?
  private var response: HTTPURLResponse?
  private var body = Data()
  private var failure: Error?
  private var session: URLSession?
  private var dataTask: URLSessionDataTask?
  private var cancellationRequested = false

  init(maximumBytes: Int) { self.maximumBytes = maximumBytes }

  func perform(_ request: URLRequest, configuration: URLSessionConfiguration) async throws
    -> HTTPResponse
  {
    try await withTaskCancellationHandler {
      try await withCheckedThrowingContinuation { continuation in
        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        let dataTask = session.dataTask(with: request)
        lock.lock()
        self.continuation = continuation
        self.session = session
        self.dataTask = dataTask
        let shouldCancel = cancellationRequested
        lock.unlock()
        dataTask.resume()
        if shouldCancel { dataTask.cancel() }
      }
    } onCancel: {
      self.cancel()
    }
  }

  private func cancel() {
    lock.lock()
    cancellationRequested = true
    let dataTask = self.dataTask
    lock.unlock()
    dataTask?.cancel()
  }

  func urlSession(
    _: URLSession,
    dataTask: URLSessionDataTask,
    didReceive response: URLResponse,
    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
  ) {
    lock.lock()
    guard let http = response as? HTTPURLResponse else {
      failure = GatewayError(.invalidResponse, message: "TikTok returned a non-HTTP response")
      lock.unlock()
      completionHandler(.cancel)
      return
    }
    self.response = http
    if let length = http.value(forHTTPHeaderField: "Content-Length"),
      let count = Int(length), count > maximumBytes
    {
      failure = GatewayError(
        .responseTooLarge, message: "TikTok response exceeded the configured size limit")
      lock.unlock()
      completionHandler(.cancel)
      return
    }
    lock.unlock()
    completionHandler(.allow)
  }

  func urlSession(_: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
    lock.lock()
    if body.count + data.count > maximumBytes {
      failure = GatewayError(
        .responseTooLarge, message: "TikTok response exceeded the configured size limit")
      lock.unlock()
      dataTask.cancel()
      return
    }
    body.append(data)
    lock.unlock()
  }

  func urlSession(
    _: URLSession,
    task _: URLSessionTask,
    willPerformHTTPRedirection _: HTTPURLResponse,
    newRequest _: URLRequest,
    completionHandler: @escaping (URLRequest?) -> Void
  ) {
    lock.lock()
    failure = GatewayError(.transportFailure, message: "TikTok redirect was rejected")
    lock.unlock()
    completionHandler(nil)
  }

  func urlSession(
    _: URLSession,
    task _: URLSessionTask,
    didReceive challenge: URLAuthenticationChallenge,
    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
  ) {
    if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
      completionHandler(.performDefaultHandling, nil)
    } else {
      completionHandler(.cancelAuthenticationChallenge, nil)
    }
  }

  func urlSession(_: URLSession, task _: URLSessionTask, didCompleteWithError error: Error?) {
    lock.lock()
    guard let continuation else {
      lock.unlock()
      return
    }
    self.continuation = nil
    let result: Result<HTTPResponse, Error>
    if let failure {
      result = .failure(failure)
    } else if let error = error as? URLError {
      result = .failure(URLSessionHTTPTransport.classify(error))
    } else if error != nil {
      result = .failure(
        TransportError(phase: .outcomeUnknown, transience: .permanent))
    } else if let response {
      var headers: [String: String] = [:]
      for (key, value) in response.allHeaderFields {
        if let key = key as? String, let value = value as? String {
          headers[key.lowercased()] = value
        }
      }
      result = .success(HTTPResponse(statusCode: response.statusCode, headers: headers, body: body))
    } else {
      result = .failure(GatewayError(.invalidResponse, message: "TikTok response was incomplete"))
    }
    let session = self.session
    self.session = nil
    self.dataTask = nil
    lock.unlock()
    session?.finishTasksAndInvalidate()
    continuation.resume(with: result)
  }
}

public protocol RetrySleeping: Sendable {
  func sleep(nanoseconds: UInt64) async throws
}

public struct TaskRetrySleeper: RetrySleeping, Sendable {
  public init() {}
  public func sleep(nanoseconds: UInt64) async throws {
    try await Task.sleep(nanoseconds: nanoseconds)
  }
}
