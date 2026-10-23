import Foundation
import SwiftData

@MainActor
final class PersistenceController {
    static let shared = PersistenceController()

    let modelContainer: ModelContainer

    private init() {
        let schema = Schema([
            Payment.self,
            PaymentSplit.self,
            DropSplit.self
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            let container = try ModelContainer(for: schema, configurations: [config])
            // A locked-message Shortcut may start PaymentTracker in a fresh process. SQLite
            // must be reopenable while locked after the first unlock since boot, so keep the
            // store, its journal files, and their directory at that protection class.
            Self.enableBackgroundStoreAccess(at: config.url)
            modelContainer = container
        } catch {
            fatalError("Failed to initialize SwiftData: \(error)")
        }
    }

    private static func enableBackgroundStoreAccess(at storeURL: URL) {
        let fileManager = FileManager.default
        let storeDirectory = storeURL.deletingLastPathComponent()
        let paths = [
            storeDirectory,
            storeURL,
            URL(fileURLWithPath: storeURL.path + "-wal"),
            URL(fileURLWithPath: storeURL.path + "-shm")
        ]

        for url in paths where fileManager.fileExists(atPath: url.path) {
            do {
                try fileManager.setAttributes(
                    [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                    ofItemAtPath: url.path
                )
            } catch {
                NSLog("PaymentTracker could not update background store protection for %@: %@", url.lastPathComponent, error.localizedDescription)
            }
        }
    }
}
