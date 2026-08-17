import Foundation
import Testing
import TikTokBusinessGatewayShared

@testable import TikTokBusinessGatewayReaderCore

@Test func authorizedAdvertisersDecodeFixtureAndIntersectAllowlist() async throws {
  let transport = ReaderTransport(response: try fixtureResponse("authorized-advertisers-response"))
  let profile = GatewayProfile(
    id: "sandbox-reader",
    capability: .reader,
    accessTokenEnvironmentVariable: "TIKTOK_READER_TOKEN",
    appID: "fake-app",
    appSecretEnvironmentVariable: "TIKTOK_APP_SECRET",
    advertiserIDs: ["123"],
    operations: [.advertisersList]
  )
  let client = try TikTokReaderClient(
    profile: profile,
    transport: transport,
    credentials: FixedCredentials(),
    testingOperationGate: allowAllOperations
  )
  let advertisers = try await client.authorizedAdvertisers()
  #expect(advertisers.map(\.advertiserID) == ["123"])
  let request = try #require(await transport.lastRequest)
  #expect(request.headers["Access-Token"] == "fake-token")
  #expect(request.url.query?.contains("app_id=fake-app") == true)
  #expect(request.url.query?.contains("secret=fake-secret") == true)
}

@Test func authorizedAdvertisersRejectsMissingData() async throws {
  let response = HTTPResponse(
    statusCode: 200,
    body: Data(#"{"code":0,"message":"OK","request_id":"missing-data"}"#.utf8)
  )
  let client = try TikTokReaderClient(
    profile: GatewayProfile(
      id: "sandbox-reader",
      capability: .reader,
      accessTokenEnvironmentVariable: "TIKTOK_READER_TOKEN",
      appID: "fake-app",
      appSecretEnvironmentVariable: "TIKTOK_APP_SECRET",
      advertiserIDs: ["123"],
      operations: [.advertisersList]
    ),
    transport: ReaderTransport(response: response),
    credentials: FixedCredentials(),
    testingOperationGate: allowAllOperations
  )
  do {
    _ = try await client.authorizedAdvertisers()
    Issue.record("Expected missing advertiser data to fail")
  } catch let error as GatewayError {
    #expect(error.code == .invalidResponse)
  }
}

@Test func productionEvidenceGatePermitsReviewedOperation() async throws {
  let transport = ReaderTransport(response: try fixtureResponse("campaigns-response"))
  let client = try TikTokReaderClient(
    profile: readerProfile(operations: [.campaignsList]),
    transport: transport,
    credentials: FixedCredentials()
  )
  _ = try await client.campaigns(advertiserID: "123", page: PageRequest())
  #expect(await transport.lastRequest != nil)
}

@Test func advertiserInfoDecodesFixtureAndBuildsExactRoute() async throws {
  let transport = ReaderTransport(response: try fixtureResponse("advertiser-info-response"))
  let client = try readerClient(operation: .advertisersGet, transport: transport)
  let advertiser = try await client.advertiserInfo(advertiserID: "123")
  #expect(advertiser.advertiserID == "123")
  #expect(advertiser.currency == "JPY")
  let request = try #require(await transport.lastRequest)
  #expect(request.url.absoluteString.contains("/open_api/v1.3/advertiser/info/?"))
  #expect(request.url.query?.contains("advertiser_ids") == true)
}

@Test func campaignsDecodeTypedPageAndInjectAccessToken() async throws {
  let transport = ReaderTransport(response: try fixtureResponse("campaigns-response"))
  let client = try readerClient(operation: .campaignsList, transport: transport)
  let page = try await client.campaigns(
    advertiserID: "123",
    campaignIDs: ["987"],
    page: PageRequest(page: 1, pageSize: 100)
  )
  #expect(page.items.first?.campaignID == "987")
  #expect(page.endReached)
  let request = try #require(await transport.lastRequest)
  #expect(request.headers["Access-Token"] == "fake-token")
  #expect(request.url.absoluteString.contains("/open_api/v1.3/campaign/get/?"))
  #expect(request.url.query?.contains("advertiser_id=123") == true)
}

@Test func adGroupsDecodeTypedFixtureAndFiltering() async throws {
  let transport = ReaderTransport(response: try fixtureResponse("adgroups-response"))
  let client = try readerClient(operation: .adGroupsList, transport: transport)
  let page = try await client.adGroups(
    advertiserID: "123",
    adGroupIDs: ["654"],
    page: PageRequest()
  )
  #expect(page.items.first?.adGroupID == "654")
  #expect(page.items.first?.campaignID == "987")
  let request = try #require(await transport.lastRequest)
  #expect(request.url.absoluteString.contains("/open_api/v1.3/adgroup/get/?"))
  #expect(request.url.query?.contains("filtering") == true)
}

@Test func adsDecodeTypedFixtureAndFiltering() async throws {
  let transport = ReaderTransport(response: try fixtureResponse("ads-response"))
  let client = try readerClient(operation: .adsList, transport: transport)
  let page = try await client.ads(advertiserID: "123", adIDs: ["321"], page: PageRequest())
  #expect(page.items.first?.adID == "321")
  #expect(page.items.first?.adGroupID == "654")
  let request = try #require(await transport.lastRequest)
  #expect(request.url.absoluteString.contains("/open_api/v1.3/ad/get/?"))
  #expect(request.url.query?.contains("filtering") == true)
}

@Test func synchronousReportDecodesProviderStrings() async throws {
  let transport = ReaderTransport(response: try fixtureResponse("report-response"))
  let client = try readerClient(operation: .reportsIntegrated, transport: transport)
  let report = SynchronousReportRequest(
    advertiserID: "123",
    dataLevel: .campaign,
    dimensions: ["campaign_id", "stat_time_day"],
    metrics: ["spend", "impressions"],
    startDate: "2026-08-15",
    endDate: "2026-08-15"
  )
  let page = try await client.synchronousReport(report, now: Date.distantFuture)
  #expect(page.items.first?.metrics["spend"] == .string("12.34"))
  let request = try #require(await transport.lastRequest)
  #expect(request.url.absoluteString.contains("/open_api/v1.3/report/integrated/get/?"))
  #expect(request.url.query?.contains("report_type=BASIC") == true)
}

@Test func reportValidationRejectsFutureDatesBeforeTransport() async throws {
  let transport = ReaderTransport(response: HTTPResponse(statusCode: 200, body: Data()))
  let client = try readerClient(operation: .reportsIntegrated, transport: transport)
  let request = SynchronousReportRequest(
    advertiserID: "123",
    dataLevel: .campaign,
    dimensions: ["campaign_id"],
    metrics: ["spend"],
    startDate: "2026-08-17",
    endDate: "2026-08-17"
  )
  await #expect(throws: GatewayError.self) {
    _ = try await client.synchronousReport(request, now: Date(timeIntervalSince1970: 1_776_297_600))
  }
  #expect(await transport.lastRequest == nil)
}

