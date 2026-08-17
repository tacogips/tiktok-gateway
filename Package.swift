// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "tiktok-business-gateway",
  platforms: [.macOS(.v14)],
  products: [
    .library(name: "TikTokBusinessGatewayShared", targets: ["TikTokBusinessGatewayShared"]),
    .library(name: "TikTokBusinessGatewayReaderCore", targets: ["TikTokBusinessGatewayReaderCore"]),
    .library(name: "TikTokBusinessGatewayWriterCore", targets: ["TikTokBusinessGatewayWriterCore"]),
    .executable(name: "tiktok-business-gateway-reader", targets: ["TikTokBusinessGatewayReader"]),
    .executable(name: "tiktok-business-gateway-writer", targets: ["TikTokBusinessGatewayWriter"])
  ],
  targets: [
    .target(name: "TikTokBusinessGatewayShared"),
    .target(
      name: "TikTokBusinessGatewayReaderCore",
      dependencies: ["TikTokBusinessGatewayShared"]
    ),
    .target(
      name: "TikTokBusinessGatewayWriterCore",
      dependencies: ["TikTokBusinessGatewayShared"]
    ),
    .executableTarget(
      name: "TikTokBusinessGatewayReader",
      dependencies: ["TikTokBusinessGatewayReaderCore"]
    ),
    .executableTarget(
      name: "TikTokBusinessGatewayWriter",
      dependencies: ["TikTokBusinessGatewayWriterCore"]
    ),
    .testTarget(
      name: "TikTokBusinessGatewaySharedTests",
      dependencies: ["TikTokBusinessGatewayShared"]
    ),
    .testTarget(
      name: "TikTokBusinessGatewayReaderCoreTests",
      dependencies: ["TikTokBusinessGatewayReaderCore", "TikTokBusinessGatewayShared"],
      resources: [.copy("Fixtures")]
    ),
    .testTarget(
      name: "TikTokBusinessGatewayWriterCoreTests",
      dependencies: ["TikTokBusinessGatewayWriterCore", "TikTokBusinessGatewayShared"],
      resources: [.copy("Fixtures")]
    )
  ],
  swiftLanguageModes: [.v6]
)
