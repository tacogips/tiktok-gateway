import Foundation
import Testing

@testable import TikTokBusinessGatewayShared

@Test func profileValidationEnforcesCapabilityAndAdvertiserAllowlists() throws {
  let profile = GatewayProfile(
    id: "sandbox-reader",
    capability: .reader,
    accessTokenEnvironmentVariable: "TIKTOK_READER_TOKEN",
    advertiserIDs: ["123"],
    operations: [.campaignsList]
  )
  try profile.validate()
  try profile.authorize(.campaignsList, advertiserID: "123")
  #expect(throws: GatewayError.self) { try profile.authorize(.adsList, advertiserID: "123") }
  #expect(throws: GatewayError.self) { try profile.authorize(.campaignsList, advertiserID: "456") }
}

@Test func compiledEvidenceGateEnablesReviewedOperations() throws {
  #expect(OperationCatalog.entries.allSatisfy { $0.enabled })
  for operation in OperationCatalog.enabledOperations {
    try OperationCatalog.operationGate.requireEnabled(operation)
  }
}

@Test func applicationSecretIsResolvedOnlyForAuthorizedAdvertiserListing() throws {
  let values = [
    "TIKTOK_READER_TOKEN": "fake-token",
    "TIKTOK_APP_SECRET": "fake-secret",
  ]
  let resolver = EnvironmentCredentialResolver { values[$0] }
  let ordinary = GatewayProfile(
    id: "ordinary-reader",
    capability: .reader,
    accessTokenEnvironmentVariable: "TIKTOK_READER_TOKEN",
    advertiserIDs: ["123"],
    operations: [.campaignsList]
  )
  #expect(try resolver.resolve(for: ordinary, operation: .campaignsList).appSecret == nil)

  let authorized = GatewayProfile(
    id: "authorized-reader",
    capability: .reader,
    accessTokenEnvironmentVariable: "TIKTOK_READER_TOKEN",
    appID: "fake-app",
    appSecretEnvironmentVariable: "TIKTOK_APP_SECRET",
    advertiserIDs: ["123"],
    operations: [.advertisersList]
  )
  #expect(
    try resolver.resolve(for: authorized, operation: .advertisersList).appSecret == "fake-secret")
}

