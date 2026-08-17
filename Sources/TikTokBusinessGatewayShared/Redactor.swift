import Foundation

public enum Redactor {
  private static let sensitiveKeyPattern = try? NSRegularExpression(
    pattern:
      #"(?i)(access[-_ ]?token|authorization|app[-_ ]?secret|secret|cookie|credential|auth[-_ ]?code)\s*[:=]\s*[^\s,;&]+"#
  )

  public static func redact(_ text: String, secrets: [String] = []) -> String {
    var result = text
    for secret in secrets where !secret.isEmpty {
      result = result.replacingOccurrences(of: secret, with: "<redacted>")
      if let encoded = secret.addingPercentEncoding(withAllowedCharacters: .alphanumerics),
        encoded != secret
      {
        result = result.replacingOccurrences(of: encoded, with: "<redacted>")
      }
    }
    guard let expression = sensitiveKeyPattern else { return result }
    let range = NSRange(result.startIndex..<result.endIndex, in: result)
    return expression.stringByReplacingMatches(
      in: result,
      range: range,
      withTemplate: "$1=<redacted>"
    )
  }
}
