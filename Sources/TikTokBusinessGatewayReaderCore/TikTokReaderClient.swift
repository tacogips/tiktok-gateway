import Foundation
import TikTokBusinessGatewayShared

public struct TikTokReaderClient: Sendable {
  private let profile: GatewayProfile
  private let credentials: any CredentialResolving
  private let operationGate: any OperationGating
  private let executor: TikTokAPIExecutor

  public init(
    profile: GatewayProfile,
    transport: any HTTPTransport = URLSessionHTTPTransport(),
    credentials: any CredentialResolving = EnvironmentCredentialResolver(),
    sleeper: any RetrySleeping = TaskRetrySleeper()
  ) throws {
    try self.init(
      profile: profile,
      transport: transport,
      credentials: credentials,
      sleeper: sleeper,
      testingOperationGate: OperationCatalog.operationGate
    )
  }

  init(
    profile: GatewayProfile,
    transport: any HTTPTransport,
    credentials: any CredentialResolving,
    sleeper: any RetrySleeping = TaskRetrySleeper(),
    testingOperationGate: any OperationGating
  ) throws {
    try profile.validate()
    guard profile.capability == .reader else {
      throw GatewayError(.unauthorizedOperation, message: "Reader client requires a reader profile")
    }
    guard Set(profile.operations).isSubset(of: OperationCatalog.enabledOperations) else {
      throw GatewayError(
        .unauthorizedOperation, message: "Reader profile contains an unknown operation")
    }
    self.profile = profile
    self.credentials = credentials
    self.operationGate = testingOperationGate
    self.executor = TikTokAPIExecutor(transport: transport, sleeper: sleeper)
  }

  public func authorizedAdvertisers() async throws -> [AuthorizedAdvertiser] {
    let operation = OperationID.advertisersList
    try profile.authorize(operation)
    try operationGate.requireEnabled(operation)
    let secret = try credentials.resolve(for: profile, operation: operation)
    let envelope: TikTokEnvelope<ItemsPayload<AuthorizedAdvertiser>> = try await executor.execute(
      operation: operation,
      credentials: secret
    )
    guard let data = envelope.data else {
      throw GatewayError(.invalidResponse, message: "TikTok response omitted advertiser data")
    }
    let allowed = Set(profile.advertiserIDs)
    return data.list.filter { allowed.contains($0.advertiserID) }
  }

  public func advertiserInfo(advertiserID: String) async throws -> AdvertiserInfo {
    let operation = OperationID.advertisersGet
    try validate(operation, advertiserID: advertiserID)
    let fields = ["advertiser_id", "name", "status", "timezone", "currency"]
    let payload: TikTokEnvelope<ItemsPayload<AdvertiserInfo>> = try await read(
      operation,
      queryItems: [
        jsonQuery("advertiser_ids", [advertiserID]),
        jsonQuery("fields", fields),
      ]
    )
    guard let item = payload.data?.list.first(where: { $0.advertiserID == advertiserID }) else {
      throw GatewayError(
        .invalidResponse, message: "TikTok did not return the requested advertiser")
    }
    return item
  }

  public func campaigns(
    advertiserID: String,
    campaignIDs: [String] = [],
    page: PageRequest
  ) async throws -> GatewayPage<CampaignSummary> {
    try validateIDs(campaignIDs, name: "campaign_ids")
    return try await list(
      operation: .campaignsList,
      advertiserID: advertiserID,
      filterName: "campaign_ids",
      ids: campaignIDs,
      fields: [
        "campaign_id", "campaign_name", "operation_status", "secondary_status", "create_time",
        "modify_time",
      ],
      page: page
    )
  }

  public func adGroups(
    advertiserID: String,
    adGroupIDs: [String] = [],
    page: PageRequest
  ) async throws -> GatewayPage<AdGroupSummary> {
    try validateIDs(adGroupIDs, name: "adgroup_ids")
    return try await list(
      operation: .adGroupsList,
      advertiserID: advertiserID,
      filterName: "adgroup_ids",
      ids: adGroupIDs,
      fields: [
        "adgroup_id", "campaign_id", "adgroup_name", "operation_status", "secondary_status",
        "create_time", "modify_time",
      ],
      page: page
    )
  }

