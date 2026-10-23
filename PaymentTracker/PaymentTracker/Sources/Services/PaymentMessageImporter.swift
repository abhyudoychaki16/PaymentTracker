import CryptoKit
import Foundation
import SwiftData

enum PaymentMessageImportResult {
    case ignored
    case duplicate
    case saved(Payment)
}

@MainActor
enum PaymentMessageImporter {
    static func importMessage(_ message: String, into context: ModelContext) throws -> PaymentMessageImportResult {
        guard let parsed = MessageScanner().parseTransaction(message: message) else { return .ignored }

        let fingerprint = fingerprint(for: message)
        let descriptor = FetchDescriptor<Payment>(predicate: #Predicate { $0.importFingerprint == fingerprint })
        if try context.fetchCount(descriptor) > 0 { return .duplicate }

        let payment = Payment(
            amount: parsed.amount,
            note: parsed.note,
            category: "Uncategorized",
            paymentMethod: parsed.paymentMethod,
            isInflow: parsed.isInflow,
            isFlaggedAsBill: parsed.isCardBillPayment,
            importFingerprint: fingerprint,
            // Keep the agreed behavior: report the time this import is processed.
            timestamp: .now
        )
        context.insert(payment)
        do {
            try context.save()
            DropSplitSMSMatcher.suggestMatch(for: payment, in: context)
            return .saved(payment)
        } catch {
            context.delete(payment)
            throw error
        }
    }

    private static func fingerprint(for message: String) -> String {
        let normalized = message
            .lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return SHA256.hash(data: Data(normalized.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}
