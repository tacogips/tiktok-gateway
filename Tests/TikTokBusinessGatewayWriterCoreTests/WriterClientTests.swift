import Foundation
import Testing
import TikTokBusinessGatewayShared

@testable import TikTokBusinessGatewayWriterCore

@Test func writerEvidenceCatalogEnablesOnlyReviewedMutations() throws {
  #expect(WriterOperationCatalog.entries.count == 3)
  #expect(WriterOperationCatalog.entries.allSatisfy { $0.enabled && $0.method == .post })
  for operation in WriterOperationCatalog.enabledOperations {
    try WriterOperationCatalog.operationGate.requireEnabled(operation)
  }
}

@Test func campaignUpdateMatchesPositiveBodyFixture() async throws {
  let transport = WriterTransport(result: .success(try fixtureResponse()))
  let client = try writerClient(operation: .campaignsStatusUpdate, transport: transport)
  _ = try await client.updateCampaignStatus(
    advertiserID: "123",
    campaignID: "456",
    family: .manual,
    status: .enable
  )
  try await expectBody(transport: transport, fixture: "campaign-status-body")
}

@Test func adGroupUpdateIsSingleResourceAndDisablesPartialSuccess() async throws {
  let transport = WriterTransport(result: .success(try fixtureResponse()))
  let client = try writerClient(operation: .adGroupsStatusUpdate, transport: transport)
  let result = try await client.updateAdGroupStatus(
    advertiserID: "123",
    adGroupID: "456",
    family: .manual,
    status: .disable
  )
  #expect(result.requestedStatus == .disable)
  let request = try #require(await transport.lastRequest)
  #expect(request.method == .post)
  #expect(request.url.absoluteString.hasSuffix("/open_api/v1.3/adgroup/status/update/"))
  try await expectBody(transport: transport, fixture: "adgroup-status-body")
}

@Test func adUpdateMatchesPositiveBodyFixture() async throws {
  let transport = WriterTransport(result: .success(try fixtureResponse()))
  let client = try writerClient(operation: .adsStatusUpdate, transport: transport)
  _ = try await client.updateAdStatus(
    advertiserID: "123", adID: "456", family: .manual, status: .enable)
  try await expectBody(transport: transport, fixture: "ad-status-body")
}

@Test func unsupportedCampaignFamilyFailsBeforeCredentialsAndNetwork() async throws {
  let transport = WriterTransport(result: .success(try fixtureResponse()))
  let client = try TikTokWriterClient(
    profile: writerProfile(.campaignsStatusUpdate),
    transport: transport,
    credentials: MissingCredentials()
  )
  do {
    _ = try await client.updateCampaignStatus(
      advertiserID: "123",
      campaignID: "456",
      family: .smartPlus,
      status: .enable
    )
    Issue.record("Expected resource-family rejection")
  } catch let error as GatewayError {
    #expect(error.code == .invalidArgument)
  }
  #expect(await transport.requestCount == 0)
}

@Test func reachAndFrequencyAdGroupFailsBeforeCredentialsAndNetwork() async throws {
  let transport = WriterTransport(result: .success(try fixtureResponse()))
  let client = try TikTokWriterClient(
    profile: writerProfile(.adGroupsStatusUpdate),
    transport: transport,
    credentials: MissingCredentials()
  )
  do {
    _ = try await client.updateAdGroupStatus(
      advertiserID: "123",
      adGroupID: "456",
      family: .reachAndFrequency,
      status: .disable
    )
    Issue.record("Expected resource-family rejection")
  } catch let error as GatewayError {
    #expect(error.code == .invalidArgument)
  }
  #expect(await transport.requestCount == 0)
}

@Test func writerDoesNotRetryOutcomeUnknownFailure() async throws {
  let transport = WriterTransport(result: .failure(TransportError(phase: .outcomeUnknown)))
  let client = try writerClient(operation: .adsStatusUpdate, transport: transport)
  await #expect(throws: GatewayError.self) {
    _ = try await client.updateAdStatus(
      advertiserID: "123", adID: "456", family: .manual, status: .enable)
  }
  #expect(await transport.requestCount == 1)
}

@Test func writerRejectsUnallowlistedAdvertiserBeforeCredentialResolution() async throws {
  let transport = WriterTransport(result: .success(try fixtureResponse()))
  let client = try TikTokWriterClient(
    profile: writerProfile(.campaignsStatusUpdate),
    transport: transport,
    credentials: MissingCredentials()
  )
  do {
    _ = try await client.updateCampaignStatus(
      advertiserID: "999",
      campaignID: "456",
      family: .manual,
      status: .enable
    )
    Issue.record("Expected authorization failure")
  } catch let error as GatewayError {
    #expect(error.code == .unauthorizedOperation)
  }
  #expect(await transport.requestCount == 0)
}

