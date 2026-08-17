import Foundation

public enum JSONValue: Codable, Equatable, Sendable {
  case string(String)
  case number(String)
  case bool(Bool)
  case object([String: JSONValue])
  case array([JSONValue])
  case null

  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    if container.decodeNil() {
      self = .null
    } else if let value = try? container.decode(String.self) {
      self = .string(value)
    } else if let value = try? container.decode(Bool.self) {
      self = .bool(value)
    } else if let value = try? container.decode(Decimal.self) {
      self = .number(NSDecimalNumber(decimal: value).stringValue)
    } else if let value = try? container.decode([String: JSONValue].self) {
      self = .object(value)
    } else if let value = try? container.decode([JSONValue].self) {
      self = .array(value)
    } else {
      throw GatewayError(.invalidResponse, message: "Unsupported JSON value")
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case .string(let value): try container.encode(value)
    case .number(let value):
      guard let number = Decimal(string: value, locale: Locale(identifier: "en_US_POSIX")) else {
        throw GatewayError(.invalidResponse, message: "Unable to encode JSON number")
      }
      try container.encode(number)
    case .bool(let value): try container.encode(value)
    case .object(let value): try container.encode(value)
    case .array(let value): try container.encode(value)
    case .null: try container.encodeNil()
    }
  }
}

public enum JSONOutput {
  public static func encode<Value: Encodable>(_ value: Value) throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    var data = try encoder.encode(value)
    data.append(0x0A)
    return data
  }

  public static func string<Value: Encodable>(_ value: Value) -> String {
    ((try? encode(value)).flatMap { String(bytes: $0, encoding: .utf8) })
      ?? "{\"error\":{\"code\":\"invalidResponse\",\"message\":\"Unable to encode output\"}}\n"
  }
}

public struct CLIResult: Sendable {
  public let stdout: String
  public let stderr: String
  public let exitCode: Int32

  public init(stdout: String = "", stderr: String = "", exitCode: Int32 = 0) {
    self.stdout = stdout
    self.stderr = stderr
    self.exitCode = exitCode
  }

  public static func failure(_ error: GatewayError) -> CLIResult {
    CLIResult(stderr: JSONOutput.string(ErrorOutput(error)), exitCode: error.exitCode)
  }
}