@Test func paginationRejectsUnsafeBoundsAndInconsistentProviderMetadata() async throws {
  #expect(throws: GatewayError.self) {
    try PageRequest(page: PaginationBounds.maximumPage + 1)
  }
  #expect(throws: GatewayError.self) {
    try GatewayPage(
      items: ["full"],
      pageInfo: TikTokPageInfo(
        page: PaginationBounds.maximumPage,
        pageSize: 1,
        totalNumber: nil,
        totalPage: nil
      )
    )
  }

  let response = HTTPResponse(
    statusCode: 200,
    body: Data(
      #"{"code":0,"message":"OK","data":{"list":[],"page_info":{"page":1,"page_size":99,"total_number":0,"total_page":1}}}"#
        .utf8
    )
  )
  let client = try readerClient(
    operation: .campaignsList,
    transport: ReaderTransport(response: response)
  )
  await #expect(throws: GatewayError.self) {
    _ = try await client.campaigns(advertiserID: "123", page: PageRequest())
  }
}

@Test func paginationValidatesContradictoryTotalsAndUsesTotalNumber() throws {
  #expect(throws: GatewayError.self) {
    try GatewayPage(
      items: Array(repeating: "item", count: 100),
      pageInfo: TikTokPageInfo(
        page: 1,
        pageSize: 100,
        totalNumber: 101,
        totalPage: 1
      )
    )
  }
  #expect(throws: GatewayError.self) {
    try GatewayPage(
      items: ["item"],
      pageInfo: TikTokPageInfo(
        page: 1,
        pageSize: 1,
        totalNumber: Int.max,
        totalPage: nil
      )
    )
  }

  let firstPage = try GatewayPage(
    items: Array(repeating: "item", count: 100),
    pageInfo: TikTokPageInfo(
      page: 1,
      pageSize: 100,
      totalNumber: 150,
      totalPage: nil
    )
  )
  #expect(!firstPage.endReached)
  #expect(firstPage.nextPage == 2)

  let completePage = try GatewayPage(
    items: Array(repeating: "item", count: 100),
    pageInfo: TikTokPageInfo(
      page: 1,
      pageSize: 100,
      totalNumber: 100,
      totalPage: nil
    )
  )
  #expect(completePage.endReached)
  #expect(completePage.nextPage == nil)
}

