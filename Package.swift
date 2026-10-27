// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "swift-recall-kit",
    // macOS only, and not by choice: every store this searches — Mail's
    // index, the Messages and WhatsApp databases, Notes — exists only on a Mac.
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "RecallKit", targets: ["RecallKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/arraypress/swift-apple-mail.git", from: "0.2.0"),
        .package(url: "https://github.com/arraypress/swift-apple-messages.git", from: "0.4.0"),
        .package(url: "https://github.com/arraypress/swift-whatsapp-messages.git", from: "0.1.0"),
        .package(url: "https://github.com/arraypress/swift-apple-notes.git", from: "0.1.1"),
        // A person's name to their phones and email addresses.
        .package(url: "https://github.com/arraypress/swift-contacts.git", from: "0.1.1"),
    ],
    targets: [
        .target(
            name: "RecallKit",
            dependencies: [
                .product(name: "AppleMail", package: "swift-apple-mail"),
                .product(name: "AppleMessages", package: "swift-apple-messages"),
                .product(name: "WhatsAppMessages", package: "swift-whatsapp-messages"),
                .product(name: "AppleNotes", package: "swift-apple-notes"),
                .product(name: "ContactsKit", package: "swift-contacts"),
            ]
        ),
        .testTarget(name: "RecallKitTests", dependencies: ["RecallKit"]),
    ]
)

// Swift 7's import rule, today: a file must import every module whose members
// it uses, rather than leaning on another file's imports.
for target in package.targets where target.type != .system && target.type != .binary && target.type != .plugin {
    target.swiftSettings = (target.swiftSettings ?? []) + [.enableUpcomingFeature("MemberImportVisibility")]
}
