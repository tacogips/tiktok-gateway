import Foundation
import TikTokBusinessGatewayShared

public struct TikTokWriterClient: Sendable {
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
      testingOperationGate: WriterOperationCatalog.operationGate
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
    guard profile.capability == .writer else {
      throw GatewayError(.unauthorizedOperation, message: "Writer client requires a writer profile")
    }
    guard Set(profile.operations).isSubset(of: WriterOperationCatalog.enabledOperations) else {
      throw GatewayError(
        .unauthorizedOperation, message: "Writer profile contains an unknown operation")
    }
    self.profile = profile
    self.credentials = credentials
    self.operationGate = testingOperationGate
    self.executor = TikTokAPIExecutor(transport: transport, sleeper: sleeper)
  }

  public func updateCampaignStatus(
    advertiserID: String,
    campaignID: String,
    family: CampaignFamily,
    status: DeliveryStatus
  ) async throws -> StatusUpdateResult {
    try family.validateForStatusUpdate()
    return try await update(
      operation: .campaignsStatusUpdate,
      advertiserID: advertiserID,
      resourceID: campaignID,
      status: status,
      body: CampaignStatusBody(
        advertiserID: advertiserID,
        campaignIDs: [campaignID],
        operationStatus: status
      )
    )
  }

  public func updateAdGroupStatus(
    advertiserID: String,
    adGroupID: String,
    family: AdGroupFamily,
    status: DeliveryStatus
  ) async throws -> StatusUpdateResult {
    try family.validateForStatusUpdate()
    return try await update(
      operation: .adGroupsStatusUpdate,
      advertiserID: advertiserID,
      resourceID: adGroupID,
      status: status,
      body: AdGroupStatusBody(
        advertiserID: advertiserID,
        adGroupIDs: [adGroupID],
        operationStatus: status
      )
    )
  }

  public func updateAdStatus(
    advertiserID: String,
    adID: String,
    family: AdFamily,
    status: DeliveryStatus
  ) async throws -> StatusUpdateResult {
    try family.validateForStatusUpdate()
    return try await update(
      operation: .adsStatusUpdate,
      advertiserID: advertiserID,
      resourceID: adID,
      status: status,
      body: AdStatusBody(advertiserID: advertiserID, adIDs: [adID], operationStatus: status)
    )
  }

  private func update<Body: Encodable>(
    operation: OperationID,
    advertiserID: String,
    resourceID: String,
    status: DeliveryStatus,
    body: Body
  ) async throws -> StatusUpdateResult {
    try IdentifierValidator.requireCanonicalDecimal(advertiserID, name: "advertiser_id")
    try IdentifierValidator.requireCanonicalDecimal(resourceID, name: "resource_id")
    try profile.authorize(operation, advertiserID: advertiserID)
    try operationGate.requireEnabled(operation)
    let encoded: Data
    do { encoded = try JSONEncoder().encode(body) } catch {
      throw GatewayError(.invalidArgument, message: "Unable to encode status update")
    }
    let secret = try credentials.resolve(for: profile, operation: operation)
    let request = try WriterRequestFactory.make(
      operation: operation,
      body: encoded,
      credentials: secret
    )
    let envelope: TikTokEnvelope<JSONValue> = try await executor.execute(
      request: request,
      retryMode: .preDispatchOnly
    )
    return StatusUpdateResult(
      operation: operation,
      advertiserID: advertiserID,
      resourceID: resourceID,
      requestedStatus: status,
      requestID: envelope.requestID,
      providerData: envelope.data
    )
  }
}
