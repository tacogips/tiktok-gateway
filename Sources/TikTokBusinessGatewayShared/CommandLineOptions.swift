import Foundation

public struct CommandLineOptions: Sendable {
  public let command: [String]
  private let values: [String: String]

  public init(arguments: [String]) throws {
    var command: [String] = []
    var values: [String: String] = [:]
    var index = 0
    while index < arguments.count {
      let argument = arguments[index]
      if argument.hasPrefix("--") {
        guard values[argument] == nil, index + 1 < arguments.count,
          !arguments[index + 1].hasPrefix("--")
        else {
          throw GatewayError(
            .invalidArgument, message: "Flag \(argument) is duplicate or missing a value")
        }
        values[argument] = arguments[index + 1]
        index += 2
      } else {
        command.append(argument)
        index += 1
      }
    }
    self.command = command
    self.values = values
  }

  public func value(_ flag: String, required: Bool = false) throws -> String? {
    if let value = values[flag], !value.isEmpty { return value }
    if required {
      throw GatewayError(.invalidArgument, message: "Required flag \(flag) is missing")
    }
    return nil
  }

  public func validate(allowed: Set<String>) throws {
    if let unknown = values.keys.first(where: { !allowed.contains($0) }) {
      throw GatewayError(.invalidArgument, message: "Unknown or inapplicable flag \(unknown)")
    }
  }

  public func integer(_ flag: String, default defaultValue: Int) throws -> Int {
    guard let raw = try value(flag) else { return defaultValue }
    guard let value = Int(raw) else {
      throw GatewayError(.invalidArgument, message: "Flag \(flag) must be an integer")
    }
    return value
  }
}