@Test func ambiguousThrottleEnvelopeIsNotRetried() async throws {
  let throttled = HTTPResponse(
    statusCode: 200,
    body: Data(
      #"{"code":40016,"message":"throttled","request_id":"one","data":{}}"#.utf8)
  )
  let transport = QueueTransport(results: [.success(throttled)])
  let sleeper = RecordingSleeper()
  let executor = TikTokAPIExecutor(transport: transport, sleeper: sleeper)
  do {
    let _: TikTokEnvelope<RequiredPayload> = try await executor.execute(
      operation: .campaignsList,
      credentials: GatewayCredentials(accessToken: "fake-token")
    )
    Issue.record("Expected provider throttle failure")
  } catch let error as GatewayError {
    #expect(error.code == .providerFailure)
    #expect(error.providerCode == 40016)
    #expect(error.requestID == "one")
  }
  #expect(await transport.requestCount == 1)
  #expect(await sleeper.sleepCount == 0)
}

@Test func finalNonSuccessHTTPRetainsTikTokEnvelopeDetails() async throws {
  let response = HTTPResponse(
    statusCode: 400,
    body: Data(
      #"{"code":40002,"message":"invalid advertiser","request_id":"provider-request-123","data":{}}"#
        .utf8
    )
  )
  let transport = QueueTransport(results: [.success(response)])
  let executor = TikTokAPIExecutor(transport: transport, sleeper: RecordingSleeper())
  do {
    let _: TikTokEnvelope<RequiredPayload> = try await executor.execute(
      operation: .campaignsList,
      credentials: GatewayCredentials(accessToken: "fake-token")
    )
    Issue.record("Expected non-success HTTP failure")
  } catch let error as GatewayError {
    #expect(error.code == .providerFailure)
    #expect(error.providerCode == 40002)
    #expect(error.requestID == "provider-request-123")
  }
  #expect(await transport.requestCount == 1)
}

@Test func finalRetryableHTTPRetainsTikTokEnvelopeDetailsAfterBoundedRetries() async throws {
  let response = HTTPResponse(
    statusCode: 503,
    body: Data(
      #"{"code":50002,"message":"temporarily unavailable","request_id":"final-request-503","data":["incompatible"]}"#
        .utf8
    )
  )
  let transport = QueueTransport(results: [
    .success(response), .success(response), .success(response),
  ])
  let sleeper = RecordingSleeper()
  let executor = TikTokAPIExecutor(transport: transport, sleeper: sleeper)
  do {
    let _: TikTokEnvelope<RequiredPayload> = try await executor.execute(
      operation: .campaignsList,
      credentials: GatewayCredentials(accessToken: "fake-token")
    )
    Issue.record("Expected final retryable HTTP failure")
  } catch let error as GatewayError {
    #expect(error.code == .providerFailure)
    #expect(error.providerCode == 50002)
    #expect(error.requestID == "final-request-503")
  }
  #expect(await transport.requestCount == 3)
  #expect(await sleeper.sleepCount == 2)
}

@Test func applicationFailureAfterHTTPRetryIgnoresIncompatibleSuccessData() async throws {
  let transient = HTTPResponse(statusCode: 503, body: Data())
  let applicationFailure = HTTPResponse(
    statusCode: 200,
    body: Data(
      #"{"code":40003,"message":"invalid request","request_id":"post-retry-app","data":"incompatible"}"#
        .utf8
    )
  )
  let transport = QueueTransport(results: [.success(transient), .success(applicationFailure)])
  let sleeper = RecordingSleeper()
  let executor = TikTokAPIExecutor(transport: transport, sleeper: sleeper)
  do {
    let _: TikTokEnvelope<RequiredPayload> = try await executor.execute(
      operation: .campaignsList,
      credentials: GatewayCredentials(accessToken: "fake-token")
    )
    Issue.record("Expected application failure after HTTP retry")
  } catch let error as GatewayError {
    #expect(error.code == .providerFailure)
    #expect(error.providerCode == 40003)
    #expect(error.requestID == "post-retry-app")
  }
  #expect(await transport.requestCount == 2)
  #expect(await sleeper.sleepCount == 1)
}

@Test func successfulEnvelopeStillRequiresCompatibleTypedData() async throws {
  let response = HTTPResponse(
    statusCode: 200,
    body: Data(#"{"code":0,"message":"OK","request_id":"success-invalid","data":{}}"#.utf8)
  )
  let executor = TikTokAPIExecutor(
    transport: QueueTransport(results: [.success(response)]),
    sleeper: RecordingSleeper()
  )
  do {
    let _: TikTokEnvelope<RequiredPayload> = try await executor.execute(
      operation: .campaignsList,
      credentials: GatewayCredentials(accessToken: "fake-token")
    )
    Issue.record("Expected incompatible success data to fail")
  } catch let error as GatewayError {
    #expect(error.code == .invalidResponse)
    #expect(error.providerCode == nil)
    #expect(error.requestID == nil)
  }
}

@Test func redactorRemovesRawAndEncodedSecrets() {
  let output = Redactor.redact(
    "authorization=abc/123 secret=abc%2F123",
    secrets: ["abc/123"]
  )
  #expect(!output.contains("abc/123"))
  #expect(!output.contains("abc%2F123"))
}

@Test func strictJSONRejectsEscapedDuplicateKeys() {
  let data = Data(#"{"operations":[],"oper\u0061tions":[]}"#.utf8)
  #expect(throws: GatewayError.self) { try StrictJSON.verifyNoDuplicateKeys(data) }
}

@Test func jsonNumbersRoundTripAsNumbersInsteadOfStrings() throws {
  let source = Data(#"[0,-12,12.34,1e3]"#.utf8)
  let decoded = try JSONDecoder().decode([JSONValue].self, from: source)
  let encoded = try JSONOutput.encode(decoded)
  let text = try #require(String(bytes: encoded, encoding: .utf8))
  #expect(!text.contains(#""12.34""#))
  #expect(!text.contains(#""1000""#))
  #expect(try JSONDecoder().decode([JSONValue].self, from: encoded) == decoded)
}

@Test func identifiersRejectUnicodeDigitsAndLeadingZeros() {
  #expect(IdentifierValidator.isCanonicalDecimal("123"))
  #expect(!IdentifierValidator.isCanonicalDecimal("１２３"))
  #expect(!IdentifierValidator.isCanonicalDecimal("0123"))
}

@Test func safeReadRetriesTransientHTTPStatus() async throws {
  let unavailable = HTTPResponse(statusCode: 503, body: Data())
  let successful = HTTPResponse(
    statusCode: 200,
    body: Data(#"{"code":0,"message":"OK","data":{}}"#.utf8)
  )
  let transport = QueueTransport(results: [.success(unavailable), .success(successful)])
  let executor = TikTokAPIExecutor(transport: transport, sleeper: RecordingSleeper())
  let envelope: TikTokEnvelope<JSONValue> = try await executor.execute(
    operation: .adsList,
    credentials: GatewayCredentials(accessToken: "fake-token")
  )
  #expect(envelope.code == 0)
  #expect(await transport.requestCount == 2)
}

@Test(arguments: [408, 501, 599])
func safeReadRetriesReviewedHTTPStatus(status: Int) async throws {
  let transient = HTTPResponse(statusCode: status, body: Data())
  let successful = HTTPResponse(
    statusCode: 200,
    body: Data(#"{"code":0,"message":"OK","data":{}}"#.utf8)
  )
  let transport = QueueTransport(results: [.success(transient), .success(successful)])
  let executor = TikTokAPIExecutor(transport: transport, sleeper: RecordingSleeper())
  let envelope: TikTokEnvelope<JSONValue> = try await executor.execute(
    operation: .adsList,
    credentials: GatewayCredentials(accessToken: "fake-token")
  )
  #expect(envelope.code == 0)
  #expect(await transport.requestCount == 2)
}

@Test(arguments: [
  URLError.Code.cancelled,
  .secureConnectionFailed,
  .serverCertificateUntrusted,
])
func safeReadDoesNotRetryPermanentTransportFailures(code: URLError.Code) async throws {
  let classified = URLSessionHTTPTransport.classify(URLError(code))
  #expect(classified.transience == .permanent)
  let transport = QueueTransport(results: [.failure(classified)])
  let sleeper = RecordingSleeper()
  let executor = TikTokAPIExecutor(transport: transport, sleeper: sleeper)
  do {
    let _: TikTokEnvelope<JSONValue> = try await executor.execute(
      operation: .adsList,
      credentials: GatewayCredentials(accessToken: "fake-token")
    )
    Issue.record("Expected permanent transport failure")
  } catch let error as GatewayError {
    #expect(error.code == .transportFailure)
  }
  #expect(await transport.requestCount == 1)
  #expect(await sleeper.sleepCount == 0)
}

@Test func configurationRejectsSymbolicLinkAndWritableFile() throws {
  let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
  defer { try? FileManager.default.removeItem(at: directory) }
  let configURL = directory.appendingPathComponent("profiles.json")
  try validConfigurationData().write(to: configURL)

  try FileManager.default.setAttributes([.posixPermissions: 0o666], ofItemAtPath: configURL.path)
  #expect(throws: GatewayError.self) { try ConfigurationLoader.load(path: configURL.path) }

  try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: configURL.path)
  let linkURL = directory.appendingPathComponent("profiles-link.json")
  try FileManager.default.createSymbolicLink(at: linkURL, withDestinationURL: configURL)
  #expect(throws: GatewayError.self) { try ConfigurationLoader.load(path: linkURL.path) }
}

@Test func configurationRejectsDirectoryOversizeAndInPlaceMutation() throws {
  let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
  defer { try? FileManager.default.removeItem(at: directory) }
  #expect(throws: GatewayError.self) { try ConfigurationLoader.load(path: directory.path) }

  let oversizedURL = directory.appendingPathComponent("oversized.json")
  try Data(repeating: 65, count: ConfigurationLoader.maximumBytes + 1).write(to: oversizedURL)
  #expect(throws: GatewayError.self) { try ConfigurationLoader.load(path: oversizedURL.path) }

  let mutableURL = directory.appendingPathComponent("mutable.json")
  try validConfigurationData().write(to: mutableURL)
  #expect(throws: GatewayError.self) {
    try SecureFileReader.read(
      path: mutableURL.path,
      maximumBytes: ConfigurationLoader.maximumBytes,
      purpose: .configuration
    ) {
      let handle = try FileHandle(forWritingTo: mutableURL)
      try handle.seek(toOffset: 0)
      try handle.write(contentsOf: Data(" ".utf8))
      try handle.synchronize()
      try handle.close()
    }
  }
}

@Test func reportFileRejectsOversizeAndPathReplacementCannotChangeReadBytes() throws {
  let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
  defer { try? FileManager.default.removeItem(at: directory) }

  let oversizedURL = directory.appendingPathComponent("oversized-report.json")
  try Data(repeating: 65, count: 65_537).write(to: oversizedURL)
  #expect(throws: GatewayError.self) {
    try SecureFileReader.read(
      path: oversizedURL.path, maximumBytes: 65_536, purpose: .reportRequest)
  }

  let original = Data(#"{"advertiser_id":"123"}"#.utf8)
  let reportURL = directory.appendingPathComponent("report.json")
  let movedURL = directory.appendingPathComponent("opened-report.json")
  try original.write(to: reportURL)
  do {
    let data = try SecureFileReader.read(
      path: reportURL.path,
      maximumBytes: 65_536,
      purpose: .reportRequest
    ) {
      try FileManager.default.moveItem(at: reportURL, to: movedURL)
      try Data(#"{"advertiser_id":"999"}"#.utf8).write(to: reportURL)
    }
    #expect(data == original)
  } catch let error as GatewayError {
    #expect(error.code == .invalidArgument)
  }
}

private func validConfigurationData() throws -> Data {
  try JSONOutput.encode(
    GatewayConfiguration(profiles: [
      GatewayProfile(
        id: "sandbox-reader",
        capability: .reader,
        accessTokenEnvironmentVariable: "TIKTOK_READER_TOKEN",
        advertiserIDs: ["123"],
        operations: [.campaignsList]
      )
    ]))
}

private actor QueueTransport: HTTPTransport {
  private var results: [Result<HTTPResponse, TransportError>]
  private(set) var requests: [HTTPRequest] = []

  init(results: [Result<HTTPResponse, TransportError>]) { self.results = results }

  var requestCount: Int { requests.count }

  func send(_ request: HTTPRequest) async throws -> HTTPResponse {
    requests.append(request)
    guard !results.isEmpty else { throw TransportError(phase: .outcomeUnknown) }
    return try results.removeFirst().get()
  }
}

private actor RecordingSleeper: RetrySleeping {
  private(set) var sleepCount = 0
  func sleep(nanoseconds _: UInt64) async throws { sleepCount += 1 }
}

private struct RequiredPayload: Decodable, Sendable {
  let required: String
}
