// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "Glance",
  platforms: [.macOS(.v26)],
  products: [
    .library(name: "GlanceCore", targets: ["GlanceCore"]),
    .executable(name: "glance-mcp", targets: ["glance-mcp"]),
  ],
  targets: [
    .target(name: "GlanceCore"),
    .executableTarget(name: "glance-mcp", dependencies: ["GlanceCore"]),
    .testTarget(
      name: "GlanceCoreTests",
      dependencies: ["GlanceCore"],
      resources: [.copy("Fixtures")]
    ),
  ]
)
