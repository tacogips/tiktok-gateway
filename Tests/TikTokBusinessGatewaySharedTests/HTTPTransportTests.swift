import Darwin
import Foundation
import Testing

@testable import TikTokBusinessGatewayShared

@Test func concreteTransportEnforcesStreamingResponseLimit() async throws {
  let server = try LocalHTTPServer(
    responses: [httpResponse(status: "200 OK", body: Data(repeating: 65, count: 128))]
  )
  let transport = URLSessionHTTPTransport(testingOrigin: server.origin)
  do {
    _ = try await transport.send(request(url: server.url("/large"), maximumBytes: 32))
    Issue.record("Expected response-size rejection")
  } catch let error as GatewayError {
    #expect(error.code == .responseTooLarge)
  }
}

@Test func concreteTransportUsesPlatformTrustForOfficialHTTPS() async throws {
  guard
    ProcessInfo.processInfo.environment["TIKTOK_BUSINESS_GATEWAY_RUN_HTTPS_INTEGRATION"] == "1"
  else { return }
  let url = OperationCatalog.origin.appendingPathComponent("open_api/v1.3/advertiser/info/")
  let response = try await URLSessionHTTPTransport().send(
    HTTPRequest(method: .get, url: url, headers: [:], maximumResponseBytes: 1_048_576)
  )
  #expect((100...599).contains(response.statusCode))
}

@Test func concreteTransportRejectsRedirectWithoutFollowingIt() async throws {
  let server = try LocalHTTPServer(
    responses: [
      httpResponse(
        status: "302 Found",
        headers: ["Location": "/redirected", "Content-Length": "0"]
      )
    ]
  )
  let transport = URLSessionHTTPTransport(testingOrigin: server.origin)
  do {
    _ = try await transport.send(request(url: server.url("/initial")))
    Issue.record("Expected redirect rejection")
  } catch let error as GatewayError {
    #expect(error.code == .transportFailure)
  }
  server.waitUntilIdle()
  #expect(server.requestCount == 1)
}

