import Foundation
import SwiftData

@MainActor
final class TransactionViewModel {
    func fetchPayments(in context: ModelContext) throws -> [Payment] {
        try context.fetch(FetchDescriptor<Payment>(sortBy: [SortDescriptor(\.timestamp, order: .reverse)]))
    }

    @discardableResult
    func addPayment(
        amount: Double,
        note: String,
        category: String,
        paymentMethod: String = "Unknown",
        isInflow: Bool = false,
        isFlaggedAsBill: Bool = false,
        timestamp: Date = .now,
        to context: ModelContext
    ) throws -> Payment {
        guard amount.isFinite, amount > 0 else { throw TransactionError.invalidAmount }
        let cleanedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedNote.isEmpty else { throw TransactionError.emptyNote }

        let payment = Payment(
            amount: amount,
            note: cleanedNote,
            category: category,
            paymentMethod: paymentMethod,
            isInflow: isInflow,
            isFlaggedAsBill: isFlaggedAsBill,
            timestamp: timestamp
        )
        context.insert(payment)
        try context.save()
        return payment
    }

    func deletePayment(_ payment: Payment, from context: ModelContext) throws {
        context.delete(payment)
        try context.save()
    }
}

enum TransactionError: LocalizedError {
    case invalidAmount
    case emptyNote

    var errorDescription: String? {
        switch self {
        case .invalidAmount: "Enter an amount greater than zero."
        case .emptyNote: "Add a description for this transaction."
        }
    }
}