@Test func missingConfigurationMapsToConfigurationExitCode() async {
  let cli = ReaderCLI(
    transport: ReaderTransport(response: HTTPResponse(statusCode: 200, body: Data())))
  let result = await cli.run(arguments: [
    "config", "validate", "--config", "/definitely/missing/profiles.json",
  ])
  #expect(result.exitCode == 2)
  #expect(result.stderr.contains("invalidConfiguration"))
}

@Test func missingReportFileMapsToArgumentExitCode() async throws {
  let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
  defer { try? FileManager.default.removeItem(at: directory) }
  let configURL = directory.appendingPathComponent("profiles.json")
  try JSONOutput.encode(
    GatewayConfiguration(profiles: [readerProfile(operations: [.reportsIntegrated])])
  ).write(to: configURL)
  let cli = ReaderCLI(
    transport: ReaderTransport(response: HTTPResponse(statusCode: 200, body: Data())),
    credentials: FixedCredentials()
  )
  let result = await cli.run(arguments: [
    "reports", "integrated", "--config", configURL.path, "--profile", "sandbox-reader",
    "--request-file", directory.appendingPathComponent("missing-report.json").path,
  ])
  #expect(result.exitCode == 2)
  #expect(result.stderr.contains("invalidArgument"))
}

@Test func oversizedReportFileMapsToArgumentExitCodeWithoutNetwork() async throws {
  let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
  defer { try? FileManager.default.removeItem(at: directory) }
  let configURL = directory.appendingPathComponent("profiles.json")
  try JSONOutput.encode(
    GatewayConfiguration(profiles: [readerProfile(operations: [.reportsIntegrated])])
  ).write(to: configURL)
  let reportURL = directory.appendingPathComponent("oversized-report.json")
  try Data(repeating: 65, count: 65_537).write(to: reportURL)
  let transport = ReaderTransport(response: HTTPResponse(statusCode: 200, body: Data()))
  let result = await ReaderCLI(transport: transport, credentials: FixedCredentials()).run(
    arguments: [
      "reports", "integrated", "--config", configURL.path, "--profile", "sandbox-reader",
      "--request-file", reportURL.path,
    ])
  #expect(result.exitCode == 2)
  #expect(result.stderr.contains("invalidArgument"))
  #expect(await transport.lastRequest == nil)
}

private func readerClient(operation: OperationID, transport: ReaderTransport) throws
  -> TikTokReaderClient
{
  try TikTokReaderClient(
    profile: readerProfile(operations: [operation]),
    transport: transport,
    credentials: FixedCredentials(),
    testingOperationGate: allowAllOperations
  )
}

private let allowAllOperations = StaticOperationGate(
  enabledOperations: OperationCatalog.enabledOperations)

private func readerProfile(operations: [OperationID]) -> GatewayProfile {
  GatewayProfile(
    id: "sandbox-reader",
    capability: .reader,
    accessTokenEnvironmentVariable: "TIKTOK_READER_TOKEN",
    advertiserIDs: ["123"],
    operations: operations
  )
}

private func fixtureResponse(_ name: String) throws -> HTTPResponse {
  let url = try #require(
    Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
  return try HTTPResponse(statusCode: 200, body: Data(contentsOf: url))
}

private struct FixedCredentials: CredentialResolving {
  func resolve(for _: GatewayProfile, operation: OperationID) throws -> GatewayCredentials {
    GatewayCredentials(
      accessToken: "fake-token",
      appID: operation == .advertisersList ? "fake-app" : nil,
      appSecret: operation == .advertisersList ? "fake-secret" : nil
    )
  }
}

private actor ReaderTransport: HTTPTransport {
  let response: HTTPResponse
  private(set) var lastRequest: HTTPRequest?

  init(response: HTTPResponse) { self.response = response }
  func send(_ request: HTTPRequest) async throws -> HTTPResponse {
    lastRequest = request
    return response
  }
}
