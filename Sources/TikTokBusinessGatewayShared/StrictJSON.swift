import Foundation

public enum StrictJSON {
  public static func verifyNoDuplicateKeys(_ data: Data) throws {
    var parser = Parser(bytes: Array(data))
    try parser.value(depth: 1)
    parser.skipWhitespace()
    guard parser.index == parser.bytes.count else { throw invalid() }
  }

  public static func requireObjectKeys(_ value: Any, allowed: Set<String>) throws {
    guard let object = value as? [String: Any], Set(object.keys).isSubset(of: allowed) else {
      throw invalid()
    }
  }

  private static func invalid() -> GatewayError {
    GatewayError(
      .invalidConfiguration, message: "JSON contains duplicate, unknown, or invalid structure")
  }

  private struct Parser {
    let bytes: [UInt8]
    var index = 0

    mutating func skipWhitespace() {
      while index < bytes.count, [9, 10, 13, 32].contains(bytes[index]) { index += 1 }
    }

    mutating func value(depth: Int) throws {
      guard depth <= 64 else { throw StrictJSON.invalid() }
      skipWhitespace()
      guard index < bytes.count else { throw StrictJSON.invalid() }
      switch bytes[index] {
      case 123: try object(depth: depth)
      case 91: try array(depth: depth)
      case 34: _ = try string()
      case 116: try literal("true")
      case 102: try literal("false")
      case 110: try literal("null")
      case 45, 48...57: try number()
      default: throw StrictJSON.invalid()
      }
    }

    mutating func object(depth: Int) throws {
      try token(123)
      skipWhitespace()
      var keys = Set<String>()
      if consume(125) { return }
      while true {
        skipWhitespace()
        let key = try string()
        guard keys.insert(key).inserted else { throw StrictJSON.invalid() }
        skipWhitespace()
        try token(58)
        try value(depth: depth + 1)
        skipWhitespace()
        if consume(125) { return }
        try token(44)
      }
    }

    mutating func array(depth: Int) throws {
      try token(91)
      skipWhitespace()
      if consume(93) { return }
      while true {
        try value(depth: depth + 1)
        skipWhitespace()
        if consume(93) { return }
        try token(44)
      }
    }

    mutating func string() throws -> String {
      let start = index
      try token(34)
      while index < bytes.count {
        let byte = bytes[index]
        if byte == 34 {
          index += 1
          let data = Data(bytes[start..<index])
          guard let value = try? JSONDecoder().decode(String.self, from: data) else {
            throw StrictJSON.invalid()
          }
          return value
        }
        guard byte >= 32 else { throw StrictJSON.invalid() }
        if byte == 92 {
          index += 1
          guard index < bytes.count else { throw StrictJSON.invalid() }
          if bytes[index] == 117 {
            guard index + 4 < bytes.count,
              bytes[(index + 1)...(index + 4)].allSatisfy(Self.isHex)
            else {
              throw StrictJSON.invalid()
            }
            index += 5
          } else {
            guard [34, 47, 92, 98, 102, 110, 114, 116].contains(bytes[index]) else {
              throw StrictJSON.invalid()
            }
            index += 1
          }
        } else {
          index += 1
        }
      }
      throw StrictJSON.invalid()
    }

    mutating func number() throws {
      if consume(45), index >= bytes.count { throw StrictJSON.invalid() }
      if consume(48) {
        if index < bytes.count, (48...57).contains(bytes[index]) { throw StrictJSON.invalid() }
      } else {
        guard index < bytes.count, (49...57).contains(bytes[index]) else {
          throw StrictJSON.invalid()
        }
        while index < bytes.count, (48...57).contains(bytes[index]) { index += 1 }
      }
      if consume(46) {
        guard index < bytes.count, (48...57).contains(bytes[index]) else {
          throw StrictJSON.invalid()
        }
        while index < bytes.count, (48...57).contains(bytes[index]) { index += 1 }
      }
      if index < bytes.count && (bytes[index] == 69 || bytes[index] == 101) {
        index += 1
        if index < bytes.count && (bytes[index] == 43 || bytes[index] == 45) { index += 1 }
        guard index < bytes.count, (48...57).contains(bytes[index]) else {
          throw StrictJSON.invalid()
        }
        while index < bytes.count, (48...57).contains(bytes[index]) { index += 1 }
      }
    }

    mutating func literal(_ value: String) throws {
      let expected = Array(value.utf8)
      guard index + expected.count <= bytes.count,
        Array(bytes[index..<(index + expected.count)]) == expected
      else {
        throw StrictJSON.invalid()
      }
      index += expected.count
    }

    mutating func token(_ expected: UInt8) throws {
      skipWhitespace()
      guard consume(expected) else { throw StrictJSON.invalid() }
    }

    mutating func consume(_ expected: UInt8) -> Bool {
      guard index < bytes.count, bytes[index] == expected else { return false }
      index += 1
      return true
    }

    private static func isHex(_ byte: UInt8) -> Bool {
      (48...57).contains(byte) || (65...70).contains(byte) || (97...102).contains(byte)
    }
  }
}
