import Foundation

public enum GatewayCapability: String, Codable, Sendable {
  case reader
  case writer
}

public enum HTTPMethod: String, Codable, Sendable {
  case get = "GET"
  case post = "POST"
}

public struct OperationID: RawRepresentable, Codable, Hashable, Sendable {
  public let rawValue: String

  public init(rawValue: String) { self.rawValue = rawValue }

  public init(from decoder: any Decoder) throws {
    self.rawValue = try decoder.singleValueContainer().decode(String.self)
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(rawValue)
  }

  public var capability: GatewayCapability? {
    guard isSyntacticallyValid else { return nil }
    return OperationCatalog.enabledOperations.contains(self) ? .reader : .writer
  }

  private var isSyntacticallyValid: Bool {
    rawValue.range(
      of: #"^[a-z][a-z0-9]*(\.[a-z][a-z0-9]*){1,3}$"#,
      options: .regularExpression
    ) != nil
  }
}

extension OperationID {
  public static let advertisersList = OperationID(rawValue: "advertisers.list")
  public static let advertisersGet = OperationID(rawValue: "advertisers.get")
  public static let campaignsList = OperationID(rawValue: "campaigns.list")
  public static let adGroupsList = OperationID(rawValue: "adgroups.list")
  public static let adsList = OperationID(rawValue: "ads.list")
  public static let reportsIntegrated = OperationID(rawValue: "reports.integrated")
}

public struct CatalogEntry: Codable, Sendable {
  public let operation: OperationID
  public let capability: GatewayCapability
  public let method: HTTPMethod
  public let path: String
  public let enabled: Bool

  public init(
    operation: OperationID,
    capability: GatewayCapability,
    method: HTTPMethod,
    path: String,
    enabled: Bool
  ) {
    self.operation = operation
    self.capability = capability
    self.method = method
    self.path = path
    self.enabled = enabled
  }
}

public protocol OperationGating: Sendable {
  func requireEnabled(_ operation: OperationID) throws
}

public struct StaticOperationGate: OperationGating, Sendable {
  private let enabledOperations: Set<OperationID>

  public init(enabledOperations: Set<OperationID>) {
    self.enabledOperations = enabledOperations
  }

  public func requireEnabled(_ operation: OperationID) throws {
    guard enabledOperations.contains(operation) else {
      throw GatewayError(
        .unauthorizedOperation,
        message: "Operation is disabled pending verified official endpoint evidence"
      )
    }
  }
}

public enum OperationCatalog {
  public static let apiVersion = "v1.3"
  public static let origin = URL(string: "https://business-api.tiktok.com")!
  public static let entries: [CatalogEntry] = [
    entry(.advertisersList, "/open_api/v1.3/oauth2/advertiser/get/"),
    entry(.advertisersGet, "/open_api/v1.3/advertiser/info/"),
    entry(.campaignsList, "/open_api/v1.3/campaign/get/"),
    entry(.adGroupsList, "/open_api/v1.3/adgroup/get/"),
    entry(.adsList, "/open_api/v1.3/ad/get/"),
    entry(.reportsIntegrated, "/open_api/v1.3/report/integrated/get/"),
  ]
  public static let enabledOperations = Set(entries.map(\.operation))
  public static let operationGate = StaticOperationGate(enabledOperations: enabledOperations)

  public static func entry(for operation: OperationID) -> CatalogEntry? {
    entries.first { $0.operation == operation }
  }

  private static func entry(_ operation: OperationID, _ path: String) -> CatalogEntry {
    CatalogEntry(
      operation: operation,
      capability: .reader,
      method: .get,
      path: path,
      enabled: true
    )
  }
}
