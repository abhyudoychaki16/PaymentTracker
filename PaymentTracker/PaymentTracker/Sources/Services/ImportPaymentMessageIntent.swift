import AppIntents
import SwiftData

@available(iOS 16.0, *)
struct ImportPaymentMessageIntent: AppIntent {
    static var title: LocalizedStringResource = "Import Payment Message"
    static var description = IntentDescription("Parse a payment notification and save the transaction on this device.")
    static var authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed

    @Parameter(title: "Message text")
    var message: String

    @MainActor
    func perform() async throws -> some IntentResult {
        let context = PersistenceController.shared.modelContainer.mainContext
        _ = try PaymentMessageImporter.importMessage(message, into: context)
        return .result()
    }
}

@available(iOS 16.0, *)
struct PaymentTrackerShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ImportPaymentMessageIntent(),
            phrases: ["Import a payment message with \(.applicationName)"],
            shortTitle: "Import Payment",
            systemImageName: "message.badge.filled.fill"
        )
    }
}