  public func ads(
    advertiserID: String,
    adIDs: [String] = [],
    page: PageRequest
  ) async throws -> GatewayPage<AdSummary> {
    try validateIDs(adIDs, name: "ad_ids")
    return try await list(
      operation: .adsList,
      advertiserID: advertiserID,
      filterName: "ad_ids",
      ids: adIDs,
      fields: [
        "ad_id", "adgroup_id", "campaign_id", "ad_name", "operation_status", "secondary_status",
        "create_time", "modify_time",
      ],
      page: page
    )
  }

  public func synchronousReport(
    _ request: SynchronousReportRequest,
    now: Date = Date()
  ) async throws -> GatewayPage<ReportRow> {
    let operation = OperationID.reportsIntegrated
    try request.validate(now: now)
    try profile.authorize(operation, advertiserID: request.advertiserID)
    let query = [
      URLQueryItem(name: "advertiser_id", value: request.advertiserID),
      URLQueryItem(name: "report_type", value: "BASIC"),
      URLQueryItem(name: "data_level", value: request.dataLevel.rawValue),
      jsonQuery("dimensions", request.dimensions),
      jsonQuery("metrics", request.metrics),
      URLQueryItem(name: "start_date", value: request.startDate),
      URLQueryItem(name: "end_date", value: request.endDate),
      URLQueryItem(name: "page", value: String(request.page)),
      URLQueryItem(name: "page_size", value: String(request.pageSize)),
    ]
    let envelope: TikTokEnvelope<ListPayload<ReportRow>> = try await read(
      operation, queryItems: query)
    guard let data = envelope.data else {
      throw GatewayError(.invalidResponse, message: "TikTok response omitted report data")
    }
    guard data.pageInfo.page == request.page, data.pageInfo.pageSize == request.pageSize else {
      throw GatewayError(.invalidResponse, message: "TikTok returned inconsistent page metadata")
    }
    return try GatewayPage(items: data.list, pageInfo: data.pageInfo)
  }

  private func list<Item: Codable & Sendable>(
    operation: OperationID,
    advertiserID: String,
    filterName: String,
    ids: [String],
    fields: [String],
    page: PageRequest
  ) async throws -> GatewayPage<Item> {
    try validate(operation, advertiserID: advertiserID)
    var query = [
      URLQueryItem(name: "advertiser_id", value: advertiserID),
      jsonQuery("fields", fields),
      URLQueryItem(name: "page", value: String(page.page)),
      URLQueryItem(name: "page_size", value: String(page.pageSize)),
    ]
    if !ids.isEmpty { query.append(jsonQuery("filtering", [filterName: ids])) }
    let envelope: TikTokEnvelope<ListPayload<Item>> = try await read(operation, queryItems: query)
    guard let data = envelope.data else {
      throw GatewayError(.invalidResponse, message: "TikTok response omitted page data")
    }
    guard data.pageInfo.page == page.page, data.pageInfo.pageSize == page.pageSize else {
      throw GatewayError(.invalidResponse, message: "TikTok returned inconsistent page metadata")
    }
    return try GatewayPage(items: data.list, pageInfo: data.pageInfo)
  }

  private func read<Payload: Decodable & Sendable>(
    _ operation: OperationID,
    queryItems: [URLQueryItem]
  ) async throws -> TikTokEnvelope<Payload> {
    try operationGate.requireEnabled(operation)
    let secret = try credentials.resolve(for: profile, operation: operation)
    return try await executor.execute(
      operation: operation,
      queryItems: queryItems,
      credentials: secret
    )
  }

  private func validate(_ operation: OperationID, advertiserID: String) throws {
    try IdentifierValidator.requireCanonicalDecimal(advertiserID, name: "advertiser_id")
    try profile.authorize(operation, advertiserID: advertiserID)
  }

  private func validateIDs(_ ids: [String], name: String) throws {
    guard ids.count <= 100, Set(ids).count == ids.count else {
      throw GatewayError(
        .invalidArgument, message: "\(name) must contain at most 100 unique identifiers")
    }
    for id in ids { try IdentifierValidator.requireCanonicalDecimal(id, name: name) }
  }

  private func jsonQuery<Value: Encodable>(_ name: String, _ value: Value) -> URLQueryItem {
    let data = try? JSONEncoder().encode(value)
    return URLQueryItem(name: name, value: data.flatMap { String(bytes: $0, encoding: .utf8) })
  }
}
