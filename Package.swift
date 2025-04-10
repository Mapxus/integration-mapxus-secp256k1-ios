// swift-tools-version: 5.4
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let version = "1.0.0"

let package = Package(
  name: "Secp256k1",
  platforms: [
    .iOS(.v9),
  ],
  products: [
    .library(
      name: "Secp256k1",
      targets: ["Secp256k1"]
    )
  ],
  targets: [
    .binaryTarget(
      name: "Secp256k1",
      url: "https://nexus3.mapxus.com/repository/mapxus-secp256k1-ios/\(version)/mapxus-secp256k1-ios.zip",
      checksum: "e70f88575518f6674c8b6fa0576f2fca350259cce6f3205f6b26e09be546ec00"
    )
  ]
)
