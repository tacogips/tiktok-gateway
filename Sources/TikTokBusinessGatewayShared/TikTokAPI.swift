import Foundation

public struct TikTokEnvelope<Payload: Decodable & Sendable>: Decodable, Sendable {
  public let code: Int
  public let message: String
  public let requestID: String?
  public let data: Payload?

  enum CodingKeys: String, CodingKey {
    case code, message, data
    case requestID = "request_id"
  }
}

public struct TikTokEmptyPayload: Codable, Sendable {
  public init() {}
}

package enum TikTokRetryMode: Sendable {
  case safeRead
  case preDispatchOnly
}

private struct TikTokEnvelopeMetadata: Decodable, Sendable {
  let code: Int
  let message: String
  let requestID: String?

  enum CodingKeys: String, CodingKey {
    case code, message
    case requestID = "request_id"
  }
}

package struct TikTokAPIExecutor: Sendable {
  private let transport: any HTTPTransport
  private let sleeper: any RetrySleeping
  private let maximumAttempts: Int

  package init(
    transport: any HTTPTransport,
    sleeper: any RetrySleeping = TaskRetrySleeper(),
    maximumAttempts: Int = 3
  ) {
    self.transport = transport
    self.sleeper = sleeper
    self.maximumAttempts = max(1, min(maximumAttempts, 3))
  }

  package func execute<Payload: Decodable & Sendable>(
    operation: OperationID,
    queryItems: [URLQueryItem] = [],
    credentials: GatewayCredentials
  ) async throws -> TikTokEnvelope<Payload> {
    let request = try makeReaderRequest(
      operation: operation,
      queryItems: queryItems,
      credentials: credentials
    )
    return try await execute(request: request, retryMode: .safeRead)
  }

  package func execute<Payload: Decodable & Sendable>(
    request: HTTPRequest,
    retryMode: TikTokRetryMode
  ) async throws -> TikTokEnvelope<Payload> {
    var attempt = 1
    while true {
      do {
        let response = try await transport.send(request)
        if retryMode == .safeRead, Self.isRetryableHTTPStatus(response.statusCode),
          attempt < maximumAttempts
        {
          try await backoff(attempt: attempt)
          attempt += 1
          continue
        }
        let metadata = try decodeMetadata(response)
        guard (200...299).contains(response.statusCode) else {
          throw GatewayError(
            .providerFailure,
            message: "TikTok returned HTTP status \(response.statusCode)",
            providerCode: metadata.code,
            requestID: metadata.requestID
          )
        }
        guard metadata.code == 0 else {
          throw GatewayError(
            .providerFailure,
            message: "TikTok rejected the operation",
            providerCode: metadata.code,
            requestID: metadata.requestID
          )
        }
        return try decodeSuccess(response)
      } catch let error as TransportError {
        let retryable =
          error.transience == .transient
          && (retryMode == .safeRead || error.phase == .preDispatch)
        if retryable, attempt < maximumAttempts {
          try await backoff(attempt: attempt)
          attempt += 1
          continue
        }
        throw GatewayError(.transportFailure, message: "TikTok transport failed")
      }
    }
  }

  private func makeReaderRequest(
    operation: OperationID,
    queryItems: [URLQueryItem],
    credentials: GatewayCredentials
  ) throws -> HTTPRequest {
    guard let entry = OperationCatalog.entry(for: operation), entry.method == .get else {
      throw GatewayError(.unauthorizedOperation, message: "Reader operation is not cataloged")
    }
    var components = URLComponents(url: OperationCatalog.origin, resolvingAgainstBaseURL: false)
    components?.path = entry.path
    var items = queryItems
    if operation == .advertisersList {
      guard let appID = credentials.appID, let secret = credentials.appSecret else {
        throw GatewayError(.missingCredential, message: "Application credentials are required")
      }
      items.append(URLQueryItem(name: "app_id", value: appID))
      items.append(URLQueryItem(name: "secret", value: secret))
    }
    components?.queryItems = items.isEmpty ? nil : items
    guard let url = components?.url else {
      throw GatewayError(.invalidArgument, message: "Unable to construct the fixed TikTok request")
    }
    let headers = ["Access-Token": credentials.accessToken, "Accept": "application/json"]
    return HTTPRequest(method: .get, url: url, headers: headers)
  }

  private func decodeMetadata(_ response: HTTPResponse) throws -> TikTokEnvelopeMetadata {
    do {
      return try JSONDecoder().decode(TikTokEnvelopeMetadata.self, from: response.body)
    } catch {
      if !(200...299).contains(response.statusCode) {
        throw GatewayError(
          .providerFailure, message: "TikTok returned HTTP status \(response.statusCode)")
      }
      throw GatewayError(.invalidResponse, message: "TikTok returned an invalid response envelope")
    }
  }

  private func decodeSuccess<Payload: Decodable & Sendable>(
    _ response: HTTPResponse
  ) throws -> TikTokEnvelope<Payload> {
    do {
      return try JSONDecoder().decode(TikTokEnvelope<Payload>.self, from: response.body)
    } catch {
      throw GatewayError(
        .invalidResponse, message: "TikTok returned invalid success-envelope data")
    }
  }

  private func backoff(attempt: Int) async throws {
    let milliseconds = UInt64(200 * (1 << (attempt - 1)))
    try await sleeper.sleep(nanoseconds: milliseconds * 1_000_000)
  }

  private static func isRetryableHTTPStatus(_ status: Int) -> Bool {
    status == 408 || status == 429 || (500...599).contains(status)
  }
}
