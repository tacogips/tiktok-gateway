import Foundation

public struct GatewayConfiguration: Codable, Sendable {
  public let schemaVersion: Int
  public let profiles: [GatewayProfile]

  public init(schemaVersion: Int = 1, profiles: [GatewayProfile]) {
    self.schemaVersion = schemaVersion
    self.profiles = profiles
  }

  public func validatedProfile(id: String, capability: GatewayCapability) throws -> GatewayProfile {
    try validate()
    guard let profile = profiles.first(where: { $0.id == id }) else {
      throw GatewayError(.invalidConfiguration, message: "Profile was not found")
    }
    guard profile.capability == capability else {
      throw GatewayError(.unauthorizedOperation, message: "Profile has the wrong capability")
    }
    return profile
  }

  public func validate() throws {
    guard schemaVersion == 1, !profiles.isEmpty else {
      throw GatewayError(.invalidConfiguration, message: "Unsupported or empty configuration")
    }
    guard Set(profiles.map(\.id)).count == profiles.count else {
      throw GatewayError(.invalidConfiguration, message: "Profile identifiers must be unique")
    }
    for profile in profiles { try profile.validate() }
  }
}

public struct GatewayProfile: Codable, Sendable {
  public let id: String
  public let capability: GatewayCapability
  public let apiVersion: String
  public let accessTokenEnvironmentVariable: String
  public let appID: String?
  public let appSecretEnvironmentVariable: String?
  public let advertiserIDs: [String]
  public let operations: [OperationID]

  enum CodingKeys: String, CodingKey {
    case id, capability, apiVersion
    case accessTokenEnvironmentVariable
    case appID = "appId"
    case appSecretEnvironmentVariable
    case advertiserIDs = "advertiserIds"
    case operations
  }

  public init(
    id: String,
    capability: GatewayCapability,
    apiVersion: String = OperationCatalog.apiVersion,
    accessTokenEnvironmentVariable: String,
    appID: String? = nil,
    appSecretEnvironmentVariable: String? = nil,
    advertiserIDs: [String],
    operations: [OperationID]
  ) {
    self.id = id
    self.capability = capability
    self.apiVersion = apiVersion
    self.accessTokenEnvironmentVariable = accessTokenEnvironmentVariable
    self.appID = appID
    self.appSecretEnvironmentVariable = appSecretEnvironmentVariable
    self.advertiserIDs = advertiserIDs
    self.operations = operations
  }

  public func validate() throws {
    guard id.range(of: #"^[a-z][a-z0-9-]{0,63}$"#, options: .regularExpression) != nil,
      apiVersion == OperationCatalog.apiVersion,
      !advertiserIDs.isEmpty,
      !operations.isEmpty
    else {
      throw GatewayError(.invalidConfiguration, message: "Profile contains invalid required fields")
    }
    try validateEnvironmentName(accessTokenEnvironmentVariable)
    guard advertiserIDs.allSatisfy(IdentifierValidator.isCanonicalDecimal),
      Set(advertiserIDs).count == advertiserIDs.count,
      Set(operations).count == operations.count,
      operations.allSatisfy({ $0.capability == capability })
    else {
      throw GatewayError(.invalidConfiguration, message: "Profile allowlists are invalid")
    }
    if operations.contains(.advertisersList) {
      guard let appID, !appID.isEmpty, let appSecretEnvironmentVariable else {
        throw GatewayError(
          .invalidConfiguration, message: "Authorized advertiser listing requires app credentials")
      }
      try validateEnvironmentName(appSecretEnvironmentVariable)
    } else if appID != nil || appSecretEnvironmentVariable != nil {
      throw GatewayError(
        .invalidConfiguration,
        message: "App credentials are only valid for authorized advertiser listing")
    }
  }

  public func authorize(_ operation: OperationID, advertiserID: String? = nil) throws {
    guard operation.capability == capability, operations.contains(operation) else {
      throw GatewayError(
        .unauthorizedOperation, message: "Operation is not allowed by this profile")
    }
    if let advertiserID, !advertiserIDs.contains(advertiserID) {
      throw GatewayError(
        .unauthorizedOperation, message: "Advertiser is not allowed by this profile")
    }
  }

  private func validateEnvironmentName(_ value: String) throws {
    let reserved = ["HOME", "PATH", "USER", "LOGNAME", "SHELL"]
    guard value.range(of: #"^[A-Z][A-Z0-9_]{0,127}$"#, options: .regularExpression) != nil,
      !reserved.contains(value)
    else {
      throw GatewayError(
        .invalidConfiguration, message: "Credential environment reference is invalid")
    }
  }
}

public enum IdentifierValidator {
  public static func isCanonicalDecimal(_ value: String) -> Bool {
    let bytes = Array(value.utf8)
    guard (1...64).contains(bytes.count), bytes.allSatisfy({ (48...57).contains($0) }), value != "0"
    else {
      return false
    }
    return bytes.count == 1 || bytes[0] != 48
  }

  public static func requireCanonicalDecimal(_ value: String, name: String) throws {
    guard isCanonicalDecimal(value) else {
      throw GatewayError(
        .invalidArgument, message: "\(name) must be a canonical nonzero decimal identifier")
    }
  }
}

public enum ConfigurationLoader {
  public static let maximumBytes = 1_048_576

  public static func load(path: String) throws -> GatewayConfiguration {
    do {
      let data = try SecureFileReader.read(
        path: path,
        maximumBytes: maximumBytes,
        purpose: .configuration
      )
      try StrictJSON.verifyNoDuplicateKeys(data)
      let raw = try JSONSerialization.jsonObject(with: data)
      try StrictJSON.requireObjectKeys(raw, allowed: ["schemaVersion", "profiles"])
      if let root = raw as? [String: Any], let profiles = root["profiles"] as? [Any] {
        let allowed =
          [
            "id", "capability", "apiVersion", "accessTokenEnvironmentVariable", "appId",
            "appSecretEnvironmentVariable", "advertiserIds", "operations",
          ] as Set<String>
        for profile in profiles { try StrictJSON.requireObjectKeys(profile, allowed: allowed) }
      }
      let configuration = try JSONDecoder().decode(GatewayConfiguration.self, from: data)
      try configuration.validate()
      return configuration
    } catch let error as GatewayError {
      throw error
    } catch {
      throw GatewayError(
        .invalidConfiguration, message: "Configuration could not be read or decoded")
    }
  }

  public static func defaultPath(
    environment: [String: String] = ProcessInfo.processInfo.environment
  ) -> String {
    if let configured = environment["TIKTOK_BUSINESS_GATEWAY_CONFIG"], !configured.isEmpty {
      return configured
    }
    return FileManager.default.homeDirectoryForCurrentUser
      .appendingPathComponent(".config/tiktok-business-gateway/profiles.json").path
  }
}
