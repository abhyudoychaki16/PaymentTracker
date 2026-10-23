import Foundation
import SwiftData

/// One locally tracked side of a DropSplit request. The same request is stored
/// independently on each phone; AirDrop carries the request, not later updates.
@Model
final class DropSplit {
    @Attribute(.unique) var requestID: String
    var direction: String
    var counterpartyName: String
    var transactionNote: String
    var category: String
    var paymentMethod: String
    var transactionAmount: Double
    var amountOwed: Double
    var payeeName: String
    var payeeUPI: String
    var createdAt: Date
    var paidAt: Date?
    var smsConfirmationFingerprint: String?

    init(
        requestID: String,
        direction: String,
        counterpartyName: String,
        transactionNote: String,
        category: String,
        paymentMethod: String,
        transactionAmount: Double,
        amountOwed: Double,
        payeeName: String,
        payeeUPI: String,
        createdAt: Date = .now,
        paidAt: Date? = nil,
        smsConfirmationFingerprint: String? = nil
    ) {
        self.requestID = requestID
        self.direction = direction
        self.counterpartyName = counterpartyName
        self.transactionNote = transactionNote
        self.category = category
        self.paymentMethod = paymentMethod
        self.transactionAmount = transactionAmount
        self.amountOwed = amountOwed
        self.payeeName = payeeName
        self.payeeUPI = payeeUPI
        self.createdAt = createdAt
        self.paidAt = paidAt
        self.smsConfirmationFingerprint = smsConfirmationFingerprint
    }

    var isOwedToMe: Bool { direction == DropSplitDirection.owedToMe }
    var isPaid: Bool { paidAt != nil }
}

enum DropSplitDirection {
    static let owedToMe = "owedToMe"
    static let iOwe = "iOwe"
}

struct DropSplitRequest: Codable, Identifiable {
    var id: String
    var transactionNote: String
    var category: String
    var paymentMethod: String
    var transactionAmount: Double
    var amountOwed: Double
    var payerName: String
    var payerUPI: String
    var recipientName: String
    var createdAt: Date
}
