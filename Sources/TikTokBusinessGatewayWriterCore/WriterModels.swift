import Foundation
import TikTokBusinessGatewayShared

public enum DeliveryStatus: String, Codable, CaseIterable, Sendable {
  case enable = "ENABLE"
  case disable = "DISABLE"
}

public enum CampaignFamily: String, Codable, Sendable {
  case manual = "MANUAL"
  case smartPlus = "SMART_PLUS"
  case reachAndFrequency = "REACH_AND_FREQUENCY"

  func validateForStatusUpdate() throws {
    guard self == .manual else {
      throw GatewayError(
        .invalidArgument, message: "Campaign status updates require the MANUAL resource family")
    }
  }
}

public enum AdGroupFamily: String, Codable, Sendable {
  case manual = "MANUAL"
  case reachAndFrequency = "REACH_AND_FREQUENCY"

  func validateForStatusUpdate() throws {
    guard self == .manual else {
      throw GatewayError(
        .invalidArgument, message: "Ad-group status updates require the MANUAL resource family")
    }
  }
}

public enum AdFamily: String, Codable, Sendable {
  case manual = "MANUAL"
  case automatedCreativeOptimization = "AUTOMATED_CREATIVE_OPTIMIZATION"

  func validateForStatusUpdate() throws {
    guard self == .manual else {
      throw GatewayError(
        .invalidArgument, message: "Ad status updates require the MANUAL resource family")
    }
  }
}

public struct StatusUpdateResult: Codable, Sendable {
  public let operation: OperationID
  public let advertiserID: String
  public let resourceID: String
  public let requestedStatus: DeliveryStatus
  public let requestID: String?
  public let providerData: JSONValue?

  enum CodingKeys: String, CodingKey {
    case operation
    case advertiserID = "advertiser_id"
    case resourceID = "resource_id"
    case requestedStatus = "requested_status"
    case requestID = "request_id"
    case providerData = "provider_data"
  }
}

struct CampaignStatusBody: Encodable {
  let advertiserID: String
  let campaignIDs: [String]
  let operationStatus: DeliveryStatus

  enum CodingKeys: String, CodingKey {
    case advertiserID = "advertiser_id"
    case campaignIDs = "campaign_ids"
    case operationStatus = "operation_status"
  }
}

struct AdGroupStatusBody: Encodable {
  let advertiserID: String
  let adGroupIDs: [String]
  let operationStatus: DeliveryStatus
  let allowPartialSuccess = false

  enum CodingKeys: String, CodingKey {
    case advertiserID = "advertiser_id"
    case adGroupIDs = "adgroup_ids"
    case operationStatus = "operation_status"
    case allowPartialSuccess = "allow_partial_success"
  }
}

struct AdStatusBody: Encodable {
  let advertiserID: String
  let adIDs: [String]
  let operationStatus: DeliveryStatus

  enum CodingKeys: String, CodingKey {
    case advertiserID = "advertiser_id"
    case adIDs = "ad_ids"
    case operationStatus = "operation_status"
  }
}