@Test func writerRetriesOnlyExplicitPreDispatchFailure() async throws {
  let transport = WriterTransport(result: .failure(TransportError(phase: .preDispatch)))
  let client = try TikTokWriterClient(
    profile: writerProfile(.campaignsStatusUpdate),
    transport: transport,
    credentials: WriterCredentials(),
    sleeper: ImmediateSleeper(),
    testingOperationGate: allowAllOperations
  )
  await #expect(throws: GatewayError.self) {
    _ = try await client.updateCampaignStatus(
      advertiserID: "123",
      campaignID: "456",
      family: .manual,
      status: .disable
    )
  }
  #expect(await transport.requestCount == 3)
}

@Test func writerRetriesCannotConnectToHostAsPreDispatchTransientFailure() async throws {
  let classified = URLSessionHTTPTransport.classify(URLError(.cannotConnectToHost))
  #expect(classified.phase == .preDispatch)
  #expect(classified.transience == .transient)
  let transport = QueueWriterTransport(results: [
    .failure(classified),
    .success(try fixtureResponse()),
  ])
  let client = try TikTokWriterClient(
    profile: writerProfile(.adsStatusUpdate),
    transport: transport,
    credentials: WriterCredentials(),
    sleeper: ImmediateSleeper(),
    testingOperationGate: allowAllOperations
  )
  _ = try await client.updateAdStatus(
    advertiserID: "123", adID: "456", family: .manual, status: .enable)
  #expect(await transport.requestCount == 2)
}

@Test func writerCLIRejectsMismatchedConfirmationBeforeCredentialsOrNetwork() async throws {
  let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
  defer { try? FileManager.default.removeItem(at: directory) }
  let configURL = directory.appendingPathComponent("profiles.json")
  let configuration = GatewayConfiguration(profiles: [writerProfile(.adsStatusUpdate)])
  try JSONOutput.encode(configuration).write(to: configURL)
  let transport = WriterTransport(result: .success(try fixtureResponse()))
  let cli = WriterCLI(transport: transport, credentials: MissingCredentials())
  let result = await cli.run(arguments: [
    "ads", "status", "update", "--config", configURL.path, "--profile", "sandbox-writer",
    "--advertiser-id", "123", "--resource-id", "456", "--resource-family", "MANUAL",
    "--status", "ENABLE", "--confirm-status", "DISABLE",
  ])
  #expect(result.exitCode == 2)
  #expect(await transport.requestCount == 0)
}

private func writerClient(operation: OperationID, transport: WriterTransport) throws
  -> TikTokWriterClient
{
  try TikTokWriterClient(
    profile: writerProfile(operation),
    transport: transport,
    credentials: WriterCredentials(),
    testingOperationGate: allowAllOperations
  )
}

private let allowAllOperations = StaticOperationGate(
  enabledOperations: WriterOperationCatalog.enabledOperations)

private func writerProfile(_ operation: OperationID) -> GatewayProfile {
  GatewayProfile(
    id: "sandbox-writer",
    capability: .writer,
    accessTokenEnvironmentVariable: "TIKTOK_WRITER_TOKEN",
    advertiserIDs: ["123"],
    operations: [operation]
  )
}

private func fixtureData(_ name: String) throws -> Data {
  let url = try #require(
    Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
  return try Data(contentsOf: url)
}

private func fixtureResponse() throws -> HTTPResponse {
  try HTTPResponse(statusCode: 200, body: fixtureData("status-update-response"))
}

private func expectBody(transport: WriterTransport, fixture: String) async throws {
  let request = try #require(await transport.lastRequest)
  let actual = try JSONSerialization.jsonObject(with: try #require(request.body)) as? NSDictionary
  let expected = try JSONSerialization.jsonObject(with: fixtureData(fixture)) as? NSDictionary
  #expect(actual == expected)
}

private struct WriterCredentials: CredentialResolving {
  func resolve(for _: GatewayProfile, operation _: OperationID) throws -> GatewayCredentials {
    GatewayCredentials(accessToken: "fake-token")
  }
}

private struct MissingCredentials: CredentialResolving {
  func resolve(for _: GatewayProfile, operation _: OperationID) throws -> GatewayCredentials {
    throw GatewayError(.missingCredential, message: "credentials should not be resolved")
  }
}

private struct ImmediateSleeper: RetrySleeping {
  func sleep(nanoseconds _: UInt64) async throws {}
}

private actor WriterTransport: HTTPTransport {
  let result: Result<HTTPResponse, TransportError>
  private(set) var lastRequest: HTTPRequest?
  private(set) var requestCount = 0

  init(result: Result<HTTPResponse, TransportError>) { self.result = result }
  func send(_ request: HTTPRequest) async throws -> HTTPResponse {
    requestCount += 1
    lastRequest = request
    return try result.get()
  }
}

private actor QueueWriterTransport: HTTPTransport {
  private var results: [Result<HTTPResponse, TransportError>]
  private(set) var requestCount = 0

  init(results: [Result<HTTPResponse, TransportError>]) { self.results = results }

  func send(_: HTTPRequest) async throws -> HTTPResponse {
    requestCount += 1
    guard !results.isEmpty else {
      throw TransportError(phase: .outcomeUnknown, transience: .permanent)
    }
    return try results.removeFirst().get()
  }
}
