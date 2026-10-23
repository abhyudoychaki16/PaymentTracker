import Foundation
import SwiftData

@Model
final class Payment {
    @Attribute(.unique) var id: UUID
    var amount: Double
    var timestamp: Date
    var note: String
    var category: String
    var paymentMethod: String = "Unknown"
    var isInflow: Bool
    var isFlaggedAsBill: Bool
    @Attribute(.unique) var importFingerprint: String?

    @Relationship(deleteRule: .cascade) var splits: [PaymentSplit]? = []

    init(
        amount: Double,
        note: String,
        category: String,
        paymentMethod: String = "Unknown",
        isInflow: Bool = false,
        isFlaggedAsBill: Bool = false,
        importFingerprint: String? = nil,
        timestamp: Date = Date()
    ) {
        self.id = UUID()
        self.amount = amount
        self.note = note
        self.category = category
        self.paymentMethod = paymentMethod
        self.isInflow = isInflow
        self.isFlaggedAsBill = isFlaggedAsBill
        self.importFingerprint = importFingerprint
        self.timestamp = timestamp
    }
}

@Model
final class PaymentSplit {
    var id: UUID
    var personName: String
    var amountShare: Double
    var payment: Payment?

    init(personName: String, amountShare: Double) {
        self.id = UUID()
        self.personName = personName
        self.amountShare = amountShare
    }
}
