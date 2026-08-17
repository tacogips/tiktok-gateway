import Foundation

#if canImport(Darwin)
  import Darwin
#elseif canImport(Glibc)
  import Glibc
#endif

public enum SecureFilePurpose: Sendable {
  case configuration
  case reportRequest

  fileprivate var errorCode: GatewayError.Code {
    switch self {
    case .configuration: .invalidConfiguration
    case .reportRequest: .invalidArgument
    }
  }

  fileprivate var label: String {
    switch self {
    case .configuration: "Configuration"
    case .reportRequest: "Report request"
    }
  }
}

public enum SecureFileReader {
  public static func read(
    path: String,
    maximumBytes: Int,
    purpose: SecureFilePurpose
  ) throws -> Data {
    try read(path: path, maximumBytes: maximumBytes, purpose: purpose, afterOpen: nil)
  }

  static func read(
    path: String,
    maximumBytes: Int,
    purpose: SecureFilePurpose,
    afterOpen: (() throws -> Void)? = nil
  ) throws -> Data {
    let flags = O_RDONLY | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC
    let descriptor = path.withCString { open($0, flags) }
    guard descriptor >= 0 else {
      throw GatewayError(purpose.errorCode, message: "\(purpose.label) could not be opened safely")
    }
    defer { close(descriptor) }

    var before = stat()
    guard fstat(descriptor, &before) == 0,
      before.st_mode & S_IFMT == S_IFREG,
      before.st_uid == geteuid(),
      before.st_mode & 0o022 == 0,
      before.st_size >= 0,
      before.st_size <= off_t(maximumBytes)
    else {
      throw GatewayError(
        purpose.errorCode,
        message: "\(purpose.label) must be a private, owned, bounded regular file"
      )
    }

    try afterOpen?()
    var data = Data()
    data.reserveCapacity(Int(before.st_size))
    var buffer = [UInt8](repeating: 0, count: 16_384)
    while true {
      let count = buffer.withUnsafeMutableBytes { bytes in
        systemRead(descriptor, bytes.baseAddress, bytes.count)
      }
      if count < 0, errno == EINTR { continue }
      guard count >= 0 else {
        throw GatewayError(
          purpose.errorCode, message: "\(purpose.label) could not be read safely")
      }
      if count == 0 { break }
      guard data.count + count <= maximumBytes else {
        throw GatewayError(purpose.errorCode, message: "\(purpose.label) exceeds the size limit")
      }
      data.append(buffer, count: count)
    }

    var after = stat()
    guard fstat(descriptor, &after) == 0, unchanged(before, after) else {
      throw GatewayError(purpose.errorCode, message: "\(purpose.label) changed while being read")
    }
    return data
  }

  private static func unchanged(_ before: stat, _ after: stat) -> Bool {
    guard before.st_dev == after.st_dev,
      before.st_ino == after.st_ino,
      before.st_mode == after.st_mode,
      before.st_uid == after.st_uid,
      before.st_size == after.st_size
    else { return false }
    #if canImport(Darwin)
      return before.st_mtimespec.tv_sec == after.st_mtimespec.tv_sec
        && before.st_mtimespec.tv_nsec == after.st_mtimespec.tv_nsec
        && before.st_ctimespec.tv_sec == after.st_ctimespec.tv_sec
        && before.st_ctimespec.tv_nsec == after.st_ctimespec.tv_nsec
    #else
      return before.st_mtim.tv_sec == after.st_mtim.tv_sec
        && before.st_mtim.tv_nsec == after.st_mtim.tv_nsec
        && before.st_ctim.tv_sec == after.st_ctim.tv_sec
        && before.st_ctim.tv_nsec == after.st_ctim.tv_nsec
    #endif
  }

  private static func systemRead(
    _ descriptor: Int32,
    _ buffer: UnsafeMutableRawPointer?,
    _ count: Int
  ) -> Int {
    #if canImport(Darwin)
      Darwin.read(descriptor, buffer, count)
    #else
      Glibc.read(descriptor, buffer, count)
    #endif
  }
}
