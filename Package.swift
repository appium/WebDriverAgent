// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WebDriverAgent",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v12)
    ],
    products: [
        // Expose the Obj-C library as a SwiftPM product so it can be imported from Swift.
        .library(name: "WebDriverAgentLib", targets: ["WebDriverAgentLib"])
    ],
    targets: [
        // ---- Vendor: CocoaAsyncSocket ----
        .target(
            name: "CocoaAsyncSocket",
            path: "WebDriverAgentLib/Vendor/CocoaAsyncSocket",
            publicHeadersPath: "."
        ),

        // ---- Vendor: CocoaHTTPServer ----
        .target(
            name: "CocoaHTTPServer",
            dependencies: ["CocoaAsyncSocket"],
            path: "WebDriverAgentLib/Vendor/CocoaHTTPServer",
            publicHeadersPath: ".",
            cSettings: [
                .headerSearchPath("Categories"),
                .headerSearchPath("Responses")
            ]
        ),

        // ---- Vendor: RoutingHTTPServer ----
        .target(
            name: "RoutingHTTPServer",
            dependencies: ["CocoaHTTPServer"],
            path: "WebDriverAgentLib/Vendor/RoutingHTTPServer",
            publicHeadersPath: ".",
            cSettings: [
                // Need CocoaHTTPServer headers in include path for quote-style imports
                .headerSearchPath("../CocoaHTTPServer"),
                .headerSearchPath("../CocoaHTTPServer/Responses"),
                .headerSearchPath("../CocoaHTTPServer/Categories")
            ]
        ),

        // ---- Main library ----
        .target(
            name: "WebDriverAgentLib",
            dependencies: [
                "RoutingHTTPServer"
            ],
            path: "WebDriverAgentLib",
            exclude: [
                "Vendor" // compiled in dedicated targets above
            ],
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath(".."),
                .headerSearchPath("include"),
                .headerSearchPath("Routing"),
                .headerSearchPath("Utilities"),
                .headerSearchPath("Utilities/LRUCache"),
                .headerSearchPath("Categories"),
                .headerSearchPath("Commands"),
                .headerSearchPath("include/WebDriverAgentLib"),
                .headerSearchPath("../PrivateHeaders/XCTest"),
                .headerSearchPath("../PrivateHeaders/MobileCoreServices"),
                .headerSearchPath("../PrivateHeaders/AccessibilityUtilities"),
                .headerSearchPath("../PrivateHeaders/TextInput"),
                .headerSearchPath("../PrivateHeaders/UIKitCore"),
            ],
            linkerSettings: [
                // Link against XCTest and system UIKit/Foundation frameworks that
                // are referenced across the Objective-C implementation files.
                .linkedFramework("XCTest"),
                .linkedFramework("UIKit"),
                .linkedFramework("Foundation"),
                .linkedFramework("MobileCoreServices"),
                .linkedFramework("UniformTypeIdentifiers")
            ]
        ),
        // Unit-test target (optional – keeps parity with the original project).
        .testTarget(
            name: "WebDriverAgentLibTests",
            dependencies: ["WebDriverAgentLib"],
            path: "WebDriverAgentTests"
        )
    ]
)
