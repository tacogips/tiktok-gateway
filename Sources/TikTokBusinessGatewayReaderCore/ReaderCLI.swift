import Foundation
import TikTokBusinessGatewayShared

public struct ReaderCLI: Sendable {
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
        return output(OperationCatalog.entries.filter { $0.capability == .reader })
      case ["config", "validate"]:
        try options.validate(allowed: ["--config"])
        let configuration = try ConfigurationLoader.load(path: try configPath(options))
        return output(["status": "valid", "profiles": String(configuration.profiles.count)])
      case ["auth", "status"]:
        let profile = try loadProfile(options, allowed: ["--profile", "--config"])
        for operation in profile.operations {
          try OperationCatalog.operationGate.requireEnabled(operation)
          _ = try credentials.resolve(for: profile, operation: operation)
        }
        return output(["status": "locallyReady", "profile": profile.id])
      case ["advertisers", "list"]:
        let profile = try loadProfile(options, allowed: ["--profile", "--config"])
        let client = try makeClient(profile)
        return output(try await client.authorizedAdvertisers())
      case ["advertisers", "get"]:
        let allowed = ["--profile", "--config", "--advertiser-id"] as Set<String>
        let profile = try loadProfile(options, allowed: allowed)
        let advertiserID = try required(options, "--advertiser-id")
        return output(try await makeClient(profile).advertiserInfo(advertiserID: advertiserID))
      case ["campaigns", "list"]:
        return try await resourceList(options, kind: .campaign)
      case ["adgroups", "list"]:
        return try await resourceList(options, kind: .adGroup)
      case ["ads", "list"]:
        return try await resourceList(options, kind: .ad)
      case ["reports", "integrated"]:
        let allowed = ["--profile", "--config", "--request-file"] as Set<String>
        let profile = try loadProfile(options, allowed: allowed)
        let request = try loadReport(path: required(options, "--request-file"))
        return output(try await makeClient(profile).synchronousReport(request))
      default:
        throw GatewayError(.invalidArgument, message: "Unknown reader command")
      }
    } catch let error as GatewayError {
      return .failure(error)
    } catch {
      return .failure(GatewayError(.invalidResponse, message: "Reader command failed"))
    }
  }

  private enum ResourceKind { case campaign, adGroup, ad }

  private func resourceList(_ options: CommandLineOptions, kind: ResourceKind) async throws
    -> CLIResult
  {
    let allowed =
      ["--profile", "--config", "--advertiser-id", "--ids", "--page", "--page-size"] as Set<String>
    let profile = try loadProfile(options, allowed: allowed)
    let advertiserID = try required(options, "--advertiser-id")
    let ids =
      try options.value("--ids")?.split(separator: ",", omittingEmptySubsequences: false).map(
        String.init) ?? []
    guard !ids.contains("") else {
      throw GatewayError(
        .invalidArgument, message: "--ids must be a comma-separated identifier list")
    }
    let page = try PageRequest(
      page: options.integer("--page", default: 1),
      pageSize: options.integer("--page-size", default: 100)
    )
    let client = try makeClient(profile)
    switch kind {
    case .campaign:
      return output(
        try await client.campaigns(advertiserID: advertiserID, campaignIDs: ids, page: page))
    case .adGroup:
      return output(
        try await client.adGroups(advertiserID: advertiserID, adGroupIDs: ids, page: page))
    case .ad:
      return output(try await client.ads(advertiserID: advertiserID, adIDs: ids, page: page))
    }
  }

  private func loadProfile(_ options: CommandLineOptions, allowed: Set<String>) throws
    -> GatewayProfile
  {
    try options.validate(allowed: allowed)
    let profileID = try required(options, "--profile")
    return try ConfigurationLoader.load(path: configPath(options)).validatedProfile(
      id: profileID, capability: .reader)
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

  private func makeClient(_ profile: GatewayProfile) throws -> TikTokReaderClient {
    try TikTokReaderClient(profile: profile, transport: transport, credentials: credentials)
  }

  private func loadReport(path: String) throws -> SynchronousReportRequest {
    do {
      let data = try SecureFileReader.read(
        path: path,
        maximumBytes: 65_536,
        purpose: .reportRequest
      )
      try StrictJSON.verifyNoDuplicateKeys(data)
      let raw = try JSONSerialization.jsonObject(with: data)
      try StrictJSON.requireObjectKeys(
        raw,
        allowed: [
          "advertiser_id", "data_level", "dimensions", "metrics", "start_date", "end_date", "page",
          "page_size",
        ]
      )
      return try JSONDecoder().decode(SynchronousReportRequest.self, from: data)
    } catch is GatewayError {
      throw GatewayError(.invalidArgument, message: "Report request is invalid")
    } catch {
      throw GatewayError(.invalidArgument, message: "Report request could not be read or decoded")
    }
  }

  private func output<Value: Encodable>(_ value: Value) -> CLIResult {
    CLIResult(stdout: JSONOutput.string(value))
  }

  public static let usage = """
    Usage: tiktok-business-gateway-reader <command> [options]

      catalog show
      config validate [--config PATH]
      auth status --profile PROFILE [--config PATH]
      advertisers list --profile PROFILE [--config PATH]
      advertisers get --profile PROFILE --advertiser-id ID [--config PATH]
      campaigns list --profile PROFILE --advertiser-id ID [--ids ID,...] [--page N] [--page-size N]
      adgroups list --profile PROFILE --advertiser-id ID [--ids ID,...] [--page N] [--page-size N]
      ads list --profile PROFILE --advertiser-id ID [--ids ID,...] [--page N] [--page-size N]
      reports integrated --profile PROFILE --request-file PATH [--config PATH]
    """
}
