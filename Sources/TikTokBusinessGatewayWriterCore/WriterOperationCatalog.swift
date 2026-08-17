import Foundation
import TikTokBusinessGatewayShared

extension OperationID {
  public static let campaignsStatusUpdate = OperationID(rawValue: "campaigns.status.update")
  public static let adGroupsStatusUpdate = OperationID(rawValue: "adgroups.status.update")
  public static let adsStatusUpdate = OperationID(rawValue: "ads.status.update")
}

enum WriterOperationCatalog {
  static let entries: [CatalogEntry] = [
    entry(.campaignsStatusUpdate, "/open_api/v1.3/campaign/status/update/"),
    entry(.adGroupsStatusUpdate, "/open_api/v1.3/adgroup/status/update/"),
    entry(.adsStatusUpdate, "/open_api/v1.3/ad/status/update/"),
  ]
  static let enabledOperations = Set(entries.map(\.operation))
  static let operationGate = StaticOperationGate(enabledOperations: enabledOperations)

  static func entry(for operation: OperationID) -> CatalogEntry? {
    entries.first { $0.operation == operation }
  }

  private static func entry(_ operation: OperationID, _ path: String) -> CatalogEntry {
    CatalogEntry(
      operation: operation,
      capability: .writer,
      method: .post,
      path: path,
      enabled: true
    )
  }
}

enum WriterRequestFactory {
  static func make(
    operation: OperationID,
    body: Data,
    credentials: GatewayCredentials
  ) throws -> HTTPRequest {
    guard let entry = WriterOperationCatalog.entry(for: operation), entry.method == .post else {
      throw GatewayError(.unauthorizedOperation, message: "Writer operation is not cataloged")
    }
    var components = URLComponents(url: OperationCatalog.origin, resolvingAgainstBaseURL: false)
    components?.path = entry.path
    guard let url = components?.url else {
      throw GatewayError(.invalidArgument, message: "Unable to construct the fixed TikTok request")
    }
    return HTTPRequest(
      method: .post,
      url: url,
      headers: [
        "Access-Token": credentials.accessToken,
        "Accept": "application/json",
        "Content-Type": "application/json",
      ],
      body: body
    )
  }
}
