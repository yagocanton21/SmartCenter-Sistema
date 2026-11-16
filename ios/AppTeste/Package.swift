// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AppTeste",
    platforms: [.iOS(.v17)],
    products: [.library(name: "AppTeste", targets: ["AppTeste"])],
    targets: [.target(name: "AppTeste")]
)
