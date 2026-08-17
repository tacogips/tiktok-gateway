import Foundation
import TikTokBusinessGatewayShared

public struct WriterCLI: Sendable {
  private let transport: any HTTPTransport
  private let credentials: any CredentialResolving
  private let environment: [String: String]

  public init(
    transport: any HTTPTransport = URLSessionHTTPTransport(),
    credentials: any CredentialResolving = EnvironmentCredentialResolver(),
    environment: [String: String] = ProcessInfo.processInfo.environment
  ) {
    self.transport = transport
    self.credentials = credentials
    self.environment = environment
  }

  public func run(arguments: [String]) async -> CLIResult {
    if arguments == ["--help"] || arguments.isEmpty { return CLIResult(stdout: Self.usage + "\n") }
    if arguments == ["--version"] {
      return CLIResult(stdout: TikTokBusinessGatewayVersion.current + "\n")
    }
    do {
      let options = try CommandLineOptions(arguments: arguments)
      switch options.command {
      case ["catalog", "show"]:
        try options.validate(allowed: [])
        return output(WriterOperationCatalog.entries)
      case ["config", "validate"]:
        try options.validate(allowed: ["--config"])
        let configuration = try ConfigurationLoader.load(path: configPath(options))
        return output(["status": "valid", "profiles": String(configuration.profiles.count)])
      case ["campaigns", "status", "update"]:
        return try await update(options, kind: .campaign)
      case ["adgroups", "status", "update"]:
        return try await update(options, kind: .adGroup)
      case ["ads", "status", "update"]:
        return try await update(options, kind: .ad)
      default:
        throw GatewayError(.invalidArgument, message: "Unknown writer command")
      }
    } catch let error as GatewayError {
      return .failure(error)
    } catch {
      return .failure(GatewayError(.invalidResponse, message: "Writer command failed"))
    }
  }

  private enum ResourceKind { case campaign, adGroup, ad }

  private func update(_ options: CommandLineOptions, kind: ResourceKind) async throws -> CLIResult {
    let allowed =
      [
        "--profile", "--config", "--advertiser-id", "--resource-id", "--resource-family",
        "--status",
        "--confirm-status",
      ] as Set<String>
    try options.validate(allowed: allowed)
    let configuration = try ConfigurationLoader.load(path: configPath(options))
    let profileID = try required(options, "--profile")
    let profile = try configuration.validatedProfile(id: profileID, capability: .writer)
    let advertiserID = try required(options, "--advertiser-id")
    let resourceID = try required(options, "--resource-id")
    let rawStatus = try required(options, "--status")
    guard let status = DeliveryStatus(rawValue: rawStatus) else {
      throw GatewayError(.invalidArgument, message: "Status must be ENABLE or DISABLE")
    }
    guard try required(options, "--confirm-status") == rawStatus else {
      throw GatewayError(
        .invalidArgument, message: "Confirmation must exactly match the requested status")
    }
    let rawFamily = try required(options, "--resource-family")
    let client = try TikTokWriterClient(
      profile: profile, transport: transport, credentials: credentials)
    switch kind {
    case .campaign:
      guard let family = CampaignFamily(rawValue: rawFamily) else {
        throw GatewayError(.invalidArgument, message: "Unsupported campaign resource family")
      }
      return output(
        try await client.updateCampaignStatus(
          advertiserID: advertiserID,
          campaignID: resourceID,
          family: family,
          status: status
        ))
    case .adGroup:
      guard let family = AdGroupFamily(rawValue: rawFamily) else {
        throw GatewayError(.invalidArgument, message: "Unsupported ad-group resource family")
      }
      return output(
        try await client.updateAdGroupStatus(
          advertiserID: advertiserID,
          adGroupID: resourceID,
          family: family,
          status: status
        ))
    case .ad:
      guard let family = AdFamily(rawValue: rawFamily) else {
        throw GatewayError(.invalidArgument, message: "Unsupported ad resource family")
      }
      return output(
        try await client.updateAdStatus(
          advertiserID: advertiserID,
          adID: resourceID,
          family: family,
          status: status
        ))
    }
  }

  private func configPath(_ options: CommandLineOptions) throws -> String {
    try options.value("--config") ?? ConfigurationLoader.defaultPath(environment: environment)
  }

  private func required(_ options: CommandLineOptions, _ flag: String) throws -> String {
    guard let value = try options.value(flag, required: true) else {
      throw GatewayError(.invalidArgument, message: "Required flag \(flag) is missing")
    }
    return value
  }

  private func output<Value: Encodable>(_ value: Value) -> CLIResult {
    CLIResult(stdout: JSONOutput.string(value))
  }

  public static let usage = """
    Usage: tiktok-business-gateway-writer <command> [options]

      catalog show
      config validate [--config PATH]
      campaigns status update --profile PROFILE --advertiser-id ID --resource-id ID --resource-family MANUAL --status ENABLE|DISABLE --confirm-status ENABLE|DISABLE
      adgroups status update --profile PROFILE --advertiser-id ID --resource-id ID --resource-family MANUAL --status ENABLE|DISABLE --confirm-status ENABLE|DISABLE
      ads status update --profile PROFILE --advertiser-id ID --resource-id ID --resource-family MANUAL --status ENABLE|DISABLE --confirm-status ENABLE|DISABLE

    Writer commands update exactly one resource. DELETE and arbitrary update fields are not supported.
    """
}
