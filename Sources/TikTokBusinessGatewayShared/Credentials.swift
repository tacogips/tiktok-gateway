import Foundation

public struct GatewayCredentials: Sendable {
  public let accessToken: String
  public let appID: String?
  public let appSecret: String?

  public init(accessToken: String, appID: String? = nil, appSecret: String? = nil) {
    self.accessToken = accessToken
    self.appID = appID
    self.appSecret = appSecret
  }
}

public protocol CredentialResolving: Sendable {
  func resolve(for profile: GatewayProfile, operation: OperationID) throws -> GatewayCredentials
}

public struct EnvironmentCredentialResolver: CredentialResolving, Sendable {
  private let environment: @Sendable (String) -> String?

  public init(
    environment: @escaping @Sendable (String) -> String? = {
      ProcessInfo.processInfo.environment[$0]
    }
  ) {
    self.environment = environment
  }

  public func resolve(for profile: GatewayProfile, operation: OperationID) throws
    -> GatewayCredentials
  {
    guard let token = environment(profile.accessTokenEnvironmentVariable), !token.isEmpty else {
      throw GatewayError(
        .missingCredential,
        message: "Required access-token environment variable is missing or empty")
    }
    guard operation == .advertisersList else {
      return GatewayCredentials(accessToken: token)
    }
    guard let appID = profile.appID,
      let reference = profile.appSecretEnvironmentVariable,
      let secret = environment(reference), !secret.isEmpty
    else {
      throw GatewayError(
        .missingCredential, message: "Required app-secret environment variable is missing or empty")
    }
    return GatewayCredentials(accessToken: token, appID: appID, appSecret: secret)
  }
}