@Test func concreteTransportDoesNotReplayWriterBodyAfterChallenge() async throws {
  let unauthorized = httpResponse(
    status: "401 Unauthorized",
    headers: ["WWW-Authenticate": #"Basic realm="test""#, "Content-Length": "0"]
  )
  let server = try LocalHTTPServer(responses: [unauthorized, unauthorized])
  let transport = URLSessionHTTPTransport(testingOrigin: server.origin)
  let body = Data(#"{"advertiser_id":"123"}"#.utf8)
  let challengedRequest = request(url: server.url("/write"), method: .post, body: body)
  do {
    _ = try await transport.send(challengedRequest)
  } catch {
    // Challenge cancellation may be surfaced as a transport failure by Foundation.
  }
  server.waitUntilIdle()
  #expect(server.requestCount == 1)
  #expect(server.requestBodies == [body])
}

@Test func concreteTransportCancelsInFlightPostWithoutReplay() async throws {
  let server = try LocalHTTPServer(
    responses: [httpResponse(status: "200 OK", body: Data("OK".utf8))],
    responseDelayMicroseconds: 1_500_000
  )
  let transport = URLSessionHTTPTransport(testingOrigin: server.origin)
  let body = Data(#"{"advertiser_id":"123"}"#.utf8)
  let started = ContinuousClock.now
  let operation = Task {
    try await transport.send(request(url: server.url("/write"), method: .post, body: body))
  }
  for _ in 0..<100 where server.requestCount == 0 {
    try await Task.sleep(for: .milliseconds(10))
  }
  #expect(server.requestCount == 1)
  operation.cancel()
  do {
    _ = try await operation.value
    Issue.record("Expected in-flight request cancellation")
  } catch let error as TransportError {
    #expect(error.phase == .outcomeUnknown)
    #expect(error.transience == .permanent)
  }
  #expect(started.duration(to: .now) < .seconds(1))
  server.waitUntilIdle()
  #expect(server.requestCount == 1)
  #expect(server.requestBodies == [body])
}

@Test func concreteTransportIgnoresInjectedProxyConfiguration() async throws {
  let server = try LocalHTTPServer(
    responses: [
      httpResponse(status: "200 OK", headers: ["Content-Length": "2"], body: Data("OK".utf8))
    ]
  )
  let configuration = URLSessionConfiguration.ephemeral
  configuration.connectionProxyDictionary = [
    "HTTPEnable": 1,
    "HTTPProxy": "127.0.0.1",
    "HTTPPort": 9,
  ]
  let transport = URLSessionHTTPTransport(
    testingOrigin: server.origin,
    configuration: configuration
  )
  let response = try await transport.send(request(url: server.url("/direct")))
  #expect(response.statusCode == 200)
  #expect(response.body == Data("OK".utf8))
}

private func request(
  url: URL,
  method: HTTPMethod = .get,
  body: Data? = nil,
  maximumBytes: Int = 1_024
) -> HTTPRequest {
  HTTPRequest(
    method: method, url: url, headers: [:], body: body, maximumResponseBytes: maximumBytes)
}

private func httpResponse(
  status: String,
  headers: [String: String] = [:],
  body: Data = Data()
) -> Data {
  var head = "HTTP/1.1 \(status)\r\nConnection: close\r\n"
  for (name, value) in headers { head += "\(name): \(value)\r\n" }
  head += "\r\n"
  var data = Data(head.utf8)
  data.append(body)
  return data
}

private final class LocalHTTPServer: @unchecked Sendable {
  private let listener: Int32
  private let responses: [Data]
  private let responseDelayMicroseconds: useconds_t
  private let lock = NSLock()
  private let finished = DispatchSemaphore(value: 0)
  private var capturedBodies: [Data] = []
  private var capturedRequestCount = 0

  let origin: URL

  init(responses: [Data], responseDelayMicroseconds: useconds_t = 0) throws {
    guard !responses.isEmpty else { throw ServerError.setup }
    let listener = socket(AF_INET, SOCK_STREAM, 0)
    guard listener >= 0 else { throw ServerError.setup }
    self.listener = listener
    self.responses = responses
    self.responseDelayMicroseconds = responseDelayMicroseconds

    var reuse: Int32 = 1
    setsockopt(
      listener, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout.size(ofValue: reuse)))
    var noSignal: Int32 = 1
    setsockopt(
      listener, SOL_SOCKET, SO_NOSIGPIPE, &noSignal, socklen_t(MemoryLayout.size(ofValue: noSignal))
    )

    var address = sockaddr_in()
    address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
    address.sin_family = sa_family_t(AF_INET)
    address.sin_addr = in_addr(s_addr: inet_addr("127.0.0.1"))
    address.sin_port = 0
    let bindResult = withUnsafePointer(to: &address) {
      $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
        Darwin.bind(listener, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
      }
    }
    guard bindResult == 0, listen(listener, 4) == 0 else {
      close(listener)
      throw ServerError.setup
    }
    var length = socklen_t(MemoryLayout<sockaddr_in>.size)
    guard
      withUnsafeMutablePointer(
        to: &address,
        {
          $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
            getsockname(listener, $0, &length)
          }
        }) == 0,
      let origin = URL(string: "http://127.0.0.1:\(UInt16(bigEndian: address.sin_port))")
    else {
      close(listener)
      throw ServerError.setup
    }
    self.origin = origin
    DispatchQueue.global().async { [self] in serve() }
  }

  deinit { close(listener) }

  var requestCount: Int { lock.withLock { capturedRequestCount } }
  var requestBodies: [Data] { lock.withLock { capturedBodies } }

  func url(_ path: String) -> URL { origin.appendingPathComponent(path) }

  func waitUntilIdle() {
    _ = finished.wait(timeout: .now() + 2)
  }

  private func serve() {
    defer { finished.signal() }
    for (index, response) in responses.enumerated() {
      var descriptor = pollfd(fd: listener, events: Int16(POLLIN), revents: 0)
      guard poll(&descriptor, 1, index == 0 ? 2_000 : 300) > 0 else { return }
      let client = accept(listener, nil, nil)
      guard client >= 0 else { return }
      var noSignal: Int32 = 1
      setsockopt(
        client, SOL_SOCKET, SO_NOSIGPIPE, &noSignal, socklen_t(MemoryLayout.size(ofValue: noSignal))
      )
      let request = readRequest(client)
      lock.withLock {
        capturedRequestCount += 1
        capturedBodies.append(request.body)
      }
      if responseDelayMicroseconds > 0 { usleep(responseDelayMicroseconds) }
      response.withUnsafeBytes { bytes in
        var offset = 0
        while offset < bytes.count {
          let sent = Darwin.send(client, bytes.baseAddress! + offset, bytes.count - offset, 0)
          if sent <= 0 { break }
          offset += sent
        }
      }
      close(client)
    }
  }

  private func readRequest(_ descriptor: Int32) -> (body: Data, raw: Data) {
    var data = Data()
    var headerEnd: Int?
    var expectedCount: Int?
    while data.count < 1_048_576 {
      var buffer = [UInt8](repeating: 0, count: 4_096)
      let count = Darwin.read(descriptor, &buffer, buffer.count)
      guard count > 0 else { break }
      data.append(buffer, count: count)
      if headerEnd == nil, let range = data.range(of: Data("\r\n\r\n".utf8)) {
        headerEnd = range.upperBound
        let head = String(bytes: data[..<range.lowerBound], encoding: .utf8) ?? ""
        let contentLength =
          head.split(separator: "\r\n")
          .first { $0.lowercased().hasPrefix("content-length:") }
          .flatMap {
            Int($0.split(separator: ":", maxSplits: 1)[1].trimmingCharacters(in: .whitespaces))
          }
          ?? 0
        expectedCount = range.upperBound + contentLength
      }
      if let expectedCount, data.count >= expectedCount { break }
    }
    guard let headerEnd else { return (Data(), data) }
    return (Data(data[headerEnd...]), data)
  }
}

private enum ServerError: Error { case setup }
