import Foundation

public struct GatewayError: Error, Equatable, Sendable, CustomStringConvertible {
  public enum Code: String, Codable, Sendable {
    case invalidArgument
    case invalidConfiguration
    case unauthorizedOperation
    case missingCredential
    case transportFailure
    case responseTooLarge
    case invalidResponse
    case providerFailure
  }

  public let code: Code
  public let message: String
  public let providerCode: Int?
  public let requestID: String?

  public init(
    _ code: Code,
    message: String,
    providerCode: Int? = nil,
    requestID: String? = nil
  ) {
    self.code = code
    self.message = message
    self.providerCode = providerCode
    self.requestID = requestID
  }

  public var description: String { message }

  public var exitCode: Int32 {
    switch code {
    case .invalidArgument, .invalidConfiguration, .unauthorizedOperation: 2
    case .missingCredential: 3
    case .transportFailure, .responseTooLarge, .invalidResponse, .providerFailure: 4
    }
  }
}

public struct ErrorOutput: Codable, Sendable {
  public let error: ErrorOutputDetails

  public init(_ error: GatewayError) {
    self.error = ErrorOutputDetails(
      code: error.code.rawValue,
      message: Redactor.redact(error.message),
      providerCode: error.providerCode,
      requestID: error.requestID
    )
  }

}

public struct ErrorOutputDetails: Codable, Sendable {
  public let code: String
  public let message: String
  public let providerCode: Int?
  public let requestID: String?

  enum CodingKeys: String, CodingKey {
    case code, message
    case providerCode = "provider_code"
    case requestID = "request_id"
  }
}
